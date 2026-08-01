# dotfiles

個人開發環境設定,主要目標平台是 **WSL2 上的 Ubuntu 24.04**(shell 為純 zsh,無 Oh My Zsh),另含一組 **Termux(Android)** 的桌面環境腳本作為次要用途。

整體圍繞一套 **AI-agent 輔助的 tmux 終端工作流**(opencode、Claude、外部 agent-tracker),疊在標準的 zsh + tmux + nvim 之上。

## 目錄結構

| 路徑 | 用途 |
|---|---|
| `.zshrc` | 純 zsh 設定:Powerlevel10k、`zsh-autosuggestions`、`zsh-syntax-highlighting`(從 `~/.config/zsh/` 載入)、nvm、開場 `fastfetch`。 |
| `.tmux.conf` + `.config/tmux/` | 高度客製的 tmux:TPM 外掛、狀態列、編號 session 管理,以及大量 AI-agent 自動化腳本(見下方 tmux 段)。 |
| `.ssh/config` | SSH 連線設定:GitHub、Tailscale 節點(laptop/desktop/nettop、Termux 的 pad/phone)、Oracle VPS。`phone` 帶 code-server/dev 埠轉發。**不含私鑰**,部署方式見下方 ssh 段。 |
| `.config/nvim/` | 只有 `lua/config/options.lua` 一個片段(剪貼簿處理),需搭配既有的 LazyVim 安裝,**非完整 nvim 設定**。 |
| `.config/opencode/` | [opencode](https://opencode.ai)(終端 AI coding agent)設定:模型供應商、MCP servers、外掛;`AGENTS.md` 為 persona/工作流指示。 |
| `ai-agent/` | 給各家 AI 工具用的 persona / rules 文件(開發準則、Cursor rules、think-mode 等)。 |
| `script/ubuntu/` | Ubuntu(apt)開發環境安裝:`setup.sh`、`install-base.sh`、`install-tools.sh`。 |
| `script/termux/` | Android/Termux 桌面環境腳本(xfce/tablet),與 Ubuntu 無關。 |
| `wsl/` | Windows 主機側的 WSL2 設定(`.wslconfig`)與 portproxy 備忘,**手動使用、非由腳本部署**。 |
| `docs/` | 設計與實作規劃文件(spec / plan)。詳細說明若有需要,放這裡。 |

## 安裝(WSL 主線)

先 clone 到 `~/code/dotfiles`,再擇一執行:

```bash
# 一鍵:基底 + 工具選單
bash script/ubuntu/setup.sh

# 或分開跑
bash script/ubuntu/install-base.sh    # 基底(強制):zsh/git/curl/vim + 插件 + .zshrc + 預設 shell
bash script/ubuntu/install-tools.sh   # 工具(可選):編號多選 fastfetch / bottom / nvm
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

### ssh 部署(手動,無腳本)

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
`opencode.json` 設定走 **TeamSync 代理**的多家模型(Gemini/Claude/GPT/DeepSeek/Kimi 等)、MCP servers(`context7`、`sequential-thinking`、`chrome-devtools`)與外掛(`superpowers`、`wakatime`)。`AGENTS.md` 定義「資深全端工程師」persona 與 TDD 工作流,是這套開發準則的唯一來源。

### ai-agent (`ai-agent/`)
給各家 AI 工具貼用的 persona / rules 文件,非可執行程式:`ai-rules.md`(Cursor 風格 rules)、`AGENTS(think-mode)*.md`(「思維總監」對抗式 persona)。開發準則本身以 `.config/opencode/AGENTS.md` 為單一來源。

### Termux 桌面腳本 (`script/termux/`)
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

1. `script/termux/startxfce_proot.sh` **寫死使用者名稱 `henry`**(`su - henry`)。
2. tmux 的 agent 整合依賴**未附的私有 binary** `~/.config/agent-tracker/bin/agent` 及其 `~/.config/agent-tracker/`、`~/.cache/agent/` 狀態檔;缺了功能降級但不致命。
3. `.config/opencode/opencode.json` 綁**私有 TeamSync 代理**,需 `TEAMSYNC_API_KEY` 與數個 `TEAMSYNC_*_BASE_URL` 環境變數,開箱無法直接使用。
4. `ai-agent/ai-rules.md` 綁**特定技術棧**(React+TS+Vite、C#+Python+Node、SQL Server+PostgreSQL)。
5. `wsl/` 內含範例 IP,且需手動複製到 Windows 端。
