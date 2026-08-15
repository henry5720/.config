# code-server 遠端存取:五種做法

從別台裝置（pad、phone、筆電）連自己的 code-server，卡點永遠是同一個：**憑證**。
這份列出所有可行做法和各自代價，phone 和 desktop 各自選一個就好。

---

## 先搞懂卡在哪

瀏覽器只把兩種來源當成 **secure context**：`https://`（憑證有效）和 `localhost`。
不是 secure context 的話，code-server 這些功能會壞：

- webview（markdown preview、大部分擴充套件的 UI）
- 剪貼簿 API
- service worker——這個最硬，**憑證有錯誤時 Chrome 直接拒絕註冊**，按「繼續前往」也沒用

所以 `http://100.119.136.27:8080` 這種 tailscale IP 直連，是「連得到但不好用」。
tailscale 負責的是**連得到**，secure context 要另外生出來。

---

## 方案總表

| | 做法 | 誰負責 TLS | 要改 code-server 設定 | 主要代價 |
|---|---|---|---|---|
| **A** | SSH tunnel（`ssh -L`） | 不需要，走 localhost | 否 | 每次要先開 tunnel，斷線就掛 |
| **B** | `tailscale serve` | tailscale（真憑證） | 否 | 需要該台有 tailscale CLI |
| **C** | `tailscale cert` + code-server 吃憑證 | code-server（真憑證） | 是 | 憑證要自己續期 |
| **D** | code-server 自簽憑證 | code-server（自簽） | 是 | service worker 會壞 |
| **E** | mkcert 自簽 + 手機裝 CA | code-server（自簽但被信任） | 是 | 每台 client 都要裝 CA |

B、C 的憑證都是 tailscale 幫你跟 Let's Encrypt 要的**真憑證**，網域是
`<機器名>.<你的 tailnet>.ts.net`。前提是 admin console 要開 MagicDNS 和 HTTPS Certificates
（Settings → DNS）。

---

## phone(Termux)可以用哪些

**能用：A、D、E。B、C 實質上不行。**

原因：Android 的 Tailscale app 只有 GUI，沒有 CLI，`tailscale serve` 和 `tailscale cert`
都碰不到。要有 CLI 就得在 Termux 自己裝 tailscale + tailscaled，而且非 root 沒有 TUN 權限，
得跑 `--tun=userspace-networking`——它會變成 tailnet 裡的**第二個節點**（跟 app 那個不同 IP、
不同名字），加上 Android 會殺背景 process，還要 `termux-wake-lock` 和 Termux:Boot 才活得久。

### A|SSH tunnel（建議）

`.ssh/config` 的 `Host phone` 已經備好了，**在 pad 上執行**：

```bash
# phone (Termux):code-server 綁 127.0.0.1,不對外開
code-server --bind-addr 127.0.0.1:8080

# pad (Termux):
ssh phone
# pad 瀏覽器開 http://localhost:8080
```

`LocalForward` 左邊在**執行 ssh 的那台**開 port，右邊的 `localhost` 在 **phone 上**解析。
連線中要臨時加 port：換行後按 `~C`，輸入 `-L 5173:localhost:5173`。

---

## henry-desktop 可以用哪些

**全部都能用。B 最省事。**

這台 WSL 因為 `.wslconfig` 設了 `networkingMode=mirrored`（`wsl/.wslconfig:14`），
eth0 上直接掛著 tailnet IP `100.119.136.27`，WSL 裡的服務綁 `127.0.0.1`，
Windows 側也看得到，中間不用接任何東西。

注意：**tailscale 指令要在 Windows 那側跑**，WSL 裡的 tailscale 是 `Logged out` 狀態。

### B|tailscale serve（建議）

code-server 完全不用改設定，tailscale 在前面當反向代理並終結 TLS：

```powershell
# Windows PowerShell,設一次就常駐
tailscale serve --bg --https=8080 8080
tailscale serve status      # 確認,順便看到完整網址
```

之後任何裝置的瀏覽器開 `https://henry-desktop.<你的 tailnet>.ts.net:8080`。

要撤掉：`tailscale serve --https=8080 off`。

### C|tailscale cert + code-server 吃憑證

不想多一層 proxy、想讓 code-server 自己講 HTTPS 的話：

```powershell
# Windows,憑證會寫在當前目錄
tailscale cert henry-desktop.<你的 tailnet>.ts.net
```

