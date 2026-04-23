#!/bin/bash

echo "[+] Installing EvilNet..."

if [[ $EUID -ne 0 ]]; then
    echo "[!] Use: sudo ./install.sh"
    exit 1
fi

apt update
apt install -y hostapd dnsmasq aircrack-ng tcpdump lighttpd php-cgi iw net-tools macchanger bridge-utils

mkdir -p /opt/EvilNet/{logs,configs,certificates,templates}

cp evilnet3.sh /usr/local/bin/EvilNet
chmod +x /usr/local/bin/EvilNet

echo "[+] Complete! Execute: sudo EvilNet"
