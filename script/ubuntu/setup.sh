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
