#!/bin/bash

# 設定顏色輸出
GREEN='\033[0;32m'
BLUE='\033[0;34m'
NC='\033[0m' # 無顏色

echo -e "${BLUE}🚀 開始全自動開發環境配置 (WSL Ubuntu)...${NC}"

# 1. 更新系統與安裝基礎工具
echo -e "${GREEN}📦 正在更新系統並安裝基礎套件 (git, curl, zsh, fastfetch)...${NC}"
sudo apt update && sudo apt upgrade -y
sudo apt install -y zsh git curl fastfetch build-essential

# 2. 安裝 Oh My Zsh
if [ ! -d "$HOME/.oh-my-zsh" ]; then
    echo -e "${GREEN}📦 安裝 Oh My Zsh...${NC}"
    sh -c "$(curl -fsSL https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh)" "" --unattended
else
    echo -e "${BLUE}✅ Oh My Zsh 已存在，跳過。${NC}"
fi

# 3. 安裝 Powerlevel10k 主題
P10K_PATH=${ZSH_CUSTOM:-$HOME/.oh-my-zsh/custom}/themes/powerlevel10k
if [ ! -d "$P10K_PATH" ]; then
    echo -e "${GREEN}🎨 下載 Powerlevel10k 主題...${NC}"
    git clone --depth=1 https://github.com/romkatv/powerlevel10k.git "$P10K_PATH"
fi

# 4. 安裝 Zsh 必備外掛 (語法高亮、自動補全)
echo -e "${GREEN}🔌 安裝 Zsh 外掛 (Syntax Highlighting & Autosuggestions)...${NC}"
ZSH_PLUGINS_DIR=${ZSH_CUSTOM:-$HOME/.oh-my-zsh/custom}/plugins
[ ! -d "$ZSH_PLUGINS_DIR/zsh-syntax-highlighting" ] && git clone https://github.com/zsh-users/zsh-syntax-highlighting.git "$ZSH_PLUGINS_DIR/zsh-syntax-highlighting"
[ ! -d "$ZSH_PLUGINS_DIR/zsh-autosuggestions" ] && git clone https://github.com/zsh-users/zsh-autosuggestions "$ZSH_PLUGINS_DIR/zsh-autosuggestions"

# 5. 配置 .zshrc
echo -e "${GREEN}📝 正在優化 .zshrc 配置...${NC}"
# 切換主題為 p10k
sed -i 's/ZSH_THEME="robbyrussell"/ZSH_THEME="powerlevel10k\/powerlevel10k"/g' ~/.zshrc
# 啟用外掛
sed -i 's/plugins=(git)/plugins=(git zsh-syntax-highlighting zsh-autosuggestions)/g' ~/.zshrc
# 在檔案末尾加入 Fastfetch
if ! grep -q "fastfetch" ~/.zshrc; then
    echo -e "\n# 啟動時顯示系統資訊\nfastfetch" >> ~/.zshrc
fi

# 6. 安裝 NVM (Node Version Manager) 與 Node.js LTS
if [ ! -d "$HOME/.nvm" ]; then
    echo -e "${GREEN}🟢 安裝 NVM 與最新 Node.js LTS...${NC}"
    curl -o- https://raw.githubusercontent.com/nvm-sh/nvm/v0.40.1/install.sh | bash
    
    # 載入 NVM 讓腳本後續可以執行 node 安裝
    export NVM_DIR="$HOME/.nvm"
    [ -s "$NVM_DIR/nvm.sh" ] && \. "$NVM_DIR/nvm.sh"
    
    nvm install --lts
    nvm use --lts
else
    echo -e "${BLUE}✅ NVM 已存在，跳過。${NC}"
fi

# 7. 設定預設 Shell 為 Zsh
echo -e "${GREEN}🔄 切換預設 Shell 為 Zsh...${NC}"
sudo chsh -s $(which zsh) $USER

echo -e "${BLUE}==================================================${NC}"
echo -e "${GREEN}🎉 所有配置已完成！${NC}"
echo -e "${BLUE}👉 下一步：${NC}"
echo -e "1. 重新啟動 WSL 或輸入 'zsh'。"
echo -e "2. 將會自動啟動 Powerlevel10k 配置精靈，請依照畫面指示選擇喜歡的風格。"
echo -e "${BLUE}==================================================${NC}"

# 直接進入 zsh
exec zsh