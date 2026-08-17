# dotfiles 改用 chezmoi 管理 實作計畫

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 把家目錄設定檔的部署從四種各自為政的機制收斂成單一的 `chezmoi apply`,並讓新機器可以一行 bootstrap。

**Architecture:** repo 根放 `.chezmoiroot`(內容 `home`),家目錄檔搬進 `home/` 並套用 chezmoi 的檔名前綴規則(`dot_` / `private_` / `executable_` / `symlink_` / `.tmpl`);`script/` `docs/` `wsl/` `ai-agent/` 留在 repo 根,chezmoi 看不到。先就地驗證 `chezmoi diff`,通過後才 `apply`,最後才把 repo 搬到 `~/.local/share/chezmoi`。

**Tech Stack:** chezmoi、Go template、git、bash

**Spec:** `docs/superpowers/specs/2026-08-17-chezmoi-migration-design.md`

## Global Constraints

- **repo 是公開的。任何秘密不得進 git。** 目前唯一的秘密是 code-server 密碼,走 `chezmoi init` 互動詢問。
- **第 6 個 Task(apply)之前不做任何不可逆的事。** Task 1-5 只動 repo,不碰家目錄,隨時可 `git checkout` 回頭。
- **文件語體**:繁體中文,標點用半形逗號 `,` 與冒號 `:`(與 repo 既有文件一致)。
- **`docs/superpowers/` 底下既有的 spec / plan 不動**——那是歷史存檔,寫的是當時的事實。本計畫自己這份除外。
- **`.config/tmux/scripts/swap_window_in_session.sh` 與 `.config/tmux/tmux-status/ccusage-today.sh` 照原樣搬,不加 `executable_` 前綴。** 它們在 repo 內確實沒有執行權限,這是已知問題但不在本次範圍。
- **分支**:`feat/chezmoi`(已建立,spec 已 commit 於 `9639eee`)。
- **本機 repo 路徑**:`/home/henry/code/dotfiles`(Task 7 之後改為 `~/.local/share/chezmoi`)。

---

### Task 1: 建立 chezmoi 骨架並搬移家目錄檔

**Files:**
- Create: `.chezmoiroot`
- Rename: `.zshrc` → `home/dot_zshrc`
- Rename: `.tmux.conf` → `home/dot_tmux.conf`
- Rename: `.ssh/config` → `home/private_dot_ssh/config`
- Rename: `ai-agent/AGENTS.md` → `home/dot_claude/CLAUDE.md`
- Rename: `.config/` → `home/dot_config/`(含 32 個檔加 `executable_` 前綴)

**Interfaces:**
- Produces: `home/` 為 chezmoi 的來源根。後續 Task 的所有路徑都以此為基準。
- Produces: 規則本體位於 `home/dot_claude/CLAUDE.md`。Task 2 的 opencode symlink 指向它部署後的位置 `~/.claude/CLAUDE.md`。

- [ ] **Step 1: 確認起點乾淨**

```bash
cd /home/henry/code/dotfiles
git status --short          # 預期:無輸出
git branch --show-current   # 預期:feat/chezmoi
```

如果 `git status` 有輸出,先停下來問人。

- [ ] **Step 2: 建立 `.chezmoiroot` 並搬移頂層檔案**

```bash
cd /home/henry/code/dotfiles
echo home > .chezmoiroot

mkdir -p home
git mv .zshrc     home/dot_zshrc
git mv .tmux.conf home/dot_tmux.conf

mkdir -p home/private_dot_ssh
git mv .ssh/config home/private_dot_ssh/config

mkdir -p home/dot_claude
git mv ai-agent/AGENTS.md home/dot_claude/CLAUDE.md

git mv .config home/dot_config
```

`.ssh/` 與 `ai-agent/` 目錄本身留著:`.ssh/` 會變空(git 不追蹤空目錄,自然消失),`ai-agent/` 還有兩份 think-mode persona。

- [ ] **Step 3: 32 個可執行檔加 `executable_` 前綴**

```bash
cd /home/henry/code/dotfiles/home/dot_config
n=0
while IFS= read -r f; do
  d=$(dirname "$f"); b=$(basename "$f")
  git mv "$f" "$d/executable_$b" && n=$((n+1))
done < <(find . -type f -perm -u+x | sort)
echo "改了 $n 個"
```

預期輸出:`改了 32 個`

- [ ] **Step 4: 驗收——確認是 rename 而非 delete+add**

```bash
cd /home/henry/code/dotfiles
git add -A
git status --short | grep -c '^R'     # 預期:43
git status --short | grep -v '^R'     # 預期:只有 A  .chezmoiroot 一行
```

43 = `.zshrc` + `.tmux.conf` + `.ssh/config` + `ai-agent/AGENTS.md` + `.config/` 底下 39 個
(含 `opencode/AGENTS.md` 這個 symlink,git 以 mode 120000 追蹤)。

git 認得出 rename 表示內容沒被改動,歷史也追得回去。若出現 `D` + `A` 配對,代表某個檔內容變了,停下來查。

- [ ] **Step 5: 驗收——檔名清單逐項核對**

```bash
git ls-files home | wc -l     # 預期:43
git ls-files home | sort
```

用 `git ls-files` 而不是 `find -type f`,因為後者看不到 `opencode/AGENTS.md` 那個 symlink。

