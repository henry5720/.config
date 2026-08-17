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

`.chezmoiroot` 把 repo 切成兩塊:`home/` 是 chezmoi 的地盤(檔名有前綴規則),其餘 chezmoi 完全看不到。

| 路徑 | 部署到 | 用途 | 詳細 |
|---|---|---|---|
| `home/dot_zshrc` | `~/.zshrc` | 純 zsh 設定:Powerlevel10k、autosuggestions、syntax-highlighting、nvm、開場 `fastfetch`。 | [↓](#zsh) |
| `home/dot_tmux.conf` + `home/dot_config/tmux/` | `~/.tmux.conf` + `~/.config/tmux/` | 高度客製的 tmux:TPM 外掛、狀態列、編號 session 管理,以及大量 AI-agent 自動化腳本。 | [↓](#tmux) |
| `home/private_dot_ssh/private_config` | `~/.ssh/config`(600) | SSH 連線設定:GitHub、Tailscale 節點、Oracle VPS。**不含私鑰**。 | [↓](#ssh) |
| `home/dot_claude/CLAUDE.md` | `~/.claude/CLAUDE.md` | **agent 規則的單一來源**,opencode 那邊 symlink 過來。 | [↓](#ai-agent-規則) |
| `home/dot_config/nvim/` | `~/.config/nvim/` | 只有 `lua/config/options.lua` 一個片段(剪貼簿處理),**非完整 nvim 設定**。 | [↓](#nvim) |
| `home/dot_config/opencode/` | `~/.config/opencode/` | [opencode](https://opencode.ai) 設定:MCP servers 與外掛,**不含模型供應商**。 | [↓](#opencode) |
| `home/dot_config/private_code-server/` | `~/.config/code-server/`(目錄 700 / 檔案 600) | code-server 設定 template,密碼由 chezmoi 帶入。 | [↓](#code-server) |
| `ai-agent/` | — | 兩份 think-mode 對抗式 persona,**手動貼用**,不部署。 | [↓](#ai-agent-規則) |
| `script/ubuntu/` | — | Ubuntu(apt)開發環境安裝:`setup.sh`、`install-base.sh`、`install-tools.sh`。 | [↓](#安裝與部署) |
| `script/termux/` | — | Android/Termux 桌面環境腳本(xfce/tablet),與 Ubuntu 無關。 | [↓](#termux) |
| `wsl/` | — | Windows 主機側的 WSL2 設定與 portproxy 備忘,**手動使用**。 | [↓](#wsl) |
| `docs/` | — | 說明文件,見上方[延伸文件](#延伸文件)。 | — |

## 安裝與部署

家目錄的設定檔由 [chezmoi](https://www.chezmoi.io) 部署,新機器一行:

> ⚠️ 這台機器如果**已經在用**(已有 `~/.zshrc`、`~/.config/opencode/` 等既有設定),
> `chezmoi init --apply` 會**直接覆蓋且不留備份**。先自行備份想留的檔案再跑這行。

```bash
sh -c "$(curl -fsLS get.chezmoi.io)" -- -b "$HOME/.local/bin" init --apply henry5720
```

`-b "$HOME/.local/bin"` 不能省——安裝腳本預設把 binary 裝到**相對路徑** `./bin`(當前目錄下),
不帶這個參數的話 chezmoi 會裝到執行當下的 `$PWD/bin`,不在任何 PATH 裡,下一步就
`chezmoi: command not found`。

這行做三件事:裝 chezmoi、clone 本 repo 到 `~/.local/share/chezmoi`、把 `home/` 底下的設定檔部署到家目錄。過程中會問一次 code-server 密碼(見[秘密](#秘密))。

套件安裝是另一條線,chezmoi 不管:

```bash
cd ~/.local/share/chezmoi
bash script/ubuntu/install-base.sh    # 基底(強制):zsh/git/curl/vim + zsh 插件 + 預設 shell
bash script/ubuntu/install-tools.sh   # 工具(可選):編號多選 fastfetch / btop / nvm / code-server
```

工具選單:空格分隔多選(例 `1 3`),直接 Enter = 全裝。兩者順序無所謂——`.zshrc` 對插件缺檔有防呆。

`.tmux.conf` 依賴的 TPM / tmux / `jq` / `fzf` 不在上面兩支腳本的安裝範圍內,要自己裝,
見[依賴一覽](#依賴一覽)。

### 日常操作

> 剛跑完 bootstrap 的同一個終端機裡打 `chezmoi` 找不到？正常的,不是失敗。`~/.local/bin` 要新開終端機或重新登入才進 PATH,開一個新終端機就行。

| 想做的事 | 指令 |
|---|---|
| 改某個設定檔 | `chezmoi edit --apply ~/.zshrc` |
| 進 repo 目錄 | `chezmoi cd` |
| 別台改過、這台要同步 | `chezmoi update`(= pull + apply) |
| 看有什麼還沒套用 | `chezmoi diff` |
| 把本機的手動修改收回 repo | `chezmoi re-add` |
| 改密碼之類的秘密 | `chezmoi edit-config` 後 `chezmoi apply` |

> ⚠️ 直接編輯 `~/.zshrc` 這種**已部署的檔案不會回到 repo**,下次 `chezmoi apply` 還會被蓋掉。
> 要嘛用 `chezmoi edit`,要嘛改完立刻 `chezmoi re-add`。這是從 symlink 換成 chezmoi 之後
> 唯一真正要改的習慣。

### 檔名前綴

`home/` 底下的檔名有規則,對應到部署後的樣子:

| 前綴 / 後綴 | 意思 |
|---|---|
| `dot_` | 部署成 `.` 開頭 |
| `private_` | 權限收成 600(目錄 700) |
| `executable_` | 部署後帶 +x |
| `symlink_` | 部署成 symlink,檔案內容就是連結目標 |
| `.tmpl` | 先跑 Go template 再部署 |

### 秘密

repo 是公開的,秘密一律不進 git。目前只有一個:code-server 密碼。

`chezmoi init` 時問一次,存在 `~/.config/chezmoi/chezmoi.toml`(**不在 repo**),由
`home/dot_config/private_code-server/private_config.yaml.tmpl` 的 `{{ .codeServerPassword }}` 帶入。

### ssh

`~/.ssh/config` 由 chezmoi 部署,權限自動收成 `~/.ssh` 700 / `config` 600,不必手動 `chmod`。

**先決條件**:私鑰 `~/.ssh/henry5720`(config 內所有 Host 的 `IdentityFile`,**未附於 repo**)
要自己放好並 `chmod 600`,否則所有連線失敗。

> 原本 README 列的 Include / symlink / copy 三種部署方式已取消——chezmoi 統一走一種。
> 若某台機器需要額外的本機 Host,在 `home/private_dot_ssh/private_config` 加 template 條件,
> 不要在家目錄直接改(會被下次 apply 蓋掉)。

### AI agent 規則

規則本體是 `home/dot_claude/CLAUDE.md`,部署成 `~/.claude/CLAUDE.md`。
opencode 那邊的 `~/.config/opencode/AGENTS.md` 是 chezmoi 建的 symlink 指過去,**不用手動 `ln`**。

本 repo 只管**規則**;skill、MCP、plugin 是訂閱來的,不進本 repo。
四者的差別、各自怎麼裝與更新,見 [`docs/ai-agent-setup.md`](docs/ai-agent-setup.md)。

### code-server

`install-tools.sh` 的選單裡選 `code-server` 會用官方腳本裝 binary;設定檔由 chezmoi 部署,
密碼見[秘密](#秘密)。

```bash
code-server     # 要用的時候再開,丟 tmux 裡
```

要它一直在(重開機自動起、沒開終端機也活著)才需要 systemd,
`systemctl --user enable --now code-server` 加 `sudo loginctl enable-linger "$USER"`。
手動開就用不到——WSL 反正重開機也不會自己起來。

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

`.config/opencode/opencode.json` —— 只放 MCP servers(`context7`、`sequential-thinking`、
`chrome-devtools`)與 `opencode-wakatime` 外掛。

**沒有 `provider` 區塊**:opencode 內建認得的 provider 用 `opencode auth login` 就好,
手寫 provider 只有「自訂 base URL 的代理」才需要。原本那份 TeamSync 代理設定已經失效,
留著只會在選單裡出現選了就噴錯的模型,所以整段拿掉。要撈回來當模板:

```bash
git log --oneline -- .config/opencode/opencode.json   # 找到移除前那個 commit
git show <commit>:.config/opencode/opencode.json
```

**沒有 `superpowers` 外掛**:別人的 skill 不用 opencode plugin 這條路裝,理由和裝法見
[`docs/ai-agent-setup.md`](docs/ai-agent-setup.md)。

`~/.config/opencode/AGENTS.md` 是 chezmoi 建的 symlink,指向 `~/.claude/CLAUDE.md`。

### ai-agent

規則本體已搬到 `home/dot_claude/CLAUDE.md` —— 跨 repo、跨 agent 的**規則單一來源**。刻意只寫「換到任何一個 repo
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

## 檔案慣例

註解樣式看檔案是哪一種,兩種不要互相看齊:

- **設定檔**(`.zshrc`、`.ssh/config`、`home/dot_config/private_code-server/private_config.yaml.tmpl`)——一堆彼此無關的
  設定並排、會跳著找,用 `# ===` 橫幅 + 編號當目錄。
- **流程腳本**(`script/ubuntu/*.sh`)——從上到下跑一次、步驟有先後,用純 `# 1.` `# 2.` 編號。
  橫幅會讓步驟看起來像可以各自獨立看的模組,但順序就是全部。

判準不是長度(`.zshrc` 64 行有橫幅,`install-tools.sh` 113 行沒有),是「跳著讀」還是「一路讀到底」。

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
3. `.config/opencode/opencode.json` **沒有設定任何模型供應商**,clone 下來要自己 `opencode auth login`。
4. `home/dot_claude/CLAUDE.md` 是 henry 的**個人回覆偏好**(繁中、白話),fork 前請整份換掉。
5. `home/private_dot_ssh/private_config` 內的 Host 與 `IdentityFile` 是 henry 的,fork 後整份替換。
6. `wsl/` 內含範例 IP,且需手動複製到 Windows 端。
