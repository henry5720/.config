#!/bin/bash
set -euo pipefail

# 用途:在低記憶體 server 建立 swapfile 當安全網,避免 OOM killer 砍行程。
# 用法:bash setup-swap.sh [大小]   例:bash setup-swap.sh 2G(預設 2G)
# 冪等:已有 /swapfile 或已掛 swap 就跳過;不重複寫入 fstab。

GREEN='\033[0;32m'; BLUE='\033[0;34m'; YELLOW='\033[1;33m'; NC='\033[0m'

SWAPFILE="/swapfile"
SIZE="${1:-2G}"
SWAPPINESS="${SWAPPINESS:-10}"   # server 建議 10:優先用 RAM,swap 只在吃緊時動

# 已經有 swap 就不重複開
if [ -n "$(swapon --show)" ]; then
  echo -e "${BLUE}✅ 系統已有 swap,跳過建立:${NC}"
  swapon --show
  exit 0
fi

if [ -e "$SWAPFILE" ]; then
  echo -e "${YELLOW}⚠️ $SWAPFILE 已存在但未啟用。請先確認內容再處理,本腳本不覆蓋。${NC}"
  exit 1
fi

echo -e "${GREEN}📦 建立 $SIZE swapfile:$SWAPFILE ...${NC}"
sudo fallocate -l "$SIZE" "$SWAPFILE"
sudo chmod 600 "$SWAPFILE"
sudo mkswap "$SWAPFILE"
sudo swapon "$SWAPFILE"

# 開機自動掛載(避免重開就沒了),不重複寫入
if ! grep -qF "$SWAPFILE" /etc/fstab; then
  echo -e "${GREEN}🔗 寫入 /etc/fstab(開機自動掛載)...${NC}"
  echo "$SWAPFILE none swap sw 0 0" | sudo tee -a /etc/fstab >/dev/null
else
  echo -e "${BLUE}✅ /etc/fstab 已有 $SWAPFILE,跳過。${NC}"
fi

# 降低 swappiness:讓系統優先用 RAM,swap 當保險
echo -e "${GREEN}⚙️ 設定 vm.swappiness=$SWAPPINESS ...${NC}"
echo "vm.swappiness=$SWAPPINESS" | sudo tee /etc/sysctl.d/99-swappiness.conf >/dev/null
sudo sysctl -w "vm.swappiness=$SWAPPINESS" >/dev/null

echo -e "${GREEN}🎉 swap 設定完成。${NC}"
swapon --show
free -h