重點檢查三件事:

1. `home/dot_config/tmux/scripts/` 底下除了 `swap_window_in_session.sh`,其餘都有 `executable_` 前綴
2. `home/dot_config/tmux/tmux-status/` 底下除了 `ccusage-today.sh`,其餘都有 `executable_` 前綴
3. `home/dot_config/code-server/config.yaml.example` 還在(Task 2 才改它)

- [ ] **Step 6: Commit**

```bash
cd /home/henry/code/dotfiles
git add -A
git commit -m "refactor(chezmoi): 家目錄檔搬進 home/,套用 chezmoi 檔名前綴

.chezmoiroot 指定 home/ 為來源根,repo 根的 script/ docs/ wsl/
ai-agent/ 維持原狀、chezmoi 看不到。

32 個可執行檔加 executable_ 前綴。swap_window_in_session.sh 與
ccusage-today.sh 在 repo 內本來就沒有執行權限,照原樣搬,維持現狀。

規則本體從 ai-agent/AGENTS.md 搬到 home/dot_claude/CLAUDE.md,
因為本體必須在 home 樹內才會被 chezmoi 部署。"
```

---

### Task 2: Template 與秘密

**Files:**
- Create: `home/.chezmoi.toml.tmpl`
- Rename + Modify: `home/dot_config/code-server/config.yaml.example` → `home/dot_config/private_code-server/private_config.yaml.tmpl`
- Delete: `home/dot_config/opencode/AGENTS.md`(原 relative symlink)
- Create: `home/dot_config/opencode/symlink_AGENTS.md.tmpl`
- Modify: `.gitignore`

**Interfaces:**
- Consumes: Task 1 建立的 `home/` 結構。
- Produces: template 變數 `.codeServerPassword`,由 `home/.chezmoi.toml.tmpl` 在 `chezmoi init` 時互動取得,存於 `~/.config/chezmoi/chezmoi.toml`(repo 外)。

- [ ] **Step 1: 建立設定檔 template**

Create `home/.chezmoi.toml.tmpl`:

```go-template
{{- $codeServerPassword := promptStringOnce . "codeServerPassword" "code-server 密碼" -}}

[data]
    codeServerPassword = {{ $codeServerPassword | quote }}
```

`promptStringOnce` 只在 `chezmoi init` 時問,且已有值就不再問。它只能用在設定檔 template,不能用在一般 dotfile template。

- [ ] **Step 2: code-server 範本改成 chezmoi template**

```bash
cd /home/henry/code/dotfiles/home/dot_config
mkdir -p private_code-server
git mv code-server/config.yaml.example private_code-server/private_config.yaml.tmpl
rmdir code-server
```

- [ ] **Step 3: 改寫 template 內容**

覆寫 `home/dot_config/private_code-server/private_config.yaml.tmpl`:

```yaml
# 這份由 chezmoi 從 home/dot_config/private_code-server/private_config.yaml.tmpl
# 產生。要改設定改那份 template,再 chezmoi apply。
# 密碼不在 template 裡 —— 它從 ~/.config/chezmoi/chezmoi.toml 帶入,那個檔不在 git。
# 內容是「安全預設」:只綁 127.0.0.1、TLS 交給外面處理。
# 適用 phone(方案 A:ssh -L)和 henry-desktop(方案 B:tailscale serve)。
# 遠端連線的五種做法與各自代價,見 docs/code-server-remote.md。

# ===============================================================
# 1. 監聽位址
# ===============================================================
# 綁 127.0.0.1 = 只有本機連得到,外面一律經 ssh tunnel 或 tailscale serve。
# 不要改成 0.0.0.0,那等於把終端機開放給整個網段。
bind-addr: 127.0.0.1:8080

# ===============================================================
# 2. 認證
# ===============================================================
# 密碼來自 chezmoi 的 codeServerPassword 變數,不是寫死在這。
# 要改密碼:chezmoi edit-config 改那一行,再 chezmoi apply。
# 明碼就夠了:外面還有 tailscale 那層,只有 tailnet 裡的裝置連得到,
# 而且 code-server 自己的預設也是明碼。但別用你其他地方在用的密碼。
auth: password
password: {{ .codeServerPassword | quote }}

# 想更保險再改 hash(優先於 password,兩行只留一行):
#   echo -n '你的密碼' | npx argon2-cli -e
# hashed-password: $argon2i$v=19$m=4096,t=3,p=1$...

# 兩行都空著的話 code-server 啟動會直接報錯,不會偷偷放行。

# ===============================================================
# 3. TLS
# ===============================================================
# 預設 false:code-server 講 http,由外層負責 https。
#   方案 A(ssh -L)  → 走 localhost,本來就是 secure context,不需要憑證
#   方案 B(serve)   → tailscale 在前面終結 TLS
cert: false

# 方案 C|tailscale cert:自己拿真憑證,取消下面兩行的註解並改路徑
#   Windows 側先跑:tailscale cert henry-desktop.<你的 tailnet>.ts.net
# cert: /mnt/c/Users/henry/certs/henry-desktop.<tailnet>.ts.net.crt
# cert-key: /mnt/c/Users/henry/certs/henry-desktop.<tailnet>.ts.net.key

# 方案 D|自簽憑證:改成 cert: true,產在 ~/.local/share/code-server/self-signed.crt
#   注意 Chrome 會擋掉 service worker 註冊,部分擴充套件會壞。

# ===============================================================
# 4. 其他
# ===============================================================
# 關掉每次啟動的更新檢查(版本由套件管理器管)
disable-update-check: true
```

