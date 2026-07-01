# 純 zsh 安裝腳本重整 Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 重整 `script/` 底下的安裝腳本為純 zsh(砍 Oh My Zsh),分「基底(強制)+ 工具(可選)」兩層,本機與 `curl|bash` 皆可跑。

**Architecture:** 三支平放於 `script/` 的腳本——`install-base.sh`(基底)、`install-tools.sh`(工具,編號多選)、`setup.sh`(入口編排)。`.zshrc` 加固為「缺工具不報錯」的靜態檔,以 symlink 部署,安裝腳本永不 mutate 其內容。

**Tech Stack:** Bash、zsh、apt(Ubuntu 24.04)、git、GitHub releases `.deb`(bottom)、nvm 官方 install script。

## Global Constraints

- 目標平台:WSL **Ubuntu 24.04**,套件管理用 `apt`,架構 `amd64`。
- **冪等**:所有安裝前先檢查是否已存在(沿用現有 `[ ! -d ]` 風格),重跑安全不重複、不報錯。
- **`.zshrc` 只 symlink、不 mutate**:安裝腳本絕不用 `sed`/`echo >>` 改 `.zshrc` 內容。
- **互動一律讀 `/dev/tty`**:`read ... </dev/tty`,確保 `curl|bash` 也能互動。
- repo 位置以 `~/code/dotfiles` 為準(symlink 目標)。
- **不動**無關腳本:`set-up-tablet.sh`、`startxfce_native.sh`、`startxfce_proot.sh`。
- 保留現有彩色 echo 提示風格(`GREEN`/`BLUE`/`NC`)。

## File Structure

- `script/install-base.sh`(新增)— apt 基底套件 + clone 3 插件 + symlink `.zshrc` + chsh。
- `script/install-tools.sh`(新增)— 編號多選選單 + 各工具安裝函式(fastfetch/bottom/nvm)。
- `script/setup.sh`(新增)— 入口:依序呼叫 base → tools,無安裝邏輯本體。
- `.zshrc`(修改)— 插件 source 加防呆、新增 `fastfetch` 條件式開場。
- `README.md`(修改)— 說明兩種跑法、symlink 部署、反安裝。
- `script/setup_linux.sh`(刪除)、`script/install_tools.sh`(刪除)。

---

### Task 1: 加固 `.zshrc`(缺工具不報錯)

**Files:**
- Modify: `/home/henry/code/dotfiles/.zshrc`(第 36-37、47、50 行的 source;第 6 節 alias 區上方加 fastfetch)

**Interfaces:**
- Consumes: 無。
- Produces: 一個「缺任何插件/工具都不報錯」的 `.zshrc`,供 Task 2 的 install-base.sh symlink 部署。

- [ ] **Step 1: 把三個插件的 source 改為「有檔才 source」**

將現有第 36 行:
```zsh
source ~/.config/zsh/powerlevel10k/powerlevel10k.zsh-theme
```
改為:
```zsh
[ -f ~/.config/zsh/powerlevel10k/powerlevel10k.zsh-theme ] \
  && source ~/.config/zsh/powerlevel10k/powerlevel10k.zsh-theme
```

將現有第 47 行:
```zsh
source ~/.config/zsh/zsh-autosuggestions/zsh-autosuggestions.zsh
```
改為:
```zsh
[ -f ~/.config/zsh/zsh-autosuggestions/zsh-autosuggestions.zsh ] \
  && source ~/.config/zsh/zsh-autosuggestions/zsh-autosuggestions.zsh
```

將現有第 50 行:
```zsh
source ~/.config/zsh/zsh-syntax-highlighting/zsh-syntax-highlighting.zsh
```
改為:
```zsh
[ -f ~/.config/zsh/zsh-syntax-highlighting/zsh-syntax-highlighting.zsh ] \
  && source ~/.config/zsh/zsh-syntax-highlighting/zsh-syntax-highlighting.zsh
```

source 順序不變(syntax-highlighting 仍最後)。

- [ ] **Step 2: 在第 6 節「自定義別名」區塊上方新增 fastfetch 條件式開場**

