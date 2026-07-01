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
