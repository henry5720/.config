#!/bin/bash
set -euo pipefail

GREEN='\033[0;32m'; BLUE='\033[0;34m'; NC='\033[0m'
DRY_RUN="${DRY_RUN:-0}"
INPUT_SRC="${INPUT_SRC:-/dev/tty}"   # 正式走 tty;測試可覆寫為 /dev/stdin

# repo 根目錄(本腳本在 script/ubuntu/ 底下)
REPO_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"

# 工具清單:編號順序即顯示順序
TOOLS=(fastfetch btop nvm code-server)

install_fastfetch() {
  command -v fastfetch &>/dev/null && { echo -e "${BLUE}✅ fastfetch 已安裝。${NC}"; return; }
  echo -e "${GREEN}📦 安裝 fastfetch (GitHub .deb)...${NC}"
  local url deb
  url=$(curl -fsSL https://api.github.com/repos/fastfetch-cli/fastfetch/releases/latest \
        | grep -o 'https://[^"]*/fastfetch-linux-amd64\.deb' | head -1)
  if [ -z "$url" ]; then
    echo -e "${BLUE}⚠️ 找不到 fastfetch 的 .deb 連結(GitHub API 限流或資產改名?),跳過。${NC}"
    return 0
  fi
  deb=$(mktemp --suffix=.deb)
  curl -fsSL "$url" -o "$deb"
  sudo dpkg -i "$deb" || sudo apt install -f -y
  rm -f "$deb"
}

install_btop() {
  command -v btop &>/dev/null && { echo -e "${BLUE}✅ btop 已安裝。${NC}"; return; }
  echo -e "${GREEN}📦 安裝 btop (apt)...${NC}"
  sudo apt update
  sudo apt install -y btop
}

install_nvm() {
  [ -d "$HOME/.nvm" ] && { echo -e "${BLUE}✅ nvm 已安裝。${NC}"; return; }
  echo -e "${GREEN}📦 安裝 nvm 與 Node.js LTS...${NC}"
  curl -o- https://raw.githubusercontent.com/nvm-sh/nvm/v0.40.1/install.sh | bash
  export NVM_DIR="$HOME/.nvm"
  [ -s "$NVM_DIR/nvm.sh" ] && \. "$NVM_DIR/nvm.sh"
  nvm install --lts
}

install_code_server() {
  if command -v code-server &>/dev/null; then
    echo -e "${BLUE}✅ code-server 已安裝。${NC}"
  else
    echo -e "${GREEN}📦 安裝 code-server (官方安裝腳本)...${NC}"
    curl -fsSL https://code-server.dev/install.sh | sh
  fi

  # 部署設定檔(cp 範本,不是 symlink —— 本機那份要能填密碼,不能進 git)
  local src="$REPO_DIR/.config/code-server/config.yaml.example"
  local dst="$HOME/.config/code-server/config.yaml"
  mkdir -p "$(dirname "$dst")"
  if [ -L "$dst" ]; then
    echo -e "${GREEN}📦 舊版把 config 部署成 symlink,拆掉改 cp${NC}"   # 舊行為的遷移
    rm "$dst"
  fi
  if [ -e "$dst" ]; then
    echo -e "${BLUE}✅ code-server config 已存在,不覆蓋(裡面可能有密碼)。${NC}"
  else
    echo -e "${GREEN}📄 從範本建立 $dst${NC}"
    cp "$src" "$dst"
    chmod 600 "$dst"   # 裡面要填明碼密碼
  fi

  cat <<'EOF'

  設定改 ~/.config/code-server/config.yaml(這份不在 git 裡),密碼也填在那:
    把 `# password: 換成你的密碼` 那行取消註解填進去,明碼即可
  啟動:systemctl --user enable --now code-server   (預設只綁 127.0.0.1:8080)
  從別台連進來的五種做法:docs/code-server-remote.md
EOF
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
  "install_${tool//-/_}"     # code-server → install_code_server
done
echo -e "${GREEN}🎉 工具安裝完成。${NC}"
