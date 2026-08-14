# AI agent 環境:誰管什麼

用 Claude Code / opencode 之類的 coding agent 時,身上會有三種東西。
它們**放在不同地方、用不同方式更新**,搞混就會出現「我明明更新了怎麼沒變」。

這份講清楚每一種是什麼、你要不要管它。

## 三種東西

| | 是什麼 | 例子 | 誰寫的 | 放哪 |
|---|---|---|---|---|
| **規則** | 你希望 agent 怎麼做事 | 用繁中回、講白話 | **你** | 本 repo |
| **skill** | 一套做某件事的步驟 | 怎麼查 bug、怎麼跑 TDD | 別人 | `~/.agents/skills/` |
| **skill(自寫)** | 同上,但是你自己的 | 寫工作日誌、讀 PM 待辦 | **你** | `~/code/work-helper/skills/` |
| **plugin** | Claude 的擴充功能 | superpowers、context7 | 別人 | `~/.claude/plugins/` |

**你要維護的是「你寫的」那兩列。** 別人的是訂閱來的,跑指令更新就好,壞了重裝。

## 規則:一份本體,各 agent 拉線過去

問題是每家 agent 讀的檔名不一樣 —— Claude 只讀 `CLAUDE.md`,opencode 讀 `AGENTS.md`。
如果各寫一份,改了 A 忘了改 B,兩邊行為就會不一樣(這件事真的發生過)。

解法是**只留一份真的檔案,其他都是捷徑**:

```
ai-agent/AGENTS.md                    ← 真的檔案,只有這份要改
   ↑                    ↑
   │                    └── .config/opencode/AGENTS.md   (repo 內,clone 就有)
   └── ~/.claude/CLAUDE.md                               (要手動拉一次)
```

新機器只要跑這一行:

```bash
ln -sfn ~/code/dotfiles/ai-agent/AGENTS.md ~/.claude/CLAUDE.md
```

之後改 `ai-agent/AGENTS.md`、`git pull`,兩邊同時生效。跟 `.zshrc` 是同一招。

> ⚠️ 原本的 `~/.claude/CLAUDE.md` 如果有內容,上面那行會**直接蓋掉且不留備份**。
> 先 `cp ~/.claude/CLAUDE.md ~/.claude/CLAUDE.md.bak`。

### 規則要寫什麼

只寫「換到任何一個 repo 都還成立」的事。判斷方法:

- 換個 repo 就不成立(技術棧、build 指令、專案慣例)→ 寫在**那個 repo 自己的 `CLAUDE.md`**
- 是一套多步驟流程(查 bug、TDD、需求對齊)→ 寫成 **skill**,用到才載入
- linter、git hook、權限設定做得到 → **交給那些工具**,寫成規則只是「希望 agent 不要這樣做」

還有一條:**規則要能判斷有沒有違規**。
「講白話一點」沒辦法判斷;「一個句子拿掉抽象名詞就沒有資訊了就重寫」可以。
判斷不了的規則,你沒辦法抓它,agent 也就不會穩定遵守。

### 不要把本體放在 `dotfiles/.claude/CLAUDE.md`

看起來很整齊,但會出事。Claude 認的專案指引位置就是 `./CLAUDE.md` 或 `./.claude/CLAUDE.md`,
而多份 CLAUDE.md 是**接在一起**送進去、不是互相覆蓋。

所以在 dotfiles 裡開 Claude 會讀到兩次:一次是你的個人設定,一次是「dotfiles 這個專案的設定」——
同一份規則載入兩遍,白花錢,而且重複的指令本身就會讓 agent 更難遵守。

## skill:別人的東西,不進本 repo

skill 是一套「做某件事的步驟」,平常不佔空間,用到才載入。目前裝的來自四個 repo:

```bash
npx skills@latest add mattpocock/skills     # 主力:grill-with-docs / diagnosing-bugs / tdd …
npx skills@latest add Leonxlnx/taste-skill  # 前端設計品味
npx skills@latest add stablyai/orca         # orca-cli / orchestration
npx skills@latest add vercel-labs/skills
```

