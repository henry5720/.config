# dotfiles 改用 chezmoi 管理設計

日期:2026-08-17

## 目標

把家目錄設定檔的部署從「四種各自為政的機制」收斂成單一的 `chezmoi apply`,並讓新機器可以一行 bootstrap。

- **單一部署機制**:取代現行的 zshrc symlink、ssh 三選一、CLAUDE.md 手動 `ln`、code-server `cp` 範本。
- **一行 bootstrap**:新機器 `sh -c "$(curl -fsLS get.chezmoi.io)" -- init --apply henry5720` 即完成所有 dotfile 部署。
- **秘密不進公開 repo**:code-server 密碼改由 `chezmoi init` 互動詢問一次,存在 repo 外。
- **權限自動化**:`~/.ssh` 700 / `config` 600 由 chezmoi 前綴保證,不再靠人手 `chmod`。
- **非家目錄內容不受影響**:`script/`、`docs/`、`wsl/`、`README.md` 維持原狀,chezmoi 看不到。

## 背景與動機

現況有兩個問題。

**一、部署機制四分五裂。** `.zshrc` 走 symlink、`.ssh/config` 由 README 列出 A/B/C 三種讓人自選、`~/.claude/CLAUDE.md` 要手動下 `ln -sfn`、code-server 走 `cp` 範本再手動填密碼。README 有很大篇幅在解釋這些差異與取捨。每加一個檔就要再決定一次「這個走哪條路」。

**二、repo 與機器已經脫節。** 2026-08-17 於主力 WSL 機清點,只有 `.ssh/config` 與 repo 同步:

| repo | 機器實際狀態 |
|---|---|
| `.zshrc`(README 稱 symlink) | 實體檔,且多出註解掉的 TeamSync API key |
| `.ssh/config` | 相同 ✅ |
| `ai-agent/AGENTS.md` → `~/.claude/CLAUDE.md` | 是另一份英文 "Behavioral guidelines",非 symlink |
| `.tmux.conf` + `.config/tmux/`(30+ 腳本) | 不存在 |
| `.config/nvim/` | 不存在 |
| `.config/opencode/opencode.json` | 舊版,仍含明碼 apiKey 的 TeamSync provider |

repo 最大的資產(tmux 那套)在這台從未部署。**這代表遷移的驗收不能用「`chezmoi diff` 為空」**,詳見〈驗收〉。

## 範圍

**做**:家目錄設定檔的部署機制。

**不做**(明確排除,之後可另議):

- `install-base.sh` 的 apt 安裝、zsh 插件 clone、`chsh` 不改成 chezmoi 的 `run_once_` 腳本。
- `install-tools.sh` 的互動選單不動(chezmoi 的 `run_once_` 跑互動選單彆扭)。
- zsh 插件 clone 不改成 `.chezmoiexternal`。
- 不加任何跨平台 template(`{{ if eq .chezmoi.os }}` 之類)。目前只有一台機器,YAGNI。
- Termux(`script/termux/`)不納入 chezmoi。

## 決策

| 項目 | 決定 | 理由 |
|---|---|---|
| repo 結構 | `.chezmoiroot` = `home` | 社群標準做法。repo 根可續留 README/script/docs,chezmoi 不會把它們當 dotfile |
| repo 位置 | 搬到 `~/.local/share/chezmoi` | chezmoi 作者於遷移討論中的建議,亦為主流。一行 bootstrap 建立在預設位置上 |
| 生效方式 | 全面 `chezmoi apply`,不保留 symlink | 混合模型會留下「哪個檔走哪條路」的記憶負擔,正是本次要消滅的東西 |
| 衝突檔 | 四個皆以 repo 為準 | repo 版較新且已清掉失效的 TeamSync provider |
| 規則本體位置 | `home/dot_claude/CLAUDE.md` | 本體須在 home 樹內才會被部署;`~/.claude/` 已存在,不必新開目錄 |

## 目標結構

