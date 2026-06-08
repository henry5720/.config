# 常用指令

## 看wsl hostname
wsl hostname -I

## 設定rule
netsh interface portproxy add v4tov4 listenaddress=0.0.0.0 listenport=3000 connectaddress=172.21.99.140 connectport=3000

## 看目前有哪些 rule
netsh interface portproxy show all

## 刪除單條
netsh interface portproxy delete v4tov4 listenaddress=0.0.0.0 listenport=3009
netsh interface portproxy delete v4tov4 listenaddress=0.0.0.0 listenport=3000

## 清空全部
netsh interface portproxy flush