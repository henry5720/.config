---
name: company-imagegen-fallback
description: 使用者明確要求生成或編輯 raster 圖片時，透過共用 imagegen-fallback wrapper 直接呼叫公司 gateway，不呼叫 Codex。
---

# Company ImageGen fallback

當使用者明確要求生成或編輯 raster 圖片時，使用共用 wrapper 直接呼叫公司 gateway。
這條流程不呼叫 Codex，也不可用內建模型假裝已經生圖。

## 執行前

先在工作區確認 wrapper 可用：

```bash
test -x "$HOME/.local/bin/imagegen-fallback"
```

若檔案不存在或不可執行，據實回報，不要改用其他模型或自行安裝替代品。

## 生成圖片

先在工作區建立輸出目錄，再把產出寫入 `output/imagegen/`：

```bash
mkdir -p output/imagegen
~/.local/bin/imagegen-fallback generate \
  --prompt "使用者要求的圖片描述" \
  --out output/imagegen/result.png
```

## 編輯圖片

使用 `edit --image`，輸出仍放在工作區的 `output/imagegen/`：

```bash
mkdir -p output/imagegen
~/.local/bin/imagegen-fallback edit \
  --image path/to/input.png \
  --prompt "使用者要求的修改" \
  --out output/imagegen/edited.png
```

## 憑證與失敗處理

- 不得讀取、顯示、複製或要求使用者提供 API key。
- 不得把 API key 放進 prompt、指令、檔案或回覆。
- wrapper 失敗時，據實回報錯誤；不要宣稱圖片已生成，也不要改用內建模型假裝生圖。
- 只在使用者明確要求生成或編輯 raster 圖片時使用這個 fallback。