- [ ] **Step 4: opencode 的 AGENTS.md 改成 chezmoi 管的 symlink**

```bash
cd /home/henry/code/dotfiles/home/dot_config/opencode
git rm AGENTS.md
printf '{{ .chezmoi.homeDir }}/.claude/CLAUDE.md\n' > symlink_AGENTS.md.tmpl
```

**為什麼必須是 `.tmpl`**:symlink 的來源檔內容就是連結目標,而 chezmoi 不會展開 `~`。寫字面上的 `~/.claude/CLAUDE.md` 會建出一條死連結。用 `{{ .chezmoi.homeDir }}` 才會展開成絕對路徑。

- [ ] **Step 5: 精簡 `.gitignore`**

`.config/code-server/config.yaml` 這條規則已無意義(該路徑不再存在,生效的那份也不再由 repo 產生)。修改 `.gitignore` 第 1 節:

```
# ===============================================================
# 1. 本機專屬設定
# ===============================================================
# 生效的設定檔由 chezmoi apply 產生在家目錄,本來就不在 repo 內。
# 秘密走 chezmoi 的 promptStringOnce,存在 ~/.config/chezmoi/(repo 外)。
*.local
```

其餘兩節(秘密、雜物)不動。

- [ ] **Step 6: 驗收——結構正確**

```bash
cd /home/henry/code/dotfiles
test -f home/.chezmoi.toml.tmpl && echo TOML_OK
test -f home/dot_config/private_code-server/private_config.yaml.tmpl && echo CS_OK
test -f home/dot_config/opencode/symlink_AGENTS.md.tmpl && echo LINK_OK
test ! -e home/dot_config/opencode/AGENTS.md && echo OLD_GONE
grep -q 'chezmoi.homeDir' home/dot_config/opencode/symlink_AGENTS.md.tmpl && echo TMPL_OK
```

五行全部要印出來。

template 的**語法**驗收在 Task 4 Step 3——這台目前還沒裝 chezmoi,現在跑不了
`chezmoi execute-template`。`chezmoi init` 若成功跳出「code-server 密碼」的提問,
就代表 `home/.chezmoi.toml.tmpl` 語法正確且 `promptStringOnce` 生效。

- [ ] **Step 7: Commit**

```bash
cd /home/henry/code/dotfiles
git add -A
git commit -m "feat(chezmoi): 加 template 與秘密處理

code-server 設定改成 chezmoi template,密碼由 chezmoi init 互動問一次、
存在 ~/.config/chezmoi/chezmoi.toml(repo 外),取代原本的
cp 範本 + 手動填 + .gitignore 擋 三步。

opencode 的 AGENTS.md 從 repo 內 relative symlink 改成 chezmoi 建的
symlink,指向部署後的 ~/.claude/CLAUDE.md。必須用 .tmpl 搭配
.chezmoi.homeDir,因為 symlink 目標不會展開 ~。"
```

---

### Task 3: 更新 install-base.sh

**Files:**
- Modify: `script/ubuntu/install-base.sh`

**Interfaces:**
- Consumes: 無(這支腳本不再依賴 repo 內的 `.zshrc` 路徑)。
- Produces: `install-base.sh` 只剩三節(apt、zsh 插件、chsh),不再部署任何設定檔。

這個 Task 排在 apply 之前,因為它只改 repo、不碰家目錄,而且改完可以立刻用「重跑一次是否冪等」驗收。

- [ ] **Step 1: 刪掉第 3 節(部署 .zshrc symlink)**

刪除 `script/ubuntu/install-base.sh` 中從 `# 3. 部署 .zshrc` 到該區塊結尾 `fi` 的整段(原第 31-45 行):

```bash
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
```

- [ ] **Step 2: 把第 4 節改成第 3 節**

```bash
# 4. 設預設 shell 為 zsh
```

改為:

```bash
# 3. 設預設 shell 為 zsh
```

- [ ] **Step 3: 移除變成孤兒的 REPO_DIR**

刪除原第 6-7 行(`REPO_DIR` 只被剛刪掉的那段使用):

```bash
# repo 根目錄(本腳本在 script/ubuntu/ 底下)
REPO_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
```

- [ ] **Step 4: 更新開場訊息**

```bash
echo -e "${BLUE}🚀 安裝基底環境 (zsh + 插件 + .zshrc)...${NC}"
```

改為:

```bash
echo -e "${BLUE}🚀 安裝基底環境 (zsh + 插件)...${NC}"
```

- [ ] **Step 5: 驗收——語法與孤兒變數**

```bash
cd /home/henry/code/dotfiles
bash -n script/ubuntu/install-base.sh && echo SYNTAX_OK
grep -c REPO_DIR script/ubuntu/install-base.sh    # 預期:0
grep -c 'zshrc'  script/ubuntu/install-base.sh    # 預期:0
grep -n '^# [0-9]\.' script/ubuntu/install-base.sh  # 預期:1. 2. 3. 連號無跳號
```