在現有第 52-56 行(`# 6. 自定義別名` 區塊)之前插入:
```zsh
# ===============================================================
# 5.5 開場系統資訊 (只有裝了 fastfetch 才跑)
# ===============================================================
command -v fastfetch &>/dev/null && fastfetch

```

- [ ] **Step 3: 驗證缺插件時不報錯**

在暫時把插件路徑改成不存在的情況下驗證邏輯(不改真實環境):
```bash
zsh -c '[ -f ~/nonexistent/x.zsh ] && source ~/nonexistent/x.zsh; echo GUARD_OK'
```
Expected: 只印出 `GUARD_OK`,無 "no such file or directory"。

- [ ] **Step 4: 驗證現有環境開 zsh 無錯**

Run:
```bash
zsh -ic 'echo ZSHRC_OK' 2>&1 | tail -5
```
Expected: 出現 `ZSHRC_OK`,且無 `source:`/`no such file` 類錯誤(fastfetch 若已裝會印系統資訊,正常)。

- [ ] **Step 5: Commit**

```bash
git add .zshrc
git commit -m "refactor(zshrc): source 插件加防呆、fastfetch 條件式開場"
```

---

### Task 2: `install-base.sh`(基底,強制安裝)

**Files:**
- Create: `/home/henry/code/dotfiles/script/install-base.sh`

**Interfaces:**
- Consumes: Task 1 加固後的 `.zshrc`(symlink 目標)。
- Produces: 可獨立執行的基底安裝腳本;供 Task 4 的 `setup.sh` 呼叫。

- [ ] **Step 1: 寫入完整腳本**

Create `/home/henry/code/dotfiles/script/install-base.sh`:
```bash
#!/bin/bash
set -euo pipefail

GREEN='\033[0;32m'; BLUE='\033[0;34m'; NC='\033[0m'

# repo 根目錄(本腳本在 script/ 底下)
REPO_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
ZSH_PLUGINS_DIR="$HOME/.config/zsh"

echo -e "${BLUE}🚀 安裝基底環境 (zsh + 插件 + .zshrc)...${NC}"

# 1. apt 基底套件
echo -e "${GREEN}📦 更新系統並安裝 zsh/git/curl/vim/build-essential...${NC}"
sudo apt update && sudo apt upgrade -y
sudo apt install -y zsh git curl vim build-essential

# 2. clone 三個 zsh 插件(冪等)
mkdir -p "$ZSH_PLUGINS_DIR"
clone_if_missing() {  # $1=目錄名 $2=git url
  if [ ! -d "$ZSH_PLUGINS_DIR/$1" ]; then
    echo -e "${GREEN}🔌 下載 $1...${NC}"
    git clone --depth=1 "$2" "$ZSH_PLUGINS_DIR/$1"
  else
    echo -e "${BLUE}✅ $1 已存在,跳過。${NC}"
  fi
}
clone_if_missing powerlevel10k        https://github.com/romkatv/powerlevel10k.git
clone_if_missing zsh-autosuggestions  https://github.com/zsh-users/zsh-autosuggestions
clone_if_missing zsh-syntax-highlighting https://github.com/zsh-users/zsh-syntax-highlighting.git

# 3. 部署 .zshrc(symlink,已存在且非本 repo symlink 先備份)
TARGET="$HOME/.zshrc"
SOURCE="$REPO_DIR/.zshrc"
if [ -L "$TARGET" ] && [ "$(readlink -f "$TARGET")" = "$(readlink -f "$SOURCE")" ]; then
  echo -e "${BLUE}✅ ~/.zshrc 已指向 repo,跳過。${NC}"
else
  if [ -e "$TARGET" ] || [ -L "$TARGET" ]; then
    echo -e "${GREEN}📦 備份現有 ~/.zshrc → ~/.zshrc.bak${NC}"
    mv "$TARGET" "$HOME/.zshrc.bak"
  fi
  echo -e "${GREEN}🔗 建立 symlink ~/.zshrc → $SOURCE${NC}"
  ln -s "$SOURCE" "$TARGET"
fi

# 4. 設預設 shell 為 zsh
if [ "$(getent passwd "$USER" | cut -d: -f7)" != "$(which zsh)" ]; then
  echo -e "${GREEN}🔄 切換預設 Shell 為 zsh...${NC}"
  sudo chsh -s "$(which zsh)" "$USER"
else
  echo -e "${BLUE}✅ 預設 Shell 已是 zsh,跳過。${NC}"
fi

echo -e "${GREEN}🎉 基底環境安裝完成。${NC}"
```

