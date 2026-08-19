# AI agent 環境:誰管什麼

用 Claude Code / opencode 這類 coding agent 時,身上會掛四種東西。
它們**放在不同地方、用不同指令更新**,搞混就會出現「我明明更新了怎麼沒變」。

## 三個原則

1. **除了規則,全部都是可選的。** skill、MCP、plugin 沒有「標準配備」,
   看你需要什麼就裝什麼,不裝也完全能用。
2. **本 repo 只維護「你自己寫的規則」。** 別人的東西一律不複製進來。
3. **這裡只記「去哪裡拿」,不記東西本身。** 重灌時照著指令重裝,不是還原備份。

## 四種東西

| | 是什麼 | 誰寫的 | 檔案實際在哪 | 怎麼更新 |
|---|---|---|---|---|
| **規則** | 你希望 agent 怎麼做事 | **你** | 本 repo `home/dot_claude/CLAUDE.md` | 改完 commit |
| **skill** | 一套做某件事的步驟,用到才載入 | 別人 或 **你** | 別人的在 `~/.agents/skills/`;自己的在寫它的那個 repo | 看來源,見下 |
| **MCP** | 給 agent 接外部服務的通道 | 別人 | 各 agent 自己的設定檔 | 通常自動抓最新 |
| **plugin** | Claude 的擴充包(可同時含 skill + MCP + 指令) | 別人 | `~/.claude/plugins/` | Claude 裡打 `/plugin` |

---

# 1. 規則(本 repo 唯一要維護的)

每家 agent 讀的檔名不一樣 —— Claude 只讀 `CLAUDE.md`,opencode 讀 `AGENTS.md`。
各寫一份的話,改了 A 忘了改 B,兩邊行為就會不一樣(這件事真的發生過)。

解法是**只留一份真的檔案,其他都是捷徑**:

```
home/dot_claude/CLAUDE.md             ← 真的檔案,只有這份要改
   ↑                    ↑
   │                    └── ~/.config/opencode/AGENTS.md   (chezmoi 建的 symlink)
   └── ~/.claude/CLAUDE.md                                 (chezmoi 部署)
```

新機器不用為規則另外做事——`chezmoi init --apply`(見 README〈安裝與部署〉)本身就含
這份規則,會直接部署好 `~/.claude/CLAUDE.md`。

> ⚠️ 若這台機器原本已有 `~/.claude/CLAUDE.md` 且有內容,`chezmoi init --apply` 會
> **直接蓋掉且不留備份**。先 `cp ~/.claude/CLAUDE.md ~/.claude/CLAUDE.md.bak`。

已經 `chezmoi init` 過的機器,想單獨重新套用規則(例如剛 `git pull` 完):

```bash
# 規則由 chezmoi 部署,不用手動 ln
chezmoi apply ~/.claude/CLAUDE.md
```

之後改 `home/dot_claude/CLAUDE.md`、`chezmoi apply`,兩邊同時生效。跟 `.zshrc` 是同一招。

## 規則要寫什麼

只寫「換到任何一個 repo 都還成立」的事。判斷方法:

- 換個 repo 就不成立(技術棧、build 指令、專案慣例)→ 寫在**那個 repo 自己的 `CLAUDE.md`**
- 是一套多步驟流程(查 bug、TDD、需求對齊)→ 寫成 **skill**,用到才載入
- linter、git hook、權限設定做得到 → **交給那些工具**,寫成規則只是「希望 agent 不要這樣做」

還有一條:**規則要能判斷有沒有違規**。
「講白話一點」沒辦法判斷;「一個句子拿掉抽象名詞就沒有資訊了就重寫」可以。
判斷不了的規則,你沒辦法抓它,agent 也就不會穩定遵守。

## 不要把本體放在 `dotfiles/.claude/CLAUDE.md`

看起來很整齊,但會出事。Claude 認的專案指引位置就是 `./CLAUDE.md` 或 `./.claude/CLAUDE.md`,
而多份 CLAUDE.md 是**接在一起**送進去、不是互相覆蓋。