```
dotfiles/
├── .chezmoiroot                       # 內容一行:home
├── home/                              # chezmoi 唯一看得到的地盤
│   ├── .chezmoi.toml.tmpl             # init 時問一次 code-server 密碼
│   ├── dot_zshrc
│   ├── dot_tmux.conf
│   ├── dot_claude/
│   │   └── CLAUDE.md                  # 規則本體(原 ai-agent/AGENTS.md)
│   ├── private_dot_ssh/
│   │   └── private_config              # 自動 ~/.ssh 700 / config 600
│   └── dot_config/
│       ├── tmux/                      # 32 個可執行檔加 executable_ 前綴
│       ├── nvim/lua/config/options.lua
│       ├── fontconfig/fonts.conf
│       ├── opencode/
│       │   ├── opencode.json
│       │   └── symlink_AGENTS.md.tmpl # → ~/.claude/CLAUDE.md
│       └── private_code-server/
│           └── private_config.yaml.tmpl
├── ai-agent/                          # 只剩兩份 think-mode persona(手動貼用)
├── script/  docs/  wsl/  README.md    # chezmoi 完全看不到
```

### 規則單一來源怎麼變

現況:`ai-agent/AGENTS.md` 是本體,`.config/opencode/AGENTS.md` 是 repo 內的 relative symlink,`~/.claude/CLAUDE.md` 靠手動 `ln -sfn`。

改後:本體搬到 `home/dot_claude/CLAUDE.md`(deploy 為 `~/.claude/CLAUDE.md`),opencode 那邊改成 chezmoi 建的 symlink。單一來源的語意不變,本體換了位置與檔名。

symlink 的來源檔必須是 template,因為 symlink 目標不會展開 `~`:

```
檔名:home/dot_config/opencode/symlink_AGENTS.md.tmpl
內容:{{ .chezmoi.homeDir }}/.claude/CLAUDE.md
```

副作用:檔名從中性的 `AGENTS.md` 變成 Claude 專屬的 `CLAUDE.md`。接受此代價以換取不新開目錄。

`ai-agent/` 保留於 repo 根,只剩 `AGENTS(think-mode).md` 與 `AGENTS(think-mode-long).md` 兩份手動貼用的 persona,本來就不部署。

### 秘密處理

`home/.chezmoi.toml.tmpl`:

```go-template
{{- $codeServerPassword := promptStringOnce . "codeServerPassword" "code-server 密碼" -}}

[data]
    codeServerPassword = {{ $codeServerPassword | quote }}
```

`chezmoi init` 時互動詢問一次,寫進 `~/.config/chezmoi/chezmoi.toml`(repo 外)。`private_config.yaml.tmpl` 以 `{{ .codeServerPassword }}` 帶入。

現行的 `config.yaml.example` + `.gitignore` 擋 `config.yaml` + 手動編輯這三步,一併取代。

## 四個衝突檔的處理

| 檔案 | 動作 | 副作用 |
|---|---|---|
| `~/.zshrc` | repo 版覆蓋 | 註解掉的 TeamSync key 消失。對應 provider 已於 `efcc09d` 判定失效,屬死碼 |
| `~/.claude/CLAUDE.md` | repo 的繁中「個人偏好」覆蓋 | **Claude Code 全域行為改變**。原本那份英文 "Behavioral guidelines" 不再生效 |
| `~/.config/opencode/opencode.json` | repo 版覆蓋 | TeamSync provider 與明碼 apiKey 從機器清掉。要重用需 `opencode auth login` |
| `~/.config/opencode/AGENTS.md` | repo 版覆蓋(改為 symlink) | 機器上那份 158 行的獨立規則文件被刪除,repo 內從未存在,已備份於 `~/.dotfiles-pre-chezmoi-backup/` |

第四項是執行到 Task 5 的閘門才發現的(spec 撰寫當下漏算)。使用者裁示:都以 dotfile 為準,機器上舊的砍掉。

`~/.config/opencode/` 底下的 `agents/`、`commands/`、`node_modules/` 不受影響——chezmoi 只管它認識的檔。

## 遷移步驟

```
1. 建 .chezmoiroot;git mv 家目錄檔進 home/ 並加前綴(含 executable_)
2. code-server 範本改 .tmpl;寫 .chezmoi.toml.tmpl;opencode symlink 改 template
3. 改 install-base.sh(拿掉 .zshrc symlink 那節)
4. 裝 chezmoi;init --source 指到現在的 repo 路徑,不 apply
5. chezmoi diff                          ← 關鍵閘門
6. 備份四個衝突檔;chezmoi apply
7. repo 搬到 ~/.local/share/chezmoi
8. 重寫 README 與 docs/ai-agent-setup.md
```

