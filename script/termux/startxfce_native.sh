#!/data/data/com.termux/files/usr/bin/bash

## 1. 環境清理
pkill -9 termux-x11
pkill -9 xfce4-session
pkill -9 virgl
pkill -9 pulseaudio

## 2. 啟動音訊與顯示後端
rm -rf ~/.config/pulse
pulseaudio --start --exit-idle-time=-1 >/dev/null 2>&1

termux-x11 :0 >/dev/null 2>&1 &
sleep 2
am start --user 0 -n com.termux.x11/com.termux.x11.MainActivity > /dev/null 2>&1
sleep 1

## 3. 穩定渲染配置 (llvmpipe 極速模式)
export DISPLAY=:0
export PULSE_SERVER=127.0.0.1

# 核心：強制使用 CPU 軟體渲染，避開驅動崩潰
export GALLIUM_DRIVER=llvmpipe

# 效能優化：讓你的 8 核心 CPU 全部參與圖形計算
export LP_NUM_THREADS=8
export mesa_glthread=true

# 提升 Chromium 在 X11 下的記憶體效率
export X11_OVERRIDE_MEMFD=1

## 4. 啟動桌面環境
dbus-launch --exit-with-session xfce4-session

