# ===============================================================
# 1. Powerlevel10k 快速啟動 (Instant Prompt)
# ===============================================================
if [[ -r "${XDG_CACHE_HOME:-$HOME/.cache}/p10k-instant-prompt-${(%):-%n}.zsh" ]]; then
  source "${XDG_CACHE_HOME:-$HOME/.cache}/p10k-instant-prompt-${(%):-%n}.zsh"
fi

# ===============================================================
# 2. 環境變數與路徑 (Path Settings)
# ===============================================================
# 如果你有使用 pnpm (Senior Engineer 標配)
export PNPM_HOME="$HOME/.local/share/pnpm"
export PATH="$PNPM_HOME:$PATH"

# 載入 NVM (確保 claude / opencode 能被找到)
export NVM_DIR="$HOME/.nvm"
[ -s "$NVM_DIR/nvm.sh" ] && \. "$NVM_DIR/nvm.sh"
[ -s "$NVM_DIR/bash_completion" ] && \. "$NVM_DIR/bash_completion"

# ===============================================================
# 3. 歷史紀錄設定 (History)
# ===============================================================
HISTFILE=~/.zsh_history
HISTSIZE=10000
SAVEHIST=10000

setopt SHARE_HISTORY          # 跨視窗共享紀錄
setopt APPEND_HISTORY         # 追加方式寫入
setopt INC_APPEND_HISTORY     # 立即寫入檔案
setopt HIST_IGNORE_DUPS       # 忽略重複
setopt HIST_IGNORE_SPACE      # 空格開頭不紀錄

# ===============================================================
# 4. 載入主題與個人化設定 (已搬移至 .config)
# ===============================================================
source ~/.config/zsh/powerlevel10k/powerlevel10k.zsh-theme
[[ ! -f ~/.p10k.zsh ]] || source ~/.p10k.zsh

# ===============================================================
# 5. 補全系統與外掛 (Completion & Plugins)
# ===============================================================
autoload -Uz compinit && compinit
zstyle ':completion:*' menu select
zstyle ':completion:*' matcher-list 'm:{a-zA-Z}={A-Za-z}' # 補全忽略大小寫

# 自動建議
source ~/.config/zsh/zsh-autosuggestions/zsh-autosuggestions.zsh

# 語法高亮 (必須放最後)
source ~/.config/zsh/zsh-syntax-highlighting/zsh-syntax-highlighting.zsh

# ===============================================================
# 6. 自定義別名 (Aliases)
# ===============================================================
alias vi='nvim'
alias vim='nvim'
alias n='nvim'
alias g='git'
alias lg='lazygit'
alias ls='ls --color=auto'
alias ll='ls -alF'
alias la='ls -A'

# AI Agents 快捷鍵 (如果需要的話)
alias c='claude'
alias oc='opencode'