- [ ] **Step 2: 語法檢查**

Run:
```bash
bash -n /home/henry/code/dotfiles/script/install-base.sh && echo SYNTAX_OK
```
Expected: `SYNTAX_OK`,無語法錯誤。

- [ ] **Step 3: 驗證 symlink 部署邏輯(不動 apt/chsh)**

在暫存目錄用假 HOME 測試部署段落是否正確建立 symlink + 備份:
```bash
TMP=$(mktemp -d); printf 'old zshrc\n' > "$TMP/.zshrc"
SRC=/home/henry/code/dotfiles/.zshrc
HOME="$TMP"; TARGET="$HOME/.zshrc"
mv "$TARGET" "$HOME/.zshrc.bak"; ln -s "$SRC" "$TARGET"
ls -la "$TARGET" && cat "$HOME/.zshrc.bak"; rm -rf "$TMP"
```
Expected: `~/.zshrc -> .../dotfiles/.zshrc`,且 `.zshrc.bak` 內容為 `old zshrc`。

- [ ] **Step 4: Commit**

```bash
chmod +x /home/henry/code/dotfiles/script/install-base.sh
git add script/install-base.sh
git commit -m "feat(script): 新增純 zsh 基底安裝腳本 install-base.sh"
```

---

### Task 3: `install-tools.sh`(工具,編號多選)

**Files:**
- Create: `/home/henry/code/dotfiles/script/install-tools.sh`

**Interfaces:**
- Consumes: 無(獨立)。
- Produces: 可獨立執行的工具安裝腳本;供 Task 4 的 `setup.sh` 呼叫。支援 `DRY_RUN=1` 只印出「會裝什麼」不實裝、`INPUT_SRC` 覆寫讀取來源(供測試/預覽;正式預設 `/dev/tty`)。

- [ ] **Step 1: 寫入完整腳本**

