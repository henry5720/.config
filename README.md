# dotfiles

個人開發環境設定,主要目標平台是 **WSL2 上的 Ubuntu 24.04**(shell 為純 zsh,無 Oh My Zsh),另含一組 **Termux(Android)** 的桌面環境腳本作為次要用途。

整體圍繞一套 **AI-agent 輔助的 tmux 終端工作流**(opencode、Claude、外部 agent-tracker),疊在標準的 zsh + tmux + nvim 之上。

## 延伸文件

| 文件 | 什麼時候讀 |
|---|---|
| [`docs/ai-agent-setup.md`](docs/ai-agent-setup.md) | 想搞懂 agent 規則 / skill / MCP / plugin 各是什麼、放哪、怎麼更新。**新機器設定 AI 工具前先讀這份。** |
| [`docs/code-server-remote.md`](docs/code-server-remote.md) | 想從 pad / 手機連自己的 code-server,卡在憑證和 secure context 的時候。列出五種做法與各自代價。 |
| [`docs/tmux-workflow.md`](docs/tmux-workflow.md) | 想搞懂 tmux 的狀態列、session 管理、agent 自動化腳本各是什麼,或狀態列少了東西要查為什麼。 |
| [`docs/superpowers/`](docs/superpowers) | zsh setup 腳本當初的設計與實作規劃(spec / plan),歷史紀錄性質。 |

## 目錄結構

`.chezmoiroot` 把 repo 切成兩塊:`home/` 是 chezmoi 的地盤(檔名有前綴規則),其餘 chezmoi 完全看不到。

