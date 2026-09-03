遇到 PDF、DOCX、PPTX、XLSX、CSV、audio 或 video 時，必須先載入 `local-artifact-intake` 並由主 agent 完成本機 preflight；在 local preflight 被明確阻塞前不得 delegate，不要在這裡重複 skill 的長流程。