裝的時候會問你要哪幾個、要裝給哪些 agent。

### 裝完長這樣

```
~/.agents/skills/tdd/          ← 真的檔案(通用 agent 都讀這裡)
      ↑
      └── ~/.claude/skills/tdd  ← 捷徑
```

**跟規則是一樣的結構,只是這個是工具自動做的,你不用管。**
所以不需要再把 skill 搬進 dotfiles 手動拉線,那是把已經自動化的事改回手動。

### 為什麼不版控

那些檔案是別人 repo 裡的。複製進來以後:

- 上游改了,你的版本不會跟著動
- 想跟上就得手動比對、手動貼、處理衝突
- 你的 dotfiles 從「我的設定」變成「我的設定 + 別人四個 repo 的快照」

一行指令能更新的事,變成長期的維護負擔。所以這裡**只記去哪裡拿,不記東西本身**。

重灌時就是把上面四行再跑一次。

### 自己寫的 skill:在 work-helper,一樣不進本 repo

上面講的是**別人的** skill。自己寫的沒有上游,`npx skills update` 管不到,
但結論一樣——**不放 dotfiles**,理由換成:

**skill 要跟它依賴的東西放一起。** 例如 `slack-todo` 一定會呼叫
`work-helper/bin/slack-list`。放在同一個 repo,路徑是相對的、一次 commit 改完;
拆兩個 repo 就得硬寫絕對路徑,而且遲早不同步。

所以自己寫的 skill 都在 `~/code/work-helper/skills/`,這裡照樣**只記去哪裡拿**:

```bash
git clone git@github.com:henry5720/work-helper.git ~/code/work-helper
for s in ~/code/work-helper/skills/*/; do
  ln -sfn "$s" ~/.claude/skills/"$(basename "$s")"
done
```

跟 `.zshrc`、`AGENTS.md` 是同一招:真的檔案只有一份,`~/.claude/skills/` 底下全是捷徑。

### 更新

```bash
npx skills@latest update -g -y   # 全部更新,-g 是「裝給所有專案的那些」
npx skills@latest update tdd     # 只更新一個
npx skills@latest list -g        # 看現在裝了哪些、各自來自哪
npx skills@latest remove <名字>  # 移除
```

> ⚠️ 更新會**蓋掉你手改過的內容**。想改某個 skill,先另存一份再改。

> ⚠️ mattpocock 的 skill 有兩種裝法(這裡用的 `npx skills`,以及 Claude 的 plugin),
> 官方說**只能選一種**,兩種都裝會變成每個 skill 兩份。這裡走 `npx skills`,
> 所以不要再去 `claude plugins install mattpocock-skills`。

## plugin:另一套,前面的指令管不到

Claude 的 plugin 跟 skill 是兩回事,`npx skills update` **完全不會動到它們**。

目前裝的:`superpowers`、`context7`、`typescript-lsp`、`claude-hud`。

更新方式是在 Claude 裡打 `/plugin`。

opencode 那邊也有自己的 plugin,寫在 `.config/opencode/opencode.json` 的 `plugin` 欄位,
由 opencode 自己更新,也跟上面兩套無關。

## 懶人包

| 想做什麼 | 怎麼做 |
|---|---|
| 改 agent 的行為規則 | 改 `ai-agent/AGENTS.md`,commit |
| 新機器套用規則 | `ln -sfn ~/code/dotfiles/ai-agent/AGENTS.md ~/.claude/CLAUDE.md` |
| 更新 skill | `npx skills@latest update -g -y` |
| 更新 Claude plugin | Claude 裡打 `/plugin` |
| 重灌後裝回 skill | 跑上面那四行 `npx skills@latest add` |
| 確認規則有生效 | 開新 session 打 `/context`,看 **Memory files** 那區 |