`install-tools.sh` 的 code-server 設定檔部署邏輯(cp 範本那段)一併移除,改由 chezmoi
負責;`REPO_DIR` 是否保留依剩餘引用而定——若移除後變成孤兒就一併刪掉。

- [ ] **Step 6: 驗收——冪等邏輯仍完整**

不要為了驗收就整支重跑——它第一節是 `apt update && apt upgrade -y`,會對整台機器做
本次範圍外的套件升級。改為靜態檢查三段冪等判斷都還在:

```bash
cd /home/henry/code/dotfiles
grep -c 'clone_if_missing' script/ubuntu/install-base.sh   # 預期:4(1 個定義 + 3 次呼叫)
grep -q 'getent passwd' script/ubuntu/install-base.sh && echo CHSH_GUARD_OK
grep -q 'apt install -y zsh git curl vim' script/ubuntu/install-base.sh && echo APT_OK
```

三項都通過即可。真正的端到端驗證留給下次裝新機器。

- [ ] **Step 7: Commit**

```bash
cd /home/henry/code/dotfiles
git add script/ubuntu/install-base.sh
git commit -m "refactor(install-base): 拿掉 .zshrc symlink 部署,交給 chezmoi

設定檔部署統一由 chezmoi apply 負責,這支只留 apt 套件、zsh 插件
clone、chsh 三件事。REPO_DIR 因此變成孤兒,一併移除。"
```

---

### Task 4: 安裝 chezmoi 並就地初始化

**Files:**
- Create: `~/.config/chezmoi/chezmoi.toml`(由 `chezmoi init` 產生,**不在 repo**)

**Interfaces:**
- Consumes: Task 1-2 建立的 `home/` 來源樹與 `home/.chezmoi.toml.tmpl`。
- Produces: 可用的 chezmoi 環境,`sourceDir` 指向 `/home/henry/code/dotfiles`。Task 5 用它跑 diff。

- [ ] **Step 1: 確認 chezmoi 尚未安裝**

```bash
command -v chezmoi || echo "未安裝,繼續"
```

- [ ] **Step 2: 安裝 chezmoi**

```bash
sh -c "$(curl -fsLS get.chezmoi.io)" -- -b "$HOME/.local/bin"
export PATH="$HOME/.local/bin:$PATH"
chezmoi --version
```

`~/.local/bin` 已在 `.zshrc` 的 PATH 內(`claude` 就裝在那)。

- [ ] **Step 3: 就地初始化,不 apply**

```bash
chezmoi init --source=/home/henry/code/dotfiles
```

會互動詢問 `code-server 密碼`。**這裡填真正要用的密碼**,它會存進 `~/.config/chezmoi/chezmoi.toml`。

注意:**沒有 `--apply`**。這一步只建立設定,不碰家目錄。

- [ ] **Step 4: 驗收——來源路徑與設定**

```bash
chezmoi source-path                        # 預期:/home/henry/code/dotfiles/home
grep -c codeServerPassword ~/.config/chezmoi/chezmoi.toml   # 預期:1
cd /home/henry/code/dotfiles && git status --short          # 預期:無輸出
```

`source-path` 尾巴是 `/home` 就代表 `.chezmoiroot` 生效了。第三行確認 `chezmoi init` 沒有偷改 repo。

- [ ] **Step 5: 驗收——秘密沒進 repo**

```bash
cd /home/henry/code/dotfiles
git status --short --ignored | grep -i chezmoi.toml   # 預期:無輸出
```

設定檔在 `~/.config/chezmoi/`,本來就不該出現在 repo 內。

這個 Task 沒有 commit——它不產生 repo 內的變更。

---

### Task 5: diff 閘門(關鍵驗收點)

**Files:** 無變更。這個 Task 只做驗收。

**Interfaces:**
- Consumes: Task 4 建立的 chezmoi 環境。
- Produces: 一份經人工核對的部署清單。Task 6 才真的寫入家目錄。

**這是整個遷移的關鍵閘門。** 因為這台機器有一半的檔案從未部署,`chezmoi diff` **不會**是空的。驗收標準是「輸出清單等於預期清單,無多無少」。

- [ ] **Step 1: 產生受影響檔案清單**

```bash
chezmoi status | awk '{print $2}' | sort -u
```

`chezmoi status` 每行開頭是兩個字元的狀態碼,不是一個:第一欄是「來源狀態相對於 chezmoi 上次寫入的變化」,第二欄是「目的端(家目錄)相對於目標狀態的變化」。這裡要看的是**第二欄**:`M` 代表該檔案已存在,apply 後會被修改(覆蓋);`A` 代表新增,這台原本沒有這個檔案。第一欄目前這台都是空白,所以兩欄印出來像「一個空格 + 一個字母」,例如 ` M .claude/CLAUDE.md`。

`awk '{print $2}'` 這裡能正確取到檔名,是因為 awk 預設以空白切欄位、且會吃掉開頭的空白——所以 `$1` 拿到的其實是第二欄那個字母,`$2` 才是路徑。這個行為**只在第一欄是空白時成立**;若第一欄也非空白(兩欄黏在一起,像 `AM`),`awk '{print $1}'` 會拿到 `AM` 整串而不是單一字母。Step 3 因此改用固定位置的 `substr`,不依賴這個巧合。