Create `/home/henry/code/dotfiles/script/install-tools.sh`:
```bash
#!/bin/bash
set -euo pipefail

GREEN='\033[0;32m'; BLUE='\033[0;34m'; NC='\033[0m'
DRY_RUN="${DRY_RUN:-0}"
INPUT_SRC="${INPUT_SRC:-/dev/tty}"   # 正式走 tty;測試可覆寫為 /dev/stdin

# 工具清單:編號順序即顯示順序
TOOLS=(fastfetch bottom nvm)

install_fastfetch() {
  command -v fastfetch &>/dev/null && { echo -e "${BLUE}✅ fastfetch 已安裝。${NC}"; return; }
  echo -e "${GREEN}📦 安裝 fastfetch (apt)...${NC}"
  sudo apt install -y fastfetch
}

install_bottom() {
  command -v btm &>/dev/null && { echo -e "${BLUE}✅ bottom 已安裝。${NC}"; return; }
  echo -e "${GREEN}📦 安裝 bottom (GitHub .deb)...${NC}"
  local url deb
  url=$(curl -fsSL https://api.github.com/repos/ClementTsang/bottom/releases/latest \
        | grep -o 'https://[^"]*_amd64\.deb' | head -1)
  deb=$(mktemp --suffix=.deb)
  curl -fsSL "$url" -o "$deb"
  sudo dpkg -i "$deb" || sudo apt install -f -y
  rm -f "$deb"
}

install_nvm() {
  [ -d "$HOME/.nvm" ] && { echo -e "${BLUE}✅ nvm 已安裝。${NC}"; return; }
  echo -e "${GREEN}📦 安裝 nvm 與 Node.js LTS...${NC}"
  curl -o- https://raw.githubusercontent.com/nvm-sh/nvm/v0.40.1/install.sh | bash
  export NVM_DIR="$HOME/.nvm"
  [ -s "$NVM_DIR/nvm.sh" ] && \. "$NVM_DIR/nvm.sh"
  nvm install --lts
}

# 顯示選單並讀取選擇
echo "請選擇要安裝的工具 (空格分隔多選,直接 Enter = 全裝):"
for i in "${!TOOLS[@]}"; do
  printf "  %d) %s\n" "$((i+1))" "${TOOLS[$i]}"
done
printf "> "
picks=()
read -a picks <"$INPUT_SRC" || true   # EOF/空輸入不因 set -e 中止

# 決定要裝的清單
selected=()
if [ "${#picks[@]}" -eq 0 ]; then
  selected=("${TOOLS[@]}")                 # Enter = 全裝
else
  for n in "${picks[@]}"; do
    if [[ "$n" =~ ^[0-9]+$ ]] && [ "$n" -ge 1 ] && [ "$n" -le "${#TOOLS[@]}" ]; then
      selected+=("${TOOLS[$((n-1))]}")     # 有效編號
    fi                                      # 無效編號忽略
  done
fi

if [ "${#selected[@]}" -eq 0 ]; then
  echo -e "${BLUE}未選擇任何工具,結束。${NC}"; exit 0
fi

echo -e "${GREEN}將安裝:${selected[*]}${NC}"
if [ "$DRY_RUN" = "1" ]; then
  echo "DRY_RUN: 不實際安裝。"; exit 0
fi

for tool in "${selected[@]}"; do
  "install_${tool}"
done
echo -e "${GREEN}🎉 工具安裝完成。${NC}"
```

- [ ] **Step 2: 語法檢查**

Run:
```bash
bash -n /home/henry/code/dotfiles/script/install-tools.sh && echo SYNTAX_OK
```
Expected: `SYNTAX_OK`。

- [ ] **Step 3: 驗證選擇解析——多選子集**

Run(用 DRY_RUN 預覽 + INPUT_SRC 從 stdin 餵輸入取代 tty):
```bash
DRY_RUN=1 INPUT_SRC=/dev/stdin bash /home/henry/code/dotfiles/script/install-tools.sh <<< "1 3"
```
Expected: 印出 `將安裝:fastfetch nvm` 與 `DRY_RUN: 不實際安裝。`(正式執行不設 `INPUT_SRC`,走 `/dev/tty`)。

- [ ] **Step 4: 驗證選擇解析——Enter 全裝與無效編號**

Run:
```bash
DRY_RUN=1 INPUT_SRC=/dev/stdin bash /home/henry/code/dotfiles/script/install-tools.sh <<< ""    # 全裝
DRY_RUN=1 INPUT_SRC=/dev/stdin bash /home/henry/code/dotfiles/script/install-tools.sh <<< "9 2" # 忽略 9,只留 bottom
```
Expected: 第一個印 `將安裝:fastfetch bottom nvm`;第二個印 `將安裝:bottom`。

- [ ] **Step 5: Commit**

```bash
chmod +x /home/henry/code/dotfiles/script/install-tools.sh
git add script/install-tools.sh
git commit -m "feat(script): 新增工具編號多選安裝腳本 install-tools.sh"
```

---

### Task 4: `setup.sh`(入口編排)

**Files:**
- Create: `/home/henry/code/dotfiles/script/setup.sh`

**Interfaces:**
- Consumes: Task 2 的 `install-base.sh`、Task 3 的 `install-tools.sh`。
- Produces: 一鍵入口。

- [ ] **Step 1: 寫入完整腳本**

Create `/home/henry/code/dotfiles/script/setup.sh`:
```bash
#!/bin/bash
set -euo pipefail

BLUE='\033[0;34m'; NC='\033[0m'
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

echo -e "${BLUE}=== 開發環境安裝 (WSL Ubuntu) ===${NC}"

# 階段一:基底(強制)
bash "$SCRIPT_DIR/install-base.sh"

# 階段二:工具(可選,編號多選)
bash "$SCRIPT_DIR/install-tools.sh"

echo -e "${BLUE}=== 完成!重開終端機或執行 'zsh' 生效 ===${NC}"
```