所以在 dotfiles 裡開 Claude 會讀到兩次:一次是你的個人設定,一次是「dotfiles 這個專案的設定」——
同一份規則載入兩遍,白花錢,而且重複的指令本身就會讓 agent 更難遵守。

> 這條**不包含** repo 根目錄的 `dotfiles/CLAUDE.md`。那份寫的是「怎麼改這個 repo」
> (檔名前綴、秘密、驗證方式),和個人偏好不重複,載入一次,是正常的專案指引。
> 要避開的只有把**個人規則本體**放到 `dotfiles/.claude/CLAUDE.md`。

## `ai-agent/` 那兩份 think-mode 不是規則

`ai-agent/AGENTS(think-mode).md` 和 `AGENTS(think-mode-long).md` 是「思維總監」對抗式 persona,
**手動貼進對話用的**,不由 chezmoi 部署、不在 symlink 鏈裡、不會自動生效。

放在 repo 根目錄(chezmoi 看不到的那半)就是為了跟會自動載入的規則分開。

---

# 2. skill

skill 是一套「做某件事的步驟」,平常不佔 context,用到才載入。

**兩件事要分開想:從哪裡來(來源)、裝給誰用(範圍)。**

## 2-1 來源:別人的 vs 自己的

### A. 別人的,而且有 CLI —— 用 `npx skills`

大部分公開 skill 都支援這個裝法:

```bash
npx skills@latest add <github帳號>/<repo名>
```

會問你要裝哪幾個、裝給哪些 agent。目前裝了哪些、各自來自哪,查:

```bash
npx skills@latest list -g
```

> **這裡不列清單。** 想裝什麼是你自己的事,而寫死的清單一定會過時 ——
> 要知道現況就跑上面那行,那才是真的。

裝完的結構:

```
~/.agents/skills/tdd/          ← 真的檔案(通用 agent 都讀這裡)
      ↑
      └── ~/.claude/skills/tdd  ← 捷徑
```

跟規則是**同一招**,只是這個由工具自動做,你不用管。
所以不需要再把 skill 搬進 dotfiles 手動拉線 —— 那是把已經自動化的事改回手動。

常用指令:

```bash
npx skills@latest update -g -y   # 全部更新
npx skills@latest update tdd     # 只更新一個
npx skills@latest find <關鍵字>  # 找新的
npx skills@latest remove <名字>  # 移除
```

> ⚠️ 更新會**蓋掉你手改過的內容**。想改某個別人的 skill,先另存一份再改。

**同一個 repo 裡的 skill 可以只挑幾個裝。** `-s` 指定名字、`-l` 只列不裝:

```bash
npx skills@latest add <帳號>/<repo> -l                    # 先看它有哪些
npx skills@latest add <帳號>/<repo> -g -y -s <名字> -a '*'  # 只裝這個,裝給所有 agent
```

