#!/data/data/com.termux/files/usr/bin/bash

termux-setup-storage
termux-change-repo
pkg update
pkg upgrade -y
pkg install -y vim git

# GUI
pkg install -y x11-repo
pkg install -y termux-x11-nightly xfce4 pulseaudio xfce4-terminal xfce4-taskmanager chromium code-oss openssh

# SSHFS
pkg install sshfs