- [ ] **Step 2: 逐項核對**

預期清單分三類,**每一項都要對得上**:

**A. 全新部署(這台原本沒有)**——約 36 項

- `.tmux.conf`
- `.config/tmux/` 底下全部(fzf_panes.tmux、scripts/、tmux-status/)
- `.config/nvim/lua/config/options.lua`
- `.config/fontconfig/fonts.conf`
- `.config/code-server/config.yaml`

**B. 覆蓋既有(spec 已決定以 repo 為準)**——正好 4 項

- `.zshrc`
- `.claude/CLAUDE.md`
- `.config/opencode/opencode.json`
- `.config/opencode/AGENTS.md`(改為 symlink,機器上原本是獨立檔案)

**C. 無變更**——`.ssh/config` 應**不出現**在清單裡(它跟 repo 已經一致)。

- [ ] **Step 3: 確認 B 類正好四項**

```bash
for f in .zshrc .claude/CLAUDE.md .config/opencode/opencode.json .config/opencode/AGENTS.md; do
  test -e "$HOME/$f" && echo "既有: $f"
done
chezmoi status | awk '{ if (substr($0,2,1) == "M") print substr($0,4) }' | sort -u
```

`substr($0,2,1)` 直接取每行第二個字元(即第二欄的狀態碼),不靠 `grep '^M'` 錨定行首——那樣行不通,因為每行實際上以第一欄(這台目前都是空白)開頭,`M`/`A` 是第二個字元,`grep '^M'` 永遠對不上,會安靜印出空結果。第二欄是 `M` 的那些行就是「既有檔案將被覆蓋」的清單(見 Step 1 的兩欄說明)。這份清單必須**正好**是那四個。多出任何一項就停下來問人——那代表有這台機器上還在用、而 spec 沒討論過的檔案要被蓋掉。

- [ ] **Step 4: 確認 ssh config 不受影響**

```bash
chezmoi status | grep -c 'ssh/config'    # 預期:0
```

若不是 0,表示 `private_dot_ssh` 讓 chezmoi 認為權限要改。檢查 `stat -c '%a' ~/.ssh ~/.ssh/config`——若本來就是 700/600 則不該有 diff;若不是,那這個 diff 是**正確的**(chezmoi 要來修權限),放行。

- [ ] **Step 5: 確認秘密有正確帶入**

```bash
chezmoi cat ~/.config/code-server/config.yaml | grep '^password:'
```

預期看到 `password: ` 後面接你在 Task 4 填的密碼。若是 `password: <no value>`,表示 template 變數名不匹配,回 Task 2 檢查。

`chezmoi cat` 只印出「將要產生的內容」,不寫檔。

**閘門:以上五步全部通過才進 Task 6。** 任何一項對不上就停下來問人,不要自行判斷放行。

---

### Task 6: 備份並 apply

**Files:**
- Create: `~/.dotfiles-pre-chezmoi-backup/`(家目錄備份,不在 repo)
- Modify: 家目錄各設定檔(由 `chezmoi apply` 寫入)

**Interfaces:**
- Consumes: Task 5 核可的部署清單。
- Produces: 家目錄進入 chezmoi 管理狀態。

**這是第一個不可逆的 Task。** 先備份再 apply。

- [ ] **Step 1: 備份四個會被覆蓋的檔**

```bash
B="$HOME/.dotfiles-pre-chezmoi-backup"
mkdir -p "$B/.claude" "$B/.config/opencode"
cp -a "$HOME/.zshrc"                          "$B/.zshrc"
cp -a "$HOME/.claude/CLAUDE.md"               "$B/.claude/CLAUDE.md"
cp -a "$HOME/.config/opencode/opencode.json"  "$B/.config/opencode/opencode.json"
cp -a "$HOME/.config/opencode/AGENTS.md"      "$B/.config/opencode/AGENTS.md"
find "$B" -type f | sort
```

預期看到四個檔。

- [ ] **Step 2: 驗收——備份可讀且非空**

```bash
B="$HOME/.dotfiles-pre-chezmoi-backup"
for f in .zshrc .claude/CLAUDE.md .config/opencode/opencode.json .config/opencode/AGENTS.md; do
  test -s "$B/$f" && echo "OK $f" || echo "FAIL $f"
done
```

四行都要 `OK`。有任何 `FAIL` 就停下來。

- [ ] **Step 3: apply**

```bash
chezmoi apply
```

- [ ] **Step 4: 驗收——shell 與 tmux**

```bash
env -i HOME="$HOME" TERM=dumb /bin/zsh -lic 'echo $PATH' | tr ':' '\n' | grep -E '\.local/bin|\.opencode/bin'
tmux new -d -s _verify && tmux kill-session -t _verify && echo TMUX_OK
```

`.zshrc` 結尾的 `command -v fastfetch && fastfetch` 會讓「互動式 zsh 執行後立刻 exit」的
結束碼呈現非零,不能拿來當驗收條件;改用乾淨環境跑一次 `.zshrc` 後檢查 PATH 是否含
`~/.local/bin`、`~/.opencode/bin` 兩個目錄,兩行都要印出來才算過。

- [ ] **Step 5: 驗收——權限與 symlink**

