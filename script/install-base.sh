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
    BACKUP="$HOME/.zshrc.bak"
    [ -e "$BACKUP" ] && BACKUP="$HOME/.zshrc.bak.$(date +%Y%m%d%H%M%S)"  # 別覆蓋既有備份
    echo -e "${GREEN}📦 備份現有 ~/.zshrc → $BACKUP${NC}"
    mv "$TARGET" "$BACKUP"
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
