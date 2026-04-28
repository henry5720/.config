#!/bin/bash
echo "--- 開始配置 Zsh + p10k + 外掛 ---"

# 1. 建立必要的目錄
mkdir -p ~/.config/zsh

# 2. 下載 Powerlevel10k (如果不存在)
if [ ! -d ~/.config/zsh/powerlevel10k ]; then
  git clone --depth=1 https://github.com/romkatv/powerlevel10k.git ~/.config/zsh/powerlevel10k
fi

# 3. 下載外掛 (如果不存在)
if [ ! -d ~/.config/zsh/zsh-autosuggestions ]; then
  git clone --depth=1 https://github.com/zsh-users/zsh-autosuggestions ~/.config/zsh/zsh-autosuggestions
fi

if [ ! -d ~/.config/zsh/zsh-syntax-highlighting ]; then
  git clone --depth=1 https://github.com/zsh-users/zsh-syntax-highlighting.git ~/.config/zsh/zsh-syntax-highlighting
fi