```bash
stat -c '%a %n' ~/.ssh ~/.ssh/config          # 預期:700 / 600
stat -c '%a %n' ~/.config/code-server/config.yaml   # 預期:600
readlink ~/.config/opencode/AGENTS.md          # 預期:/home/henry/.claude/CLAUDE.md
ls -l ~/.config/tmux/scripts/new_session.sh    # 預期:權限含 x
```

- [ ] **Step 6: 驗收——內容確實換成 repo 版**

```bash
diff ~/.zshrc "$(chezmoi source-path)/dot_zshrc" && echo ZSHRC_OK
diff ~/.claude/CLAUDE.md "$(chezmoi source-path)/dot_claude/CLAUDE.md" && echo RULES_OK
diff ~/.config/opencode/opencode.json "$(chezmoi source-path)/dot_config/opencode/opencode.json" && echo OPENCODE_OK
grep -c 'ANTHROPIC_AUTH_TOKEN\|TEAMSYNC_API_KEY' ~/.zshrc    # 預期:0
grep -c 'apiKey' ~/.config/opencode/opencode.json            # 預期:0
```

最後兩行確認金鑰確實從機器上清掉了。

- [ ] **Step 7: 驗收——chezmoi 自身狀態**

```bash
chezmoi verify && echo VERIFY_OK
chezmoi status                    # 預期:無輸出
```

- [ ] **Step 8: 驗收——opencode 的 agents/ commands/ 沒被動到**

```bash
ls ~/.config/opencode/            # 預期:agents commands node_modules opencode.json AGENTS.md ...
```

chezmoi 只管它認識的檔。`agents/`、`commands/`、`node_modules/` 應原封不動。

這個 Task 沒有 commit——它只改家目錄,不改 repo。

---

### Task 7: repo 搬到 chezmoi 預設位置

**Files:**
- Move: `/home/henry/code/dotfiles` → `/home/henry/.local/share/chezmoi`
- Modify: `~/.config/chezmoi/chezmoi.toml`(移除 `sourceDir`)

**Interfaces:**
- Consumes: Task 6 完成的 apply 狀態。
- Produces: repo 位於 chezmoi 預設位置,`chezmoi init --apply henry5720` 一行 bootstrap 可用。

先驗證再搬家:apply 已經驗收過了,搬家出錯不會牽連前面的成果。

- [ ] **Step 1: 確認工作區乾淨且已推上遠端**

```bash
cd /home/henry/code/dotfiles
git status --short              # 預期:無輸出
git push -u origin feat/chezmoi
```

**搬家前一定要 push。** 萬一搬移出錯,遠端還有一份。

- [ ] **Step 2: 搬移**

```bash
mkdir -p ~/.local/share
mv /home/henry/code/dotfiles ~/.local/share/chezmoi
```

- [ ] **Step 3: 移除 sourceDir 設定,改用預設值**

編輯 `~/.config/chezmoi/chezmoi.toml`,刪掉 `sourceDir = "/home/henry/code/dotfiles"` 那一行(若 `chezmoi init --source` 有寫入的話)。保留 `[data]` 區塊。

```bash
grep -n sourceDir ~/.config/chezmoi/chezmoi.toml || echo "沒有 sourceDir,不用改"
```

- [ ] **Step 4: 驗收——chezmoi 找得到新位置**

```bash
chezmoi source-path                # 預期:/home/henry/.local/share/chezmoi/home
chezmoi doctor                     # 預期:無 ERROR(warning 可接受)
chezmoi status                     # 預期:無輸出
chezmoi verify && echo VERIFY_OK
```

`chezmoi doctor` 的 warning 常見於未安裝的可選工具(如 gpg、age),不影響。**ERROR 就要處理。**

- [ ] **Step 5: 驗收——舊路徑已淨空**

```bash
test ! -e /home/henry/code/dotfiles && echo OLD_PATH_GONE
cd ~/.local/share/chezmoi && git status --short && git log --oneline -1
```

git 歷史應完整保留。

這個 Task 沒有 commit——搬移不改內容。

---

### Task 8: 重寫 README 與 ai-agent-setup.md

**Files:**
- Modify: `README.md`(第 15-30 行的目錄結構表、第 31-131 行的部署章節、第 219 行起的注意事項)
- Modify: `docs/ai-agent-setup.md`(第 41 行、第 222 行)

**Interfaces:**
- Consumes: Task 1-7 的最終結構與指令。
- Produces: 文件與實作一致。

- [ ] **Step 1: 替換 README 的目錄結構表**

`README.md` 第 15-30 行的表格,把路徑欄改成 chezmoi 的來源路徑。替換整個表格為:

```markdown
## 目錄結構

`.chezmoiroot` 把 repo 切成兩塊:`home/` 是 chezmoi 的地盤(檔名有前綴規則),其餘 chezmoi 完全看不到。

| 路徑 | 部署到 | 用途 | 詳細 |
|---|---|---|---|
| `home/dot_zshrc` | `~/.zshrc` | 純 zsh 設定:Powerlevel10k、autosuggestions、syntax-highlighting、nvm、開場 `fastfetch`。 | [↓](#zsh) |
| `home/dot_tmux.conf` + `home/dot_config/tmux/` | `~/.tmux.conf` + `~/.config/tmux/` | 高度客製的 tmux:TPM 外掛、狀態列、編號 session 管理,以及大量 AI-agent 自動化腳本。 | [↓](#tmux) |
| `home/private_dot_ssh/config` | `~/.ssh/config`(600) | SSH 連線設定:GitHub、Tailscale 節點、Oracle VPS。**不含私鑰**。 | [↓](#ssh) |
| `home/dot_claude/CLAUDE.md` | `~/.claude/CLAUDE.md` | **agent 規則的單一來源**,opencode 那邊 symlink 過來。 | [↓](#ai-agent-規則) |
| `home/dot_config/nvim/` | `~/.config/nvim/` | 只有 `lua/config/options.lua` 一個片段(剪貼簿處理),**非完整 nvim 設定**。 | [↓](#nvim) |
| `home/dot_config/opencode/` | `~/.config/opencode/` | [opencode](https://opencode.ai) 設定:MCP servers 與外掛,**不含模型供應商**。 | [↓](#opencode) |
| `home/dot_config/private_code-server/` | `~/.config/code-server/`(600) | code-server 設定 template,密碼由 chezmoi 帶入。 | [↓](#code-server) |
| `ai-agent/` | — | 兩份 think-mode 對抗式 persona,**手動貼用**,不部署。 | [↓](#ai-agent-規則) |
| `script/ubuntu/` | — | Ubuntu(apt)開發環境安裝:`setup.sh`、`install-base.sh`、`install-tools.sh`。 | [↓](#安裝與部署) |
| `script/termux/` | — | Android/Termux 桌面環境腳本(xfce/tablet),與 Ubuntu 無關。 | [↓](#termux) |
| `wsl/` | — | Windows 主機側的 WSL2 設定與 portproxy 備忘,**手動使用**。 | [↓](#wsl) |
| `docs/` | — | 說明文件,見上方[延伸文件](#延伸文件)。 | — |
```

- [ ] **Step 2: 替換 README 第 31-131 行(整個部署章節)**

刪除原本的〈安裝與部署〉〈zshrc 部署〉〈ssh 部署〉〈AI agent 部署〉〈code-server 部署〉五節,替換為:

```markdown
## 安裝與部署

家目錄的設定檔由 [chezmoi](https://www.chezmoi.io) 部署,新機器一行:

```bash
sh -c "$(curl -fsLS get.chezmoi.io)" -- -b "$HOME/.local/bin" init --apply henry5720
```

這行做三件事:裝 chezmoi、clone 本 repo 到 `~/.local/share/chezmoi`、把 `home/` 底下的設定檔部署到家目錄。過程中會問一次 code-server 密碼(見[秘密](#秘密))。

套件安裝是另一條線,chezmoi 不管:

```bash
cd ~/.local/share/chezmoi
bash script/ubuntu/install-base.sh    # 基底(強制):zsh/git/curl/vim + zsh 插件 + 預設 shell
bash script/ubuntu/install-tools.sh   # 工具(可選):編號多選 fastfetch / btop / nvm / code-server
```

工具選單:空格分隔多選(例 `1 3`),直接 Enter = 全裝。兩者順序無所謂——`.zshrc` 對插件缺檔有防呆。

### 日常操作

| 想做的事 | 指令 |
|---|---|
| 改某個設定檔 | `chezmoi edit --apply ~/.zshrc` |
| 進 repo 目錄 | `chezmoi cd` |
| 別台改過、這台要同步 | `chezmoi update`(= pull + apply) |
| 看有什麼還沒套用 | `chezmoi diff` |
| 把本機的手動修改收回 repo | `chezmoi re-add` |
| 改密碼之類的秘密 | `chezmoi edit-config` 後 `chezmoi apply` |

> ⚠️ 直接編輯 `~/.zshrc` 這種**已部署的檔案不會回到 repo**,下次 `chezmoi apply` 還會被蓋掉。
> 要嘛用 `chezmoi edit`,要嘛改完立刻 `chezmoi re-add`。這是從 symlink 換成 chezmoi 之後
> 唯一真正要改的習慣。

### 檔名前綴

`home/` 底下的檔名有規則,對應到部署後的樣子:

| 前綴 / 後綴 | 意思 |
|---|---|
| `dot_` | 部署成 `.` 開頭 |
| `private_` | 權限收成 600(目錄 700) |
| `executable_` | 部署後帶 +x |
| `symlink_` | 部署成 symlink,檔案內容就是連結目標 |
| `.tmpl` | 先跑 Go template 再部署 |

### 秘密

repo 是公開的,秘密一律不進 git。目前只有一個:code-server 密碼。

`chezmoi init` 時問一次,存在 `~/.config/chezmoi/chezmoi.toml`(**不在 repo**),由
`home/dot_config/private_code-server/private_config.yaml.tmpl` 的 `{{ .codeServerPassword }}` 帶入。

### ssh

`~/.ssh/config` 由 chezmoi 部署,權限自動收成 `~/.ssh` 700 / `config` 600,不必手動 `chmod`。

**先決條件**:私鑰 `~/.ssh/henry5720`(config 內所有 Host 的 `IdentityFile`,**未附於 repo**)
要自己放好並 `chmod 600`,否則所有連線失敗。

> 原本 README 列的 Include / symlink / copy 三種部署方式已取消——chezmoi 統一走一種。
> 若某台機器需要額外的本機 Host,在 `home/private_dot_ssh/config` 加 template 條件,
> 不要在家目錄直接改(會被下次 apply 蓋掉)。

### AI agent 規則

規則本體是 `home/dot_claude/CLAUDE.md`,部署成 `~/.claude/CLAUDE.md`。
opencode 那邊的 `~/.config/opencode/AGENTS.md` 是 chezmoi 建的 symlink 指過去,**不用手動 `ln`**。

本 repo 只管**規則**;skill、MCP、plugin 是訂閱來的,不進本 repo。
四者的差別、各自怎麼裝與更新,見 [`docs/ai-agent-setup.md`](docs/ai-agent-setup.md)。

### code-server

`install-tools.sh` 的選單裡選 `code-server` 會用官方腳本裝 binary;設定檔由 chezmoi 部署,
密碼見[秘密](#秘密)。

```bash
code-server     # 要用的時候再開,丟 tmux 裡
```

要它一直在(重開機自動起、沒開終端機也活著)才需要 systemd,
`systemctl --user enable --now code-server` 加 `sudo loginctl enable-linger "$USER"`。
手動開就用不到——WSL 反正重開機也不會自己起來。

預設只綁 `127.0.0.1:8080`、`cert: false`,也就是**假設 TLS 由外層處理**。
從 pad / 手機連進來有五種做法(ssh tunnel、`tailscale serve`、`tailscale cert`、自簽、mkcert),
各自的代價與指令見 [`docs/code-server-remote.md`](docs/code-server-remote.md)。
```