[caveman](https://github.com/JuliusBrussee/caveman) 是這樣裝的:它 repo 裡有 20 個 skill,
只裝了核心那個 `caveman`(壓縮輸出用詞省 output token)。剩下 19 個沒裝的理由:
6 個(`caveman-discover` / `-evidence-review` / `-learn` / `-manage` / `-optimize` / `-setup`)
要 Caveman Cloud 帳號;`investigate-first`、`safe-refactor`、`surgical-patch`、`lean-build`、
`verify-and-stop`、`caveman-explore`、`cavecrew` 跟已經裝的 mattpocock 那組
(`diagnosing-bugs` / `tdd` / `prototype`)和內建的 `Explore` agent 職責重疊。
**skill 每多一個,每個 session 就多一段 description 常駐在 context 裡**,重疊的不要裝兩份。

caveman 也提供 proxy(`npm i -g @caveman-ai/cli` 之後用 `caveman claude` 取代 `claude`)
和 MCP server 兩條路,**都沒用**:proxy 會改寫送進模型的內容,出問題時分不清是模型的問題
還是被壓壞了,而且它要換掉 `claude` 的啟動入口 —— 這個 repo 沒有納管 claude 怎麼啟動。

### B. 自己寫的,或只有 git repo 沒有 CLI —— clone 完拉 symlink

沒有 CLI 就自己做 CLI 在做的事:把 repo 放到某處,再把要用的 skill 資料夾連過去。

```bash
git clone <repo網址> ~/code/<名字>
ln -sfn ~/code/<名字>/skills/<skill名> ~/.claude/skills/<skill名>
```

一個 skill 就是一個資料夾,裡面有 `SKILL.md`。不用額外註冊;已開啟的 agent 不會重新掃描,
新增後重啟 client。

**自己寫的 skill 放哪?放在它依賴的東西旁邊。**
例如 `slack-todo` 會呼叫 `work-helper/bin/` 底下的程式 —— 放同一個 repo,
路徑是相對的、一次 commit 改完;拆兩個 repo 就得寫死絕對路徑,遲早不同步。

目前自己寫的都在 `~/code/work-helper/`:

```
~/code/work-helper/
├── bin/              ← skill 會呼叫的程式
└── skills/
    ├── daily-worklog/
    └── slack-todo/
```

## 2-2 範圍:裝給誰用

同一個 skill 可以只裝給一個專案,也可以全機器共用。差別只是**放的位置**:

| 範圍 | 位置 | 什麼時候用 |
|---|---|---|
| **global** | `~/.claude/skills/<名字>/`(Claude)<br>`~/.agents/skills/<名字>/`(其他 agent) | 到處都用得到:查 bug、TDD、寫日誌 |
| **project** | `<那個repo>/.claude/skills/<名字>/` | 只有這個專案有意義,而且要跟著 repo 給同事 |

`npx skills` 用旗標切:`-g` 是 global,`-p` 是只裝這個專案。
手動 clone 的話就是 symlink 拉到上表對應的位置。

opencode 會自動掃 `~/.claude/skills/`、`~/.agents/skills/`,以及專案裡對應的兩個目錄。
所以同一份 skill 不用再寫進 `opencode.json`;目前大部分 `~/.claude/skills/*` 本來就是指向
`~/.agents/skills/*` 的 symlink。

project 範圍的好處是**會進版控**,同事 clone 下來就有;
壞處是換個專案就沒了。判斷方法:**這個 skill 講的事,換個 repo 還成立嗎?**

## 2-3 為什麼別人的 skill 不進 dotfiles

那些檔案是別人 repo 裡的。複製進來以後:

- 上游改了,你的版本不會跟著動
- 想跟上就得手動比對、手動貼、處理衝突
- 你的 dotfiles 從「我的設定」變成「我的設定 + 別人好幾個 repo 的快照」

一行指令能更新的事,變成長期的維護負擔。

---

# 3. MCP

MCP 是「讓 agent 連到外部服務」的通道 —— 查文件、開瀏覽器、讀 Slack、連資料庫。
**跟 skill 完全是兩回事**:skill 是步驟說明(純文字),MCP 是真的能對外做事的工具。

也是可選的,想接什麼再裝什麼。

**不同 client 不會共用 MCP 設定。** Claude 裡裝過的 MCP 或 plugin,opencode 不會自動載入;
同一個 server 要分別寫進兩邊的設定。這跟 skill 不同,不要因為 opencode 讀得到
`~/.claude/skills/` 就以為它也會讀 Claude 的 MCP。

## Claude

```bash
claude mcp add <名字> -- npx -y <套件名>       # 預設 local(只有這台的這個專案)
claude mcp add <名字> -s user -- npx -y <套件名>  # user:所有專案都能用
claude mcp add <名字> -s project -- ...          # project:寫進 repo 的 .mcp.json,同事也有
claude mcp list                                  # 看現況
```

`-s user` 的設定存在 `~/.claude.json`;`-s project` 存在該 repo 根目錄的 `.mcp.json`。
session 裡打 `/mcp` 可以看目前連上了哪些。

### 哪些 MCP 設定該進這個 repo

判準只有一句:**重跑一次官方裝法,這個設定會不會自己回來?**

| | 會回來 | 不會回來 |
|---|---|---|
| 例子 | context7(`npx ctx7 setup` 一行搞定)、promptx | chrome-devtools 那四個參數 |
| 怎麼辦 | 不進 repo,在下面[換機器怎麼重建](#換機器怎麼重建)記一行指令 | 進 repo |

會回來的東西抄進 repo 只有壞處:上游改了裝法,你 repo 裡那份就變成凍住的舊版本
(這跟[為什麼別人的 skill 不進 dotfiles](#2-3-為什麼別人的-skill-不進-dotfiles)是同一個道理)。

chrome-devtools 是唯一的例外,因為官方裝法
`claude mcp add chrome-devtools npx chrome-devtools-mcp@latest` 生出來的設定**是壞的** ——
少了 `--browser-url`,在 WSL 上跑不起來。那份設定裡有四個重跑 installer 不會回來的決定,
所以用 chezmoi 的 `modify_` 納管:見 [chrome-devtools-mcp.md](chrome-devtools-mcp.md)。

### codegraph:設定會回來,但它塞進 CLAUDE.md 的那段不會

[codegraph](https://github.com/colbymchenry/codegraph) 把程式碼建成 symbol 圖,讓 agent 用
`codegraph_explore` 一次拿到「相關符號原始碼 + 呼叫路徑」,取代一堆 grep。它同時是 CLI、MCP
server 和背景 daemon。

裝法選 npm(不是官方那條 `curl | sh`):

```bash
npm i -g @colbymchenry/codegraph      # 主套件只是 shim,真的 binary 走 optionalDependency 帶下來
codegraph install -t claude -l global -y   # 寫 MCP 設定進 Claude Code(user 範圍)
```

`-t claude` 是刻意的:opencode 那邊不讓 installer 寫,設定放在 template 裡,理由見
[opencode](#opencode)。

⚠️ **npm 裝的東西綁在當前 node 版本。** `npm config get prefix` 是
`~/.nvm/versions/node/<版本>`,`nvm use` 換版本後 `codegraph` 就從 PATH 上消失,而
`~/.claude.json` 裡那台 MCP server 的 command 就是裸的 `codegraph` —— 它會變成連不上,
而不是報「找不到指令」。換 node 版本後重跑一次 `npm i -g` 就好。

`codegraph install` 動四個地方,其中三個符合上面「會回來」的判準,**只有一個不會**:

| 它改了什麼 | apply 之後還在嗎 | 為什麼 |
|---|---|---|
| `~/.claude.json` 的 `mcpServers.codegraph` | 在 | `modify_private_dot_claude.json` 只釘 chrome-devtools 那個 key,其他原封不動帶過 |
| `~/.claude/settings.json` 的 `codegraph prompt-hook` + `permissions.allow` | 在 | 同上,`modify_settings.json` 只釘一個 plugin 開關 |
| `~/.claude/CLAUDE.md` 的 `<!-- CODEGRAPH_START -->` 區塊 | **不在** | 這份是 chezmoi 直接部署的整檔,apply 會把它蓋回 repo 版 |

所以那段收進了 `home/dot_claude/CLAUDE.md`,**保留英文原文和 START/END 標記** ——
`codegraph upgrade` 會重寫兩個標記之間的內容,翻成中文的話每次升級都跑出 chezmoi diff。

> 裝完跑一次 `chezmoi verify`。實測第一次 `codegraph install` 之後 `~/.claude.json` 的權限
> 從 600 變成 644(repo 那份是 `modify_private_dot_claude.json`,前綴 `private_` 就是 600)。
> 重跑 `codegraph install --refresh` 不會重現,所以兇手不確定是它還是 Claude Code 自己寫檔;
> 反正 `chmod 600 ~/.claude.json` 就好 —— 那個檔裡有帳號資訊,644 表示同機其他使用者讀得到。

### codegraph 的索引是每個專案自己的事

```bash
cd <專案>
codegraph init      # 建索引,之後存檔 2 秒內自動同步
codegraph status    # 看索引狀態
codegraph uninit -f # 移除(注意是 -f,不是 -y)
```

`.codegraph/` 裡自帶一份 `.gitignore`(內容是 `*` 加 `!.gitignore`),所以 db 不會進版控,
但**目錄本身還是會出現在 `git status` 的 untracked**,要不要在該 repo 的 `.gitignore` 加
`.codegraph/` 自己決定。

**這個 dotfiles repo 不值得 init。** 實測 `codegraph init` 只索引到 5 個檔
(4 個 `home/dot_config/tmux/scripts/*.py` 加 `nvim/lua/config/options.lua`,80 nodes) ——
shell script 和設定檔它不解析,而這個 repo 幾乎只有這兩種東西。

## opencode

寫在 `home/dot_config/opencode/private_opencode.json.tmpl`(部署成權限 600 的
`~/.config/opencode/opencode.json`)的 `mcp` 欄位,格式是每個 server 一段 `command` 陣列。

repo 裡有 `chrome-devtools` 和 `codegraph` 兩個 server,外加 `opencode-wakatime` 外掛。
chrome-devtools 從 WSL 經 mirrored networking 連到 Windows 的 `127.0.0.1:9222`,不會在 WSL
另開 Chrome —— 啟動方式、獨立 profile、排錯全在
[chrome-devtools-mcp.md](chrome-devtools-mcp.md)。

**opencode 這邊的 MCP 一律走 template,不要用工具自己的 installer 寫。** 上面那條
「重跑裝法會不會自己回來」的判準在這裡不成立:`~/.config/opencode/opencode.json` 是 chezmoi
從 template 渲染出來的整檔,installer(例如 `codegraph install -t opencode`)寫進去的東西
下次 `chezmoi apply` 就被蓋掉,而且不會有任何提示。改 template 再 apply 才留得住。

改完驗證(這個檔含明文 API key,不要直接 cat):

```bash
chezmoi cat ~/.config/opencode/opencode.json | jq empty        # JSON 合法嗎
chezmoi apply ~/.config/opencode/opencode.json
opencode mcp list                                             # 看有沒有 connected
```

`context7` 和 `sequential-thinking` 以前也寫在這裡,已經拿掉:
context7 走 `npx ctx7 setup`(官方 CLI,會偵測裝了哪些 agent 讓你選),寫進 repo 只是把舊裝法
凍住;sequential-thinking 則是 Anthropic 從 2025-12 起建議改用 extended thinking 取代,
而且長 session 記憶體會漲到 10GB 以上。

### provider 與 API key

這份設定有自訂 base URL 的 `codex-lb-gcp` provider,所以不能只靠 `opencode auth login`。
provider 結構跟著 dotfiles 走,API key 則由 `home/.chezmoi.toml.tmpl` 的 `promptStringOnce`
在 `chezmoi init` 時詢問,只存在 repo 外的 `~/.config/chezmoi/chezmoi.toml`。

fork 這個 repo 時要換掉 provider 的 base URL,並在 `chezmoi init` 輸入自己的 key。不要把
渲染後的 `~/.config/opencode/opencode.json` 收回 repo,那份含明文 key。

> 大部分 MCP 是用 `npx -y` 跑的,每次啟動抓最新版,不需要手動更新。

---

# 4. plugin

Claude 專屬的擴充包,一個 plugin 裡面可能同時有 skill、MCP、slash 指令。
**`npx skills update` 完全管不到它們**,這是最容易搞混的地方。

```
Claude 裡打 /plugin   → 瀏覽、安裝、更新、移除
```

檔案在 `~/.claude/plugins/`,清單在 `installed_plugins.json`。

opencode 也有自己的 plugin,寫在 `opencode.json` 的 `plugin` 欄位,由 opencode 自己管,
跟 Claude 的 plugin 無關。

> ⚠️ **同一套 skill 不要用兩種方式裝。** 有些作者同時提供 `npx skills` 和 Claude plugin
> 兩條路(例如 mattpocock),兩邊都裝會變成每個 skill 兩份。選一條。

---

# 換機器怎麼重建

`chezmoi init --apply henry5720` 只會帶回 repo 裡的東西 —— 規則(含 codegraph 那段)、
opencode 設定(含 chrome-devtools 與 codegraph 兩個 MCP)、chrome-devtools 那兩份 `modify_`、
`chrome-mcp`。**可選的東西一律要自己重裝**,
下面這幾行就是清單:

```bash
# MCP
npx ctx7 setup                                                   # context7,會問要裝給哪些 agent
claude mcp add promptx -s user -- npx -y @promptx/mcp-server      # promptx
npm i -g @colbymchenry/codegraph && codegraph install -t claude -l global -y   # codegraph
#   opencode 那邊不用再跑,設定在 opencode template 裡,chezmoi apply 就有

# skill(別人的)—— 這幾個是目前的來源,查現況用 `npx skills@latest list -g`
npx skills@latest add mattpocock/skills      # tdd / diagnosing-bugs / domain-modeling ...
npx skills@latest add Leonxlnx/taste-skill   # 前端設計品味那一組
npx skills@latest add vercel-labs/skills     # find-skills
npx skills@latest add stablyai/orca          # computer-use / orca-cli
npx skills@latest add JuliusBrussee/caveman -g -y -s caveman -a '*'   # 只要核心那一個,理由見 2-1

# Claude plugin —— 這幾個要在 Claude 裡打 /plugin 一個一個裝
#   claude-hud(需先加 marketplace jarrodwatts/claude-hud)
#   andrej-karpathy-skills(需先加 marketplace forrestchang/andrej-karpathy-skills)
#   context7 / typescript-lsp / frontend-design / skill-creator(官方 marketplace)
#   chrome-devtools-mcp —— 不要開,repo 裡那份 modify_ 會把它設成 false,理由見
#   chrome-devtools-mcp.md
```

自己寫的 skill 在 `~/code/work-helper/`,那是另一個 repo,clone 下來再照
[2-1 B](#b-自己寫的或只有-git-repo-沒有-cli--clone-完拉-symlink) 拉 symlink。

> 這份清單**會過時**,它的用途是「照著跑一遍,發現少什麼就補上」,不是權威來源。
> 現況一律問工具本身:`npx skills@latest list -g`、`claude mcp list`、Claude 裡打 `/plugin`。
> 這跟 [2-1](#a-別人的而且有-cli--用-npx-skills) 說的「不列清單」不衝突 ——
> 那裡講的是「現在裝了哪些」(會一直變),這裡列的是「重建步驟」。

---

# 懶人包

| 想做什麼 | 怎麼做 |
|---|---|
| 改 agent 的行為規則 | 改 `home/dot_claude/CLAUDE.md`,commit |
| 新機器套用規則 | `chezmoi init --apply henry5720`(規則含在裡面) |
| 看現在裝了哪些 skill | `npx skills@latest list -g` |
| 裝別人的 skill | `npx skills@latest add <帳號>/<repo>` |
| 裝沒有 CLI 的 skill | clone 下來,再 `ln -sfn <repo>/skills/<名字> ~/.claude/skills/<名字>` |
| 只給某個專案用的 skill | 放 `<那個repo>/.claude/skills/<名字>/` |
| 更新 skill | `npx skills@latest update -g -y` |
| 接一個 MCP | `claude mcp add <名字> -s user -- npx -y <套件名>` |
| 讓 agent 用瀏覽器 | `chrome-mcp` 開 Windows Chrome,再在 session 裡 `/mcp` 確認連上 |
| 讓 agent 用 symbol 圖查程式碼,不要一直 grep | 在那個專案 `codegraph init`,見 [codegraph](#codegraph設定會回來但它塞進-claudemd-的那段不會) |
| 換過 node 版本後 codegraph 掛了 | `npm i -g @colbymchenry/codegraph` 再裝一次(npm -g 綁 node 版本) |
| 換新機器要重裝什麼 | 見[換機器怎麼重建](#換機器怎麼重建) |
| 更新 Claude plugin | Claude 裡打 `/plugin` |
| 確認規則有生效 | 開新 session 打 `/context`,看 **Memory files** 那區 |
