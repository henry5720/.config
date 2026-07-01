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