第 1-5 步都不碰家目錄,可隨時 `git checkout` 回頭。**第 6 步之前不做任何不可逆的事。**

`install-base.sh` 排在第 3 步而非最後,是因為它只改 repo、不碰家目錄,歸在「可回頭」那半邊比較安全。它與第 6 步之間有個空窗:腳本已不再部署 `.zshrc`,而 chezmoi 還沒 apply。這在本機無影響(`~/.zshrc` 已是實體檔),但**空窗期內不要拿這個 branch 去裝新機器**。

第 4 步先讓 chezmoi 就地指向現在的 `~/code/dotfiles`(`~/.config/chezmoi/chezmoi.toml` 的 `sourceDir`),確認 diff/apply 都對之後,第 7 步才搬到預設位置並**移除** `sourceDir` 設定(用預設值)。先驗證再搬家,搬家出錯不會牽連前面的驗收。

實作細節見 `docs/superpowers/plans/2026-08-17-chezmoi-migration.md`。

### 第 8 步的具體改動

`install-base.sh`:刪掉第 3 節(部署 `.zshrc` symlink)。其餘四節(apt、插件 clone、chsh)不動。`REPO_DIR` 變數若因此無人使用則一併移除。

`README.md`:刪除〈zshrc 部署〉〈ssh 部署〉〈AI agent 部署〉三節與〈code-server 部署〉的 `cp` 說明,改為單一的 chezmoi 章節。〈安裝與部署〉的 `~/code/dotfiles` 路徑改成新位置。

`docs/ai-agent-setup.md`:兩處 `ln -sfn ~/code/dotfiles/ai-agent/AGENTS.md ~/.claude/CLAUDE.md` 改為說明由 chezmoi 部署。

`docs/superpowers/` 底下既有的 spec/plan **不動**——那是歷史存檔,寫的是當時的事實。

## 驗收

因為這台機器有一半的檔案從未部署,**`chezmoi diff` 不會是空的**。驗收標準改為「輸出清單等於預期部署清單,無多無少」。

第 5 步的閘門:

```bash
chezmoi status | awk '{print $2}' | sort -u
```

`chezmoi status` 每行的狀態碼分兩欄,行首是第一欄(這台目前都是空白);要核對的檔案清單在第二欄,`awk '{print $2}'` 正是取第二欄。

預期清單 = 新增 tmux 那批 + nvim + fontconfig + ssh config + code-server config + 覆蓋四個衝突檔。逐項核對,出現意料外的項目就停下。

第 6 步 apply 後:

```bash
env -i HOME="$HOME" TERM=dumb /bin/zsh -lic 'echo $PATH' | tr ':' '\n' | grep -E '\.local/bin|\.opencode/bin'
tmux new -d -s _v && tmux kill-session -t _v && echo TMUX_OK
stat -c '%a' ~/.ssh ~/.ssh/config              # 應為 700 / 600
readlink ~/.config/opencode/AGENTS.md          # 應為 ~/.claude/CLAUDE.md
chezmoi verify && echo VERIFY_OK
```

第 7 步後:`chezmoi doctor` 無 error。

第 8 步後:`bash -n script/ubuntu/install-base.sh`;README 與 `docs/ai-agent-setup.md` 不再出現 `~/code/dotfiles`。

## 已知問題(不在本次範圍)

`.config/tmux/scripts/swap_window_in_session.sh` 與 `.config/tmux/tmux-status/ccusage-today.sh` 在 repo 內**沒有執行權限**,其餘 32 個同類都有。tmux 呼叫它們時應會失敗,疑似遺漏。本次照原樣搬移(不加 `executable_` 前綴),維持現狀。要修另開一輪。

## 風險

| 風險 | 緩解 |
|---|---|
| apply 覆蓋掉機器上還在用的東西 | 第 5 步逐項核對 diff;第 6 步先備份四個衝突檔 |
| tmux 設定第一次落地就出錯 | 這台本來就沒有 tmux 設定,失敗不會比現況更差;驗收含 tmux 開得起來 |
| 換掉 `~/.claude/CLAUDE.md` 後 agent 行為變化 | 已知並接受;備份留著,不滿意可還原 |
| repo 搬家後找不到 | `chezmoi cd` / `chezmoi source-path`;README 寫明 |