- [ ] **Step 2: 語法檢查**

Run:
```bash
bash -n /home/henry/code/dotfiles/script/setup.sh && echo SYNTAX_OK
```
Expected: `SYNTAX_OK`。

- [ ] **Step 3: Commit**

```bash
chmod +x /home/henry/code/dotfiles/script/setup.sh
git add script/setup.sh
git commit -m "feat(script): 新增入口編排腳本 setup.sh"
```

---

### Task 5: 刪除舊腳本 + 更新 README

**Files:**
- Delete: `/home/henry/code/dotfiles/script/setup_linux.sh`
- Delete: `/home/henry/code/dotfiles/script/install_tools.sh`
- Modify: `/home/henry/code/dotfiles/README.md`

**Interfaces:**
- Consumes: Task 2-4 的三支新腳本(README 需引用其用法)。
- Produces: 乾淨的 `script/` 目錄與完整 README。

- [ ] **Step 1: 刪除舊的兩支腳本**

Run:
```bash
git rm /home/henry/code/dotfiles/script/setup_linux.sh /home/henry/code/dotfiles/script/install_tools.sh
```
Expected: 兩檔被移除;`set-up-tablet.sh`、`startxfce_native.sh`、`startxfce_proot.sh` 仍在。

- [ ] **Step 2: 覆寫 README.md**

覆寫 `/home/henry/code/dotfiles/README.md`:
```markdown
# dotfiles

WSL Ubuntu 24.04 的個人環境設定(純 zsh,無 Oh My Zsh)。

## 安裝

先 clone 到 `~/code/dotfiles`,再擇一執行:

```bash
# 一鍵:基底 + 工具選單
bash script/setup.sh

# 或分開跑
bash script/install-base.sh    # 基底(強制):zsh/git/curl/vim + 插件 + .zshrc + 預設 shell
bash script/install-tools.sh   # 工具(可選):編號多選 fastfetch / bottom / nvm
```

工具選單:空格分隔多選(例 `1 3`),直接 Enter = 全裝。

## .zshrc 部署方式

`install-base.sh` 會把 `~/.zshrc` 建成指向本 repo 的 **symlink**:

```bash
ls -la ~/.zshrc      # 應顯示 ~/.zshrc -> ~/code/dotfiles/.zshrc
```

好處:改 repo 的 `.zshrc`,`git pull` 後立刻生效。若原本已有 `~/.zshrc`,會先備份成 `~/.zshrc.bak`。

## 反安裝 .zshrc(還原原本設定)

```bash
rm ~/.zshrc && mv ~/.zshrc.bak ~/.zshrc
```
```

- [ ] **Step 3: Commit**

```bash
git add README.md
git commit -m "docs: 刪除舊 omz 腳本並更新 README(純 zsh + symlink 說明)"
```

---

## 全流程手動驗收(在真實 WSL 上執行一次)

以下需 sudo/apt/chsh,由你在目標機上實跑確認:

1. `bash script/install-base.sh` → 基底套件裝好、`~/.config/zsh/` 有 3 插件、`ls -la ~/.zshrc` 是指向 repo 的 symlink、預設 shell 為 zsh;**再跑一次**全部印「已存在,跳過」,無錯。
2. `bash script/install-tools.sh` → 選單出現;輸入 `1 3` 只裝 fastfetch+nvm;Enter 全裝;`curl|bash` 情境亦能互動(`/dev/tty`)。
3. `bash script/setup.sh` → 基底 + 工具選單一條龍。
4. 只裝部分工具時,開新 zsh **不報任何 error**(未裝的 fastfetch/nvm 被防呆略過)。
5. `ls script/` 確認舊 `setup_linux.sh`、`install_tools.sh` 已無;xfce/tablet 腳本仍在。