| 路徑 | 部署到 | 用途 | 詳細 |
|---|---|---|---|
| `home/dot_zshrc` | `~/.zshrc` | 純 zsh:Powerlevel10k、autosuggestions、syntax-highlighting、nvm、pnpm PATH、共享歷史、開場 `fastfetch`。插件從 `~/.config/zsh/` 載入(由 `install-base.sh` clone,未 vendored),缺檔有防呆不會報錯。 | — |
| `home/dot_tmux.conf` + `home/dot_config/tmux/` | `~/.tmux.conf` + `~/.config/tmux/` | 高度客製的 tmux:TPM 外掛、狀態列、編號 session 管理,以及大量 AI-agent 自動化腳本。 | [tmux-workflow.md](docs/tmux-workflow.md) |
| `home/private_dot_ssh/private_config` | `~/.ssh/config`(600) | SSH 連線設定:GitHub、Tailscale 節點、Oracle VPS 兩個 tenancy、Termux(port 8022)。**不含私鑰** —— `~/.ssh/henry5720` 要自己放好並 `chmod 600`,否則所有連線失敗。 | [檔案內有逐段註解](home/private_dot_ssh/private_config) |
| `home/dot_claude/CLAUDE.md` | `~/.claude/CLAUDE.md` | **agent 規則的單一來源**,opencode 那邊 symlink 過來。只寫「換到任何 repo 都還成立」的事。 | [ai-agent-setup.md](docs/ai-agent-setup.md) |
| `home/dot_config/nvim/` | `~/.config/nvim/` | 只有 `lua/config/options.lua`(設 `vim.g.clipboard`:SSH 走 OSC 52,否則用 Termux 剪貼簿),**非完整 nvim 設定**,需搭配既有 LazyVim 基底。 | — |
| `home/dot_config/opencode/` | `~/.config/opencode/` | [opencode](https://opencode.ai) 的 MCP servers 與外掛,**不含模型供應商**,clone 下來要自己 `opencode auth login`。 | [ai-agent-setup.md](docs/ai-agent-setup.md) |
| `home/dot_config/private_code-server/` | `~/.config/code-server/`(目錄 700 / 檔案 600) | code-server 設定 template,密碼由 chezmoi 帶入。 | [code-server-remote.md](docs/code-server-remote.md) |
| `ai-agent/` | — | 兩份 think-mode 對抗式 persona,**手動貼用**,不部署。 | [ai-agent-setup.md](docs/ai-agent-setup.md) |
| `script/ubuntu/` | — | Ubuntu(apt)開發環境安裝:`setup.sh`、`install-base.sh`、`install-tools.sh`。 | [↓](#安裝與部署) |
| `script/termux/` | — | Android/Termux 桌面環境腳本,**與 WSL 無關**:`set-up-tablet.sh` 首次裝 XFCE/X11 堆疊、`startxfce_native.sh` 軟體渲染跑 XFCE、`startxfce_proot.sh` 進 proot-distro Debian 跑 XFCE。 | — |
| `wsl/` | — | Windows 主機側檔案,**不由本 repo 腳本部署**:`.wslconfig`(記憶體 16G / swap 8G / 8 CPU / mirrored 網路,需複製到 `%UserProfile%\.wslconfig`)、`command.md`(`netsh portproxy` 備忘)。 | — |
| `docs/` | — | 說明文件,見上方[延伸文件](#延伸文件)。 | — |
| `CLAUDE.md` | — | 怎麼改這個 repo:檔名前綴語意、秘密怎麼加、驗證方式、註解樣式。 | [CLAUDE.md](CLAUDE.md) |

## 安裝與部署

家目錄的設定檔由 [chezmoi](https://www.chezmoi.io) 部署,新機器兩步:

> ⚠️ 這台機器如果**已經在用**(已有 `~/.zshrc`、`~/.config/opencode/` 等既有設定),
> `chezmoi init --apply` 會**直接覆蓋且不留備份**。先自行備份想留的檔案再跑。

```bash
sudo snap install chezmoi --classic
chezmoi init --apply henry5720
```

會 clone 本 repo 到 `~/.local/share/chezmoi`、部署 `home/` 底下的設定檔到家目錄,
並問一次 code-server 密碼(見[秘密](#秘密))。

**為什麼用 snap**:apt 的套件庫沒有 chezmoi(Debian 有,Ubuntu 沒跟上),而 snap 那份是上游作者
twpayne 本人發布的,還附帶自動升級。想釘住版本用 `sudo snap refresh --hold chezmoi`。

套件安裝是另一條線,chezmoi 不管:

```bash
cd ~/.local/share/chezmoi
bash script/ubuntu/install-base.sh    # 基底(強制):zsh/git/curl/vim + zsh 插件 + chezmoi + 預設 shell
bash script/ubuntu/install-tools.sh   # 工具(可選):編號多選 fastfetch / btop / nvm / code-server
```

工具選單:空格分隔多選(例 `1 3`),直接 Enter = 全裝。兩者順序無所謂——`.zshrc` 對插件缺檔有防呆。

`.tmux.conf` 依賴的 TPM / tmux / `jq` / `fzf` 不在上面兩支腳本的安裝範圍內,要自己裝,
見[依賴一覽](#依賴一覽)。

### chezmoi 怎麼用

常用的就這些:

| 想做的事 | 指令 |
|---|---|
| 改某個設定檔 | `chezmoi edit --apply ~/.zshrc` |
| 看有什麼還沒套用 | `chezmoi diff` |
| 套用 | `chezmoi apply` |
| 把本機的手動修改收回 repo | `chezmoi re-add` |
| 進 source dir(commit / push 在這裡做) | `chezmoi cd` |
| 別台改過、這台要同步 | `chezmoi update`(= pull + apply) |
| 改密碼之類的秘密 | `chezmoi edit-config` 後 `chezmoi apply` |

再細的就交給官方文件:[Daily operations](https://www.chezmoi.io/user-guide/daily-operations/)(完整指令)、
[Target types](https://www.chezmoi.io/reference/target-types/)(`home/` 的檔名前綴 `dot_` /
`private_` / `executable_` / `symlink_`)、
[Templating](https://www.chezmoi.io/user-guide/templating/)(`.tmpl` 的 Go template 寫法)。

只有兩件事是這個 repo / 這個環境特有的,官方文件不會寫:

> ⚠️ **改設定一律走 chezmoi**。直接編輯 `~/.zshrc` 這種已部署的檔案**不會回到 repo**,
> 下次 `chezmoi apply` 還會被蓋掉。要嘛 `chezmoi edit --apply ~/.zshrc`,要嘛改完立刻
> `chezmoi re-add`。改完在 `chezmoi cd` 裡 commit + push,其他機器 `chezmoi update` 收。
> 這是從 symlink 換成 chezmoi 之後唯一真正要改的習慣。

> 在**已經是 zsh** 的終端機裡剛裝完 snap、打 `chezmoi` 找不到?正常的,不是失敗。
> `/snap/bin` 是由部署下來的 `.zshrc` 加進 PATH 的(Ubuntu 的 `/etc/zsh/zprofile` 不 source
> `/etc/profile`,所以 snapd 自己那條加不到 zsh),開一個新終端機就行。全新機器不會遇到——
> 那時還在 bash,`/snap/bin` 本來就在 PATH 裡。

### 秘密

repo 是公開的,秘密一律不進 git。目前只有一個:code-server 密碼 —— `chezmoi init` 時問一次,
存在 `~/.config/chezmoi/chezmoi.toml`(**不在 repo**),以 `{{ .codeServerPassword }}` 帶進
code-server 的 template。

事後改密碼、想換成 argon2 hash,見
[`docs/code-server-remote.md`](docs/code-server-remote.md#密碼放哪)。

## 要改這個 repo

檔名前綴的語意、秘密怎麼加、註解樣式、驗證方式,全在 [`CLAUDE.md`](CLAUDE.md) —— 給 agent 看的,
人要改也照那份。

## 依賴一覽

- **平台**:WSL2(Windows)+ Ubuntu 24.04 為主;xfce/tablet 腳本需 Termux(Android)。
- **dotfile 部署**:chezmoi(snap,由 `install-base.sh` 安裝)。snap 需要 systemd,Ubuntu 24.04 的 WSL 映像預設已開。
- **shell**:zsh、Powerlevel10k、autosuggestions、syntax-highlighting(裝在 `~/.config/zsh/`)。
- **tmux**:tmux、TPM、`tmux-resurrect`/`continuum`、`fzf`、`jq`、Python 3,以及私有 `agent-tracker`(未附)。
- **編輯器**:Neovim + 既有 LazyVim 基底。
- **AI 工具**:Node/nvm、`opencode` CLI、MCP servers(經 `npx`)。
- **可選工具**:`fastfetch`、`btop`、`code-server`(由 `install-tools.sh` 安裝)。

## ⚠️ 機器特定 / fork 前需自行修改

1. `script/termux/startxfce_proot.sh` **寫死使用者名稱 `henry`**(`su - henry`)。
2. tmux 的 agent 整合依賴**未附的私有 binary** `~/.config/agent-tracker/bin/agent` 及其 `~/.config/agent-tracker/`、`~/.cache/agent/` 狀態檔;缺了功能降級但不致命。
3. `home/dot_config/opencode/opencode.json` **沒有設定任何模型供應商**,clone 下來要自己 `opencode auth login`。
4. `home/dot_claude/CLAUDE.md` 是 henry 的**個人回覆偏好**(繁中、白話),fork 前請整份換掉。
5. `home/private_dot_ssh/private_config` 內的 Host 與 `IdentityFile` 是 henry 的,fork 後整份替換。
6. `wsl/` 內含範例 IP,且需手動複製到 Windows 端。
