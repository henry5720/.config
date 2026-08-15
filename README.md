# dotfiles

個人開發環境設定,主要目標平台是 **WSL2 上的 Ubuntu 24.04**(shell 為純 zsh,無 Oh My Zsh),另含一組 **Termux(Android)** 的桌面環境腳本作為次要用途。

整體圍繞一套 **AI-agent 輔助的 tmux 終端工作流**(opencode、Claude、外部 agent-tracker),疊在標準的 zsh + tmux + nvim 之上。

## 延伸文件

| 文件 | 什麼時候讀 |
|---|---|
| [`docs/ai-agent-setup.md`](docs/ai-agent-setup.md) | 想搞懂 agent 規則 / skill / MCP / plugin 各是什麼、放哪、怎麼更新。**新機器設定 AI 工具前先讀這份。** |
| [`docs/code-server-remote.md`](docs/code-server-remote.md) | 想從 pad / 手機連自己的 code-server,卡在憑證和 secure context 的時候。列出五種做法與各自代價。 |
| [`docs/superpowers/`](docs/superpowers) | zsh setup 腳本當初的設計與實作規劃(spec / plan),歷史紀錄性質。 |

## 目錄結構

| 路徑 | 用途 | 詳細 |
|---|---|---|
| `.zshrc` | 純 zsh 設定:Powerlevel10k、autosuggestions、syntax-highlighting、nvm、開場 `fastfetch`。 | [↓](#zsh) |
| `.tmux.conf` + `.config/tmux/` | 高度客製的 tmux:TPM 外掛、狀態列、編號 session 管理,以及大量 AI-agent 自動化腳本。 | [↓](#tmux) |
| `.ssh/config` | SSH 連線設定:GitHub、Tailscale 節點、Oracle VPS。**不含私鑰**。 | [↓](#ssh-部署) |
| `.config/nvim/` | 只有 `lua/config/options.lua` 一個片段(剪貼簿處理),**非完整 nvim 設定**。 | [↓](#nvim) |
| `.config/opencode/` | [opencode](https://opencode.ai) 設定:模型供應商、MCP servers、外掛。 | [↓](#opencode) |
| `.config/code-server/` | code-server 設定:只綁 `127.0.0.1`,TLS 交給外層。密碼不進 repo。 | [↓](#code-server-部署) |
| `ai-agent/` | **agent 規則的單一來源** `AGENTS.md`,各家 agent 都 symlink 到它。 | [↓](#ai-agent) |
| `script/ubuntu/` | Ubuntu(apt)開發環境安裝:`setup.sh`、`install-base.sh`、`install-tools.sh`。 | [↓](#安裝與部署) |
| `script/oci/` | Oracle Cloud 專用:搶 A1(`grab-a1.sh`)、閒置保活(`setup-keepalive.sh`)。 | [↑](#延伸文件) |
| `script/termux/` | Android/Termux 桌面環境腳本(xfce/tablet),與 Ubuntu 無關。 | [↓](#termux) |
| `wsl/` | Windows 主機側的 WSL2 設定與 portproxy 備忘,**手動使用、非由腳本部署**。 | [↓](#wsl) |
| `docs/` | 說明文件,見上方[延伸文件](#延伸文件)。 | — |

## 安裝與部署

先 clone 到 `~/code/dotfiles`,再擇一執行:

```bash
# 一鍵:基底 + 工具選單
bash script/ubuntu/setup.sh

# 或分開跑
bash script/ubuntu/install-base.sh    # 基底(強制):zsh/git/curl/vim + 插件 + .zshrc + 預設 shell
bash script/ubuntu/install-tools.sh   # 工具(可選):編號多選 fastfetch / btop / nvm / code-server
```

工具選單:空格分隔多選(例 `1 3`),直接 Enter = 全裝。

腳本處理 zsh 那條線和工具選單(含 code-server 的設定檔部署)。**ssh 與 AI agent 要手動各跑一次**,見下面幾節。

### zshrc 部署

`install-base.sh` 會把 `~/.zshrc` 建成指向本 repo 的 **symlink**:

```bash
ls -la ~/.zshrc      # 應顯示 ~/.zshrc -> ~/code/dotfiles/.zshrc
```

好處:改 repo 的 `.zshrc`,`git pull` 後立刻生效。若原本已有 `~/.zshrc`,會先備份(通常為 `~/.zshrc.bak`)。

反安裝(還原原本設定):

```bash
rm ~/.zshrc && mv ~/.zshrc.bak ~/.zshrc
```

### ssh 部署

`.ssh/config` 不由 `install-base.sh` 部署,需手動擇一。**先決條件**:三種方式都需要私鑰
`~/.ssh/henry5720`(config 內所有 Host 的 `IdentityFile`,**未附於 repo**),放好後設權限
`chmod 600 ~/.ssh/henry5720`,否則所有連線失敗。

擇一(由鬆到緊):

```bash
# 方式 A|Include(推薦):repo 管共用,本機仍可疊加自己的 Host,pull 即生效
#   把 Include 放在最上面(prepend)。用暫存檔避免讀寫同檔清空原內容。
{ echo 'Include ~/code/dotfiles/.ssh/config'; cat ~/.ssh/config 2>/dev/null; } > ~/.ssh/config.new \
  && mv ~/.ssh/config.new ~/.ssh/config

# 方式 B|symlink:pull 即生效,但整份被 repo 獨佔、無法再放機器特定設定,且覆蓋既有檔
mv ~/.ssh/config ~/.ssh/config.bak 2>/dev/null; ln -s ~/code/dotfiles/.ssh/config ~/.ssh/config

# 方式 C|copy:完全自主可任意改,但 pull 後不會生效、需手動重 copy,易與 repo drift
cp ~/code/dotfiles/.ssh/config ~/.ssh/config
```

`chmod 700 ~/.ssh` 收斂目錄權限。三種方式的差異就是「同步 vs 自主」的取捨:A 兩者兼顧、
B 全同步無自主、C 全自主無同步。

> ssh 對多數選項是 **first-match-wins**。方式 A 把 `Include` 放最上面 → repo 設定優先;
> 若某台想用本機值蓋掉 repo 的同名 Host,改把 `Include` 放檔案**最後**即可。

### AI agent 部署

本 repo 只管**規則**;skill、MCP、plugin 是訂閱來的,不進本 repo。
四者的差別、各自怎麼裝與更新,見 [`docs/ai-agent-setup.md`](docs/ai-agent-setup.md)。

新機器只要跑這一行:

```bash
# Claude Code 只讀 CLAUDE.md,不讀 AGENTS.md,所以要換名字
ln -sfn ~/code/dotfiles/ai-agent/AGENTS.md ~/.claude/CLAUDE.md
```

`.config/opencode/AGENTS.md` 是 repo 內的 relative symlink,clone 下來就生效。

> ⚠️ 原本的 `~/.claude/CLAUDE.md` 如果有內容,`ln -sfn` 會**直接蓋掉且不留備份**,先自行 `cp`。

### code-server 部署

在 `install-tools.sh` 的選單裡選 `code-server` 就會一次做完兩件事:用官方安裝腳本裝 binary、
把 `~/.config/code-server/config.yaml` 建成指向本 repo 的 **symlink**(原檔會先備份成
`config.yaml.bak`)。

```bash
ls -la ~/.config/code-server/config.yaml   # 應指向 ~/code/dotfiles/.config/code-server/config.yaml
```

**密碼不在設定檔裡**——那個檔案在 git 裡。改用環境變數(會蓋過設定檔),寫進不版控的地方:

```bash
export HASHED_PASSWORD='$argon2i$...'   # 建議
export PASSWORD='...'                   # 或明碼
```

預設只綁 `127.0.0.1:8080`、`cert: false`,也就是**假設 TLS 由外層處理**。
從 pad / 手機連進來有五種做法(ssh tunnel、`tailscale serve`、`tailscale cert`、自簽、mkcert),
各自的代價與指令見 [`docs/code-server-remote.md`](docs/code-server-remote.md)。

## 各區塊說明

### zsh

`.zshrc` —— 純 zsh,插件從 `~/.config/zsh/` 載入(由 `install-base.sh` git clone,未 vendored 進 repo)。載入 nvm(讓 `claude` / `opencode` 找得到)、設定 pnpm PATH 與共享歷史,並在裝了 `fastfetch` 時開場顯示系統資訊。所有插件 source 皆有防呆,缺檔不會報錯。

### tmux

`.tmux.conf` + `.config/tmux/` —— 為多 agent、多 session 的 AI 工作流打造:

- **外掛(TPM)**:`tmux-resurrect` + `tmux-continuum`(session 持久化、還原 pane 內容與 `lazygit`/`yazi` 等程序),外加自製 `fzf_panes.tmux`(fzf 的 MRU pane 選擇器)。
- **狀態列**(`tmux-status/`):組合左右狀態,顯示 ccusage(Claude Code 用量)、每 pane/window 記憶體、todo 數等。
- **腳本**(`scripts/`):編號 session 管理(重命名/排序/搬移)、版面建構、跨平台剪貼簿、以及 agent 自動化(agent palette 彈窗、記住並還原 opencode pane 的工作目錄、resurrect 還原後重啟 Flutter dev server 等)。

依賴:tmux(較新版)、TPM、Python 3、`jq`、`fzf`,以及外部 binary `~/.config/agent-tracker/bin/agent`(**未附**,缺了大部分狀態列/hook 會安靜降級)。

### nvim

`.config/nvim/` —— 只版控 `lua/config/options.lua`(依 LazyVim 目錄慣例),設定 `vim.g.clipboard`:SSH 連線用 OSC 52 同步剪貼簿,否則用 Termux 剪貼簿工具。需搭配既有 LazyVim 基底。

### opencode

`.config/opencode/opencode.json` —— 設定走 **TeamSync 代理**的多家模型(Gemini/Claude/GPT/DeepSeek/Kimi 等)、MCP servers(`context7`、`sequential-thinking`、`chrome-devtools`)與外掛(`superpowers`、`wakatime`)。

`.config/opencode/AGENTS.md` 是指向 `../../ai-agent/AGENTS.md` 的 symlink。

### ai-agent

`ai-agent/AGENTS.md` —— 跨 repo、跨 agent 的**規則單一來源**。刻意只寫「換到任何一個 repo
都還成立」的事:語言、白話、回覆方式、誠實。

想加規則之前先過這張表:

| 這件事 | 該放哪 |
|---|---|
| 換個 repo 就不成立(技術棧、build 指令、專案慣例) | 該 repo 自己的 `CLAUDE.md` |
| 是多步驟流程(debug、TDD、需求對齊) | 寫成 skill,按需載入 |
| linter / hook / `permissions.deny` 做得到 | 交給工具,不要寫成規則 |

規則還要**可驗證** —— 「白話一點」不可驗證,「一個句子拿掉抽象名詞就沒有資訊了就重寫」可以。
不可驗證的規則你沒辦法指著回覆說它違規,agent 也就不會穩定遵守。

完整說明(含 skill / MCP / plugin 怎麼分)見 [`docs/ai-agent-setup.md`](docs/ai-agent-setup.md)。

`AGENTS(think-mode)*.md` 是「思維總監」對抗式 persona,手動貼用,不在 symlink 鏈裡。

### termux

`script/termux/` —— **與 WSL 無關**,是 Android/Termux 上的桌面環境腳本:`set-up-tablet.sh` 首次安裝 XFCE/X11 GUI 堆疊;`startxfce_native.sh` 用軟體渲染直接跑 XFCE;`startxfce_proot.sh` 進 proot-distro Debian 跑 XFCE。

### wsl

`wsl/` —— Windows 主機側檔案,**不由本 repo 腳本部署**:`.wslconfig`(記憶體 16G / swap 8G / 8 CPU / mirrored 網路,需複製到 `%UserProfile%\.wslconfig`)、`command.md`(把 Windows 埠轉發進 WSL 的 `netsh portproxy` 備忘)。

## 依賴一覽

- **平台**:WSL2(Windows)+ Ubuntu 24.04 為主;xfce/tablet 腳本需 Termux(Android)。
- **shell**:zsh、Powerlevel10k、autosuggestions、syntax-highlighting(裝在 `~/.config/zsh/`)。
- **tmux**:tmux、TPM、`tmux-resurrect`/`continuum`、`fzf`、`jq`、Python 3,以及私有 `agent-tracker`(未附)。
- **編輯器**:Neovim + 既有 LazyVim 基底。
- **AI 工具**:Node/nvm、`opencode` CLI、MCP servers(經 `npx`)。
- **可選工具**:`fastfetch`、`btop`、`code-server`(由 `install-tools.sh` 安裝)。

## ⚠️ 機器特定 / fork 前需自行修改

1. `script/termux/startxfce_proot.sh` **寫死使用者名稱 `henry`**(`su - henry`)。
2. tmux 的 agent 整合依賴**未附的私有 binary** `~/.config/agent-tracker/bin/agent` 及其 `~/.config/agent-tracker/`、`~/.cache/agent/` 狀態檔;缺了功能降級但不致命。
3. `.config/opencode/opencode.json` 綁**私有 TeamSync 代理**,需 `TEAMSYNC_API_KEY` 與數個 `TEAMSYNC_*_BASE_URL` 環境變數,開箱無法直接使用。
4. `ai-agent/AGENTS.md` 是 henry 的**個人回覆偏好**(繁中、白話),fork 前請整份換掉。
5. `.ssh/config` 內的 Host 與 `IdentityFile` 是 henry 的,fork 後整份替換。
6. `wsl/` 內含範例 IP,且需手動複製到 Windows 端。
