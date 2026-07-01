# dotfiles

個人開發環境設定,主要目標平台是 **WSL2 上的 Ubuntu 24.04**(shell 為純 zsh,無 Oh My Zsh),另含一組 **Termux(Android)** 的桌面環境腳本作為次要用途。

整體圍繞一套 **AI-agent 輔助的 tmux 終端工作流**(opencode、Claude、外部 agent-tracker),疊在標準的 zsh + tmux + nvim 之上。

## 目錄結構

| 路徑 | 用途 |
|---|---|
| `.zshrc` | 純 zsh 設定:Powerlevel10k、`zsh-autosuggestions`、`zsh-syntax-highlighting`(從 `~/.config/zsh/` 載入)、nvm、開場 `fastfetch`。 |
| `.tmux.conf` + `.config/tmux/` | 高度客製的 tmux:TPM 外掛、狀態列、編號 session 管理,以及大量 AI-agent 自動化腳本(見下方 tmux 段)。 |
| `.config/nvim/` | 只有 `lua/config/options.lua` 一個片段(剪貼簿處理),需搭配既有的 LazyVim 安裝,**非完整 nvim 設定**。 |
| `.config/opencode/` | [opencode](https://opencode.ai)(終端 AI coding agent)設定:模型供應商、MCP servers、外掛;`AGENTS.md` 為 persona/工作流指示。 |
| `ai-agent/` | 給各家 AI 工具用的 persona / rules 文件(開發準則、Cursor rules、think-mode 等)。 |
| `script/` | 安裝腳本:WSL 主線的 zsh 環境(`setup.sh` 等),以及 Termux 的 xfce/tablet 桌面腳本。 |
| `wsl/` | Windows 主機側的 WSL2 設定(`.wslconfig`)與 portproxy 備忘,**手動使用、非由腳本部署**。 |
| `docs/` | 設計與實作規劃文件(spec / plan)。詳細說明若有需要,放這裡。 |

## 安裝(WSL 主線)

先 clone 到 `~/code/dotfiles`,再擇一執行:

```bash
# 一鍵:基底 + 工具選單
bash script/setup.sh

# 或分開跑
bash script/install-base.sh    # 基底(強制):zsh/git/curl/vim + 插件 + .zshrc + 預設 shell
bash script/install-tools.sh   # 工具(可選):編號多選 fastfetch / bottom / nvm
```

工具選單:空格分隔多選(例 `1 3`),直接 Enter = 全裝。

### .zshrc 部署方式

`install-base.sh` 會把 `~/.zshrc` 建成指向本 repo 的 **symlink**:

```bash
ls -la ~/.zshrc      # 應顯示 ~/.zshrc -> ~/code/dotfiles/.zshrc
```

好處:改 repo 的 `.zshrc`,`git pull` 後立刻生效。若原本已有 `~/.zshrc`,會先備份(通常為 `~/.zshrc.bak`)。

反安裝(還原原本設定):

```bash
rm ~/.zshrc && mv ~/.zshrc.bak ~/.zshrc
```

## 各區塊說明

### zsh (`.zshrc`)
純 zsh,插件從 `~/.config/zsh/` 載入(由 `install-base.sh` git clone,未 vendored 進 repo)。載入 nvm(讓 `claude` / `opencode` 找得到)、設定 pnpm PATH 與共享歷史,並在裝了 `fastfetch` 時開場顯示系統資訊。所有插件 source 皆有防呆,缺檔不會報錯。

### tmux (`.tmux.conf` + `.config/tmux/`)
為多 agent、多 session 的 AI 工作流打造:

- **外掛(TPM)**:`tmux-resurrect` + `tmux-continuum`(session 持久化、還原 pane 內容與 `lazygit`/`yazi` 等程序),外加自製 `fzf_panes.tmux`(fzf 的 MRU pane 選擇器)。
- **狀態列**(`tmux-status/`):組合左右狀態,顯示 ccusage(Claude Code 用量)、每 pane/window 記憶體、todo 數等。
- **腳本**(`scripts/`):編號 session 管理(重命名/排序/搬移)、版面建構、跨平台剪貼簿、以及 agent 自動化(agent palette 彈窗、記住並還原 opencode pane 的工作目錄、resurrect 還原後重啟 Flutter dev server 等)。

依賴:tmux(較新版)、TPM、Python 3、`jq`、`fzf`,以及外部 binary `~/.config/agent-tracker/bin/agent`(**未附**,缺了大部分狀態列/hook 會安靜降級)。

### nvim (`.config/nvim/`)
只版控 `lua/config/options.lua`(依 LazyVim 目錄慣例),設定 `vim.g.clipboard`:SSH 連線用 OSC 52 同步剪貼簿,否則用 Termux 剪貼簿工具。需搭配既有 LazyVim 基底。

### opencode (`.config/opencode/`)
`opencode.json` 設定走 **TeamSync 代理**的多家模型(Gemini/Claude/GPT/DeepSeek/Kimi 等)、MCP servers(`context7`、`sequential-thinking`、`chrome-devtools`)與外掛(`superpowers`、`wakatime`)。`AGENTS.md` 定義「資深全端工程師」persona 與 TDD 工作流(內容與 `ai-agent/development-guidelines.md` 相同)。

### ai-agent (`ai-agent/`)
給各家 AI 工具貼用的 persona / rules 文件,非可執行程式:`development-guidelines.md`(開發準則,opencode `AGENTS.md` 的來源)、`ai-rules.md`(Cursor 風格 rules)、`AGENTS(think-mode)*.md`(「思維總監」對抗式 persona)。

### Termux 桌面腳本 (`script/startxfce_*.sh`、`set-up-tablet.sh`)
**與 WSL 無關**,是 Android/Termux 上的腳本:`set-up-tablet.sh` 首次安裝 XFCE/X11 GUI 堆疊;`startxfce_native.sh` 用軟體渲染直接跑 XFCE;`startxfce_proot.sh` 進 proot-distro Debian 跑 XFCE。

### wsl (`wsl/`)
Windows 主機側檔案,**不由本 repo 腳本部署**:`.wslconfig`(記憶體 16G / swap 8G / 8 CPU / mirrored 網路,需複製到 `%UserProfile%\.wslconfig`)、`command.md`(把 Windows 埠轉發進 WSL 的 `netsh portproxy` 備忘)。

## 依賴一覽

- **平台**:WSL2(Windows)+ Ubuntu 24.04 為主;xfce/tablet 腳本需 Termux(Android)。
- **shell**:zsh、Powerlevel10k、autosuggestions、syntax-highlighting(裝在 `~/.config/zsh/`)。
- **tmux**:tmux、TPM、`tmux-resurrect`/`continuum`、`fzf`、`jq`、Python 3,以及私有 `agent-tracker`(未附)。
- **編輯器**:Neovim + 既有 LazyVim 基底。
- **AI 工具**:Node/nvm、`opencode` CLI、MCP servers(經 `npx`)。
- **可選工具**:`fastfetch`、`bottom`(由 `install-tools.sh` 安裝)。

## ⚠️ 機器特定 / fork 前需自行修改

1. `script/startxfce_proot.sh` **寫死使用者名稱 `henry`**(`su - henry`)。
2. tmux 的 agent 整合依賴**未附的私有 binary** `~/.config/agent-tracker/bin/agent` 及其 `~/.config/agent-tracker/`、`~/.cache/agent/` 狀態檔;缺了功能降級但不致命。
3. `.config/opencode/opencode.json` 綁**私有 TeamSync 代理**,需 `TEAMSYNC_API_KEY` 與數個 `TEAMSYNC_*_BASE_URL` 環境變數,開箱無法直接使用。
4. `ai-agent/ai-rules.md` 綁**特定技術棧**(React+TS+Vite、C#+Python+Node、SQL Server+PostgreSQL)。
5. `wsl/` 內含範例 IP,且需手動複製到 Windows 端。