然後在 `~/.config/code-server/config.yaml` 填 `cert` / `cert-key` 指向那兩個檔
（WSL 從 `/mnt/c/...` 讀得到）。

代價：憑證約 90 天到期，要自己排程重跑 `tailscale cert`，B 沒這問題。

### A|SSH tunnel

臨時用、不想動任何設定的時候：

```bash
ssh -L 8080:localhost:8080 henry-desktop
```

---

## D、E:自簽憑證(兩台都適用,但都有坑)

### D|code-server 自己產自簽憑證

```yaml
# ~/.config/code-server/config.yaml
cert: true
```

或 `code-server --cert`。憑證產在 `~/.local/share/code-server/self-signed.crt`。

**坑**：瀏覽器不信任自簽憑證，按「繼續前往」可以看到畫面，但 Chrome 會擋掉
service worker 註冊（`Failed to register a ServiceWorker`），部分擴充套件會壞。
`https://` 這個 scheme 本身讓 `isSecureContext` 為 true，所以剪貼簿等 API 大多還能用，
但這是「半殘」狀態，能選 B/C 就別選這個。

### E|mkcert 產憑證 + 手機裝 CA

把 D 的坑補起來：用 mkcert 建一個本機 CA，把 `rootCA.pem` 裝到每台要連的裝置上，
之後憑證就是「被信任的」，service worker 正常。

```bash
mkcert -install
mkcert henry-desktop.local 100.119.136.27
# 把產出的 pem 填進 config.yaml 的 cert / cert-key
```

**坑**：每台 client 都要裝 CA。Android 裝的是 user CA——Chrome 瀏覽網頁認，
但 app 不認，而且系統會一直顯示「網路可能受監控」。Android 11 之後對 CA 的限制也越來越緊。

適用情境：完全離線、沒有 tailscale 的環境。有 tailscale 就直接用 B。

---

## 密碼放哪

tailscale 那層已經擋掉 tailnet 以外的人,code-server 的密碼是第二道。

`.config/code-server/config.yaml.example` 是**範本**,安裝腳本會 cp 一份到
`~/.config/code-server/config.yaml`(順便 `chmod 600`)。密碼填在 cp 出來的那份,不要填回
範本——範本在 git 裡,而且這個 repo 是公開的。argon2 hash 一樣不能放,它是可以離線爆的。

明碼就夠了。tailscale 已經把非 tailnet 的人全擋在外面,code-server 自己的預設也是明碼
(第一次啟動會產一組隨機的寫進 config.yaml)。唯一要守的是**別用你其他地方在用的密碼**,
明碼落在磁碟上,外洩就是直接可用。

```yaml
# ~/.config/code-server/config.yaml
password: 你的密碼
```

想更保險再換 argon2 hash(`echo -n '你的密碼' | npx argon2-cli -e`),`hashed-password`
優先於 `password`,兩個留一個。兩個都空著的話 code-server 啟動會直接報錯
(`main.js:152`),不會偷偷放行。

環境變數 `HASHED_PASSWORD` / `PASSWORD` 又會蓋過設定檔
(code-server 讀完會把它們從 `process.env` 刪掉,不傳給子 process),但**只有你手動在終端機
前景跑 `code-server` 時才有用**——systemd 起的 service 不經過 shell,讀不到任何 shell rc。

要手機隨時連得到就得常駐,所以走 systemd:

```bash
systemctl --user enable --now code-server
sudo loginctl enable-linger "$USER"   # 沒開終端機時也讓它活著
```

⚠️ WSL 的限制:Windows 重開機後 WSL 不會自己起來,systemd 服務也就不在,手機會連不到。

## 一句話結論

- **phone** → A（`ssh phone`，config 已備好）
- **henry-desktop** → B（`tailscale serve`，設一次就好）

---

## 參考

- [code-server：TLS 設定](https://coder.com/docs/code-server/guide)（`--cert` / `--cert-key`、自簽憑證路徑）
- [code-server #6809：自簽憑證下 plugin 失效](https://github.com/coder/code-server/issues/6809)
- [code-server #7206：insecure context 的症狀](https://github.com/coder/code-server/discussions/7206)
- [Chromium：ServiceWorker 不接受自簽憑證](https://issues.chromium.org/issues/40423989)
- [mkcert](https://github.com/FiloSottile/mkcert)
