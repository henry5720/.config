# 重整 dotfiles 安裝腳本(純 zsh)設計

日期:2026-07-01

## 目標

重整 `script/` 底下的安裝腳本,達成:

- **純 zsh**:砍掉 Oh My Zsh,只維護一套與現有 `.zshrc` 一致的純 zsh 配置。
- **分層安裝**:基底一律裝、工具自選。
- **兩種跑法皆可**:本機 `bash script/setup.sh`,以及 `curl ... | bash` 一行流。
- **解耦**:`.zshrc` 是版控的靜態產物,安裝腳本只 symlink、絕不 mutate 其內容。

## 背景與動機

現況兩支 script 互相矛盾:

- `setup_linux.sh`:Oh My Zsh 版,裝到 `~/.oh-my-zsh/custom/`,還用 `sed`/`echo` 改 `~/.zshrc`。
- `install_tools.sh`:純 zsh 版(其實裝的是插件),裝到 `~/.config/zsh/`,與現有 `.zshrc` 一致。

現有 `.zshrc` 已是純 zsh(手動 source p10k / autosuggestions / syntax-highlighting,自己 `compinit`),`setup_linux.sh` 裝的東西根本沒被讀取。決定:**砍 omz,統一純 zsh。**(未來若要遷回 omz 也很快,不預留兩版。)

## 分層

| 層 | 內容 | 可選? | 原因 |
|---|---|---|---|
| 基底(強制) | zsh, git, curl, vim, build-essential + 3 個 zsh 插件 + 部署 `.zshrc` + chsh | ❌ 一律裝 | `.zshrc` 無條件依賴插件;git/curl 是 clone 插件的前提 |
| 工具(可選) | fastfetch, bottom, nvm | ✅ 編號多選 | `.zshrc` 對這些皆有防呆或不 source,缺了不影響 shell |

「插件」不獨立成一層——它與 zsh 環境同生共死,併入基底。

## 檔案結構

`script/` 平放、語意命名:

```
script/
  install-base.sh    # 基底(強制)
  install-tools.sh   # 工具(可選,編號多選)
  setup.sh           # 入口:先 base 後 tools
```

- 三支皆可獨立執行。
- `setup.sh` 只編排、不重複安裝邏輯。
- **取代**舊的 `setup_linux.sh`、`install_tools.sh`(刪除)。
- **不動**無關腳本:`set-up-tablet.sh`、`startxfce_native.sh`、`startxfce_proot.sh`。

## 各腳本行為

### install-base.sh

1. `apt update && apt upgrade -y`
2. `apt install -y zsh git curl vim build-essential`
3. clone 3 個插件到 `~/.config/zsh/`(存在則跳過,冪等):
   - powerlevel10k
   - zsh-autosuggestions
   - zsh-syntax-highlighting
4. 部署 `.zshrc`:**symlink** `~/.zshrc` → repo 內的 `.zshrc`(已存在且非本 repo symlink 時先備份)。
5. `chsh -s $(which zsh)` 設預設 shell。

### install-tools.sh

編號多選選單:

```
請選擇要安裝的工具 (空格分隔多選,直接 Enter = 全裝):
  1) fastfetch
  2) bottom
  3) nvm
>
```

- 一律 `read -a picks </dev/tty`(本機與 `curl|bash` 皆可互動)。
- 空格分隔多選;空輸入(Enter)= 全裝;無效編號忽略。
- 每個工具用各自最合適的安裝法,實作時逐一確認:
  - fastfetch:apt(Ubuntu 24.04+ 有);舊版需 PPA 或 GitHub `.deb`。
  - bottom:apt 通常沒有,用 GitHub releases 的 `.deb`。
  - nvm:官方 install script,裝完 `nvm install --lts`。
- 全部安裝前先檢查是否已存在(冪等)。

### setup.sh

入口編排:依序呼叫 `install-base.sh` → `install-tools.sh`。不含任何安裝邏輯本體。

## .zshrc 加固(選項 1:靜態自我偵測)

**原則:`.zshrc` 寫一次寫到穩,缺工具不報錯;安裝腳本永不改其內容。**

- 已知工具的整合行「預先寫好且防呆」→ 沒裝時休眠、裝了自動生效,零手改。
- 未來新工具需 shell 整合時,由人在版控的 `.zshrc` 手動加一行防呆、commit(只有人知道想怎麼整合)。

具體修改:

```zsh
# nvm — 已是防呆,保持
[ -s "$NVM_DIR/nvm.sh" ] && \. "$NVM_DIR/nvm.sh"

# fastfetch — 只有裝了才開場跑(新增)
command -v fastfetch &>/dev/null && fastfetch

# 插件 — 由無條件 source 改為有檔才 source(加固)
[ -f ~/.config/zsh/powerlevel10k/powerlevel10k.zsh-theme ] \
  && source ~/.config/zsh/powerlevel10k/powerlevel10k.zsh-theme
[ -f ~/.config/zsh/zsh-autosuggestions/zsh-autosuggestions.zsh ] \
  && source ~/.config/zsh/zsh-autosuggestions/zsh-autosuggestions.zsh
[ -f ~/.config/zsh/zsh-syntax-highlighting/zsh-syntax-highlighting.zsh ] \
  && source ~/.config/zsh/zsh-syntax-highlighting/zsh-syntax-highlighting.zsh
```

`bottom` 不需任何 `.zshrc` 配置。source 順序不變(syntax-highlighting 仍最後)。

## 通用原則

- **冪等**:所有安裝前先檢查是否已存在(沿用現有 `[ ! -d ]` 風格),重跑安全。
- **目標平台**:WSL Ubuntu(apt)。
- 有顏色輸出的 echo 提示(沿用現有風格)。

## 驗收標準

1. `bash script/install-base.sh` 在乾淨環境裝好 zsh + 插件 + symlink `.zshrc` + chsh,重跑不重複/不報錯。
2. `bash script/install-tools.sh` 跳出選單;`1 3` 只裝 fastfetch+nvm;Enter 全裝;本機與 `curl|bash` 皆能互動。
3. `bash script/setup.sh` 一條龍:基底 + 工具選單。
4. 任一工具未裝時,開啟 zsh **不報任何 error**。
5. 舊 `setup_linux.sh`、`install_tools.sh` 已刪除;xfce/tablet 腳本未被更動。
```