- [ ] **Step 3: 更新 README 結尾的注意事項**

原第 219 行起的〈⚠️ 機器特定 / fork 前需自行修改〉,第 4、5 項路徑已變。改為:

```markdown
4. `home/dot_claude/CLAUDE.md` 是 henry 的**個人回覆偏好**(繁中、白話),fork 前請整份換掉。
5. `home/private_dot_ssh/config` 內的 Host 與 `IdentityFile` 是 henry 的,fork 後整份替換。
```

其餘 1、2、3、6 項不動(它們指的路徑沒變或本來就在 repo 根)。

- [ ] **Step 4: 更新 ai-agent-setup.md**

第 41 行:

```bash
ln -sfn ~/code/dotfiles/ai-agent/AGENTS.md ~/.claude/CLAUDE.md
```

改為:

```bash
# 規則由 chezmoi 部署,不用手動 ln
chezmoi apply ~/.claude/CLAUDE.md
```

第 222 行表格列:

```markdown
| 新機器套用規則 | `ln -sfn ~/code/dotfiles/ai-agent/AGENTS.md ~/.claude/CLAUDE.md` |
```

改為:

```markdown
| 新機器套用規則 | `chezmoi init --apply henry5720`(規則含在裡面) |
```

**第 124 行與第 225 行不要動**——那兩行講的是 skill 的安裝(`~/code/<名字>/skills/`),跟 dotfiles 路徑無關。

- [ ] **Step 5: 驗收——無殘留舊路徑**

```bash
cd ~/.local/share/chezmoi
grep -rn 'code/dotfiles' README.md docs/ai-agent-setup.md    # 預期:無輸出
grep -rn 'ai-agent/AGENTS.md' README.md docs/ai-agent-setup.md  # 預期:無輸出
grep -c 'chezmoi' README.md    # 預期:> 10
```

`docs/superpowers/` 底下仍會有 `code/dotfiles` —— **那是歷史存檔,正確,不要改**。

- [ ] **Step 6: 驗收——文件裡的指令真的能跑**

```bash
cd "$(chezmoi source-path)/.." && pwd     # 預期:/home/henry/.local/share/chezmoi
bash -n script/ubuntu/install-base.sh && bash -n script/ubuntu/install-tools.sh && echo SCRIPTS_OK
```

第一行驗證 README 教的 `cd "$(chezmoi source-path)/.."` 確實會落在 repo 根。

- [ ] **Step 7: Commit 並推上遠端**

```bash
cd ~/.local/share/chezmoi
git add README.md docs/ai-agent-setup.md
git commit -m "docs: 部署章節改寫為 chezmoi

刪掉 zshrc symlink、ssh 三選一、AI agent 手動 ln、code-server cp 範本
四節,收斂成單一的 chezmoi 章節。加上日常操作表與檔名前綴對照。

目錄結構表改列來源路徑與部署目標。ai-agent-setup.md 兩處部署指令
一併更新(第 124/225 行講的是 skill 安裝,與 dotfiles 無關,不動)。"
git push
```

---

## 完成後的整體驗收

```bash
cd ~/.local/share/chezmoi
chezmoi doctor                  # 無 ERROR
chezmoi verify && echo OK       # 家目錄與來源一致
chezmoi status                  # 無輸出
git status --short              # 無輸出
env -i HOME="$HOME" TERM=dumb /bin/zsh -lic 'echo $PATH' | tr ':' '\n' | grep -E '\.local/bin|\.opencode/bin'
tmux new -d -s _f && tmux kill-session -t _f && echo TMUX_OK
```

備份 `~/.dotfiles-pre-chezmoi-backup/` 確認用不到之後再自行刪除,本計畫不刪。
