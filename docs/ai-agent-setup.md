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

### B. 自己寫的,或只有 git repo 沒有 CLI —— clone 完拉 symlink

沒有 CLI 就自己做 CLI 在做的事:把 repo 放到某處,再把要用的 skill 資料夾連過去。

```bash
git clone <repo網址> ~/code/<名字>
ln -sfn ~/code/<名字>/skills/<skill名> ~/.claude/skills/<skill名>
```

一個 skill 就是一個資料夾,裡面有 `SKILL.md`。連過去就能用,不用註冊、不用重啟。

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

## Claude

```bash
claude mcp add <名字> -- npx -y <套件名>       # 預設 local(只有這台的這個專案)
claude mcp add <名字> -s user -- npx -y <套件名>  # user:所有專案都能用
claude mcp add <名字> -s project -- ...          # project:寫進 repo 的 .mcp.json,同事也有
claude mcp list                                  # 看現況
```

`-s user` 的設定存在 `~/.claude.json`;`-s project` 存在該 repo 根目錄的 `.mcp.json`。
session 裡打 `/mcp` 可以看目前連上了哪些。

## opencode

寫在 `home/dot_config/opencode/opencode.json`(部署成 `~/.config/opencode/opencode.json`)的
`mcp` 欄位,格式是每個 server 一段 `command` 陣列。這份設定**在本 repo 裡**,
所以它是唯一跟著 dotfiles 走的 MCP 設定。

目前接了 `context7`、`sequential-thinking`、`chrome-devtools`,外加 `opencode-wakatime` 外掛。

### 為什麼沒有 `provider` 區塊

是刻意拿掉的。opencode 內建認得的 provider 用 `opencode auth login` 就好,手寫 `provider`
只有「自訂 base URL 的代理」才需要。原本那份 TeamSync 代理設定已經失效,留著只會在模型選單裡
出現「選了就噴錯」的項目。

所以 clone 下來是**沒有任何模型供應商**的,要自己 `opencode auth login`。

要撈回舊的當模板(311 行,含 provider 寫法):

```bash
chezmoi cd
git show efcc09d^:.config/opencode/opencode.json
```

`efcc09d` 就是移除那筆 commit。要自己找的話用 `--follow`,因為檔案在 chezmoi 遷移時搬過位置:

```bash
git log --oneline --follow -- home/dot_config/opencode/opencode.json
```

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
| 更新 Claude plugin | Claude 裡打 `/plugin` |
| 確認規則有生效 | 開新 session 打 `/context`,看 **Memory files** 那區 |
