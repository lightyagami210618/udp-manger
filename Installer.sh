#!/bin/bash
# Zivpn UDP Module All-in-One Installer & Manager Setup
# GitHub Repository: lightyagami210618/udp-manger

# Color Definitions
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

clear
echo -e "${CYAN}==========================================${NC}"
echo -e "${GREEN}   STARTING ZIVPN UDP AUTO INSTALLATION   ${NC}"
echo -e "${CYAN}==========================================${NC}"
sleep 2

# ၁။ Server Update ပြုလုပ်ခြင်းနှင့် လိုအပ်သော Packages များ တင်ခြင်း
echo -e "\n${YELLOW}[1/6] Updating system and installing dependencies...${NC}"
apt-get update -y
apt-get install -y wget curl jq openssl iptables ufw

# ၂။ ယခင် ရှိပြီးသား Service ကို ရပ်တန့်ခြင်း
systemctl stop zivpn.service 1> /dev/null 2> /dev/null

# ၃။ ZiVPN Binary ကို ဒေါင်းလုဒ်ဆွဲခြင်းနှင့် Custom Config ဖန်တီးခြင်း
echo -e "\n${YELLOW}[2/6] Downloading ZiVPN UDP Binary...${NC}"
wget https://github.com/zahidbd2/udp-zivpn/releases/download/udp-zivpn_1.4.9/udp-zivpn-linux-amd64 -O /usr/local/bin/zivpn-core 1> /dev/null 2> /dev/null
chmod +x /usr/local/bin/zivpn-core

mkdir -p /etc/zivpn
cat <<EOF > /etc/zivpn/config.json
{
  "listen": ":5667",
  "cert": "/etc/zivpn/zivpn.crt",
  "key": "/etc/zivpn/zivpn.key",
  "auth": {
    "mode": "passwords",
    "config": []
  }
}
EOF

# ၄။ SSL Certificates နှင့် System Settings များ ပြုလုပ်ခြင်း
echo -e "\n${YELLOW}[3/6] Generating SSL Certificates & Optimizing System...${NC}"
openssl req -new -newkey rsa:4096 -days 365 -nodes -x509 -subj "/C=US/ST=California/L=Los Angeles/O=Example Corp/OU=IT Department/CN=zivpn" -keyout "/etc/zivpn/zivpn.key" -out "/etc/zivpn/zivpn.crt" 1> /dev/null 2> /dev/null

sysctl -w net.core.rmem_max=16777216 1> /dev/null 2> /dev/null
sysctl -w net.core.wmem_max=16777216 1> /dev/null 2> /dev/null

# ၅။ Systemd Service ဖန်တီးခြင်း
echo -e "\n${YELLOW}[4/6] Creating Systemd Service...${NC}"
cat <<EOF > /etc/systemd/system/zivpn.service
[Unit]
Description=zivpn VPN Server
After=network.target

[Service]
Type=simple
User=root
WorkingDirectory=/etc/zivpn
ExecStart=/usr/local/bin/zivpn-core server -c /etc/zivpn/config.json
Restart=always
RestartSec=3
Environment=ZIVPN_LOG_LEVEL=info
CapabilityBoundingSet=CAP_NET_ADMIN CAP_NET_BIND_SERVICE CAP_NET_RAW
AmbientCapabilities=CAP_NET_ADMIN CAP_NET_BIND_SERVICE CAP_NET_RAW
NoNewPrivileges=true

[Install]
WantedBy=multi-user.target
EOF

# ၆။ Firewall Rules နှင့် Port Forwarding သတ်မှတ်ခြင်း
echo -e "\n${YELLOW}[5/6] Configuring Firewall & Port Forwarding...${NC}"
systemctl daemon-reload
systemctl enable zivpn.service
systemctl start zivpn.service

IFACE=$(ip -4 route ls | grep default | grep -Po '(?<=dev )(\S+)' | head -1)
iptables -t nat -A PREROUTING -i "$IFACE" -p udp --dport 6000:19999 -j DNAT --to-destination :5667
ufw allow 6000:19999/udp 1> /dev/null 2> /dev/null
ufw allow 5667/udp 1> /dev/null 2> /dev/null

# ၇။ Colored Manager Menu Panel ဖန်တီးခြင်း
echo -e "\n${YELLOW}[6/6] Setting up ZiVPN Manager Menu Command...${NC}"
cat <<'EOF' > /usr/local/bin/zivpn
#!/bin/bash

CONFIG_FILE="/etc/zivpn/config.json"

# Color Definitions
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
PURPLE='\033[0;35m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

zivpn_menu() {
    clear
    echo -e "${CYAN}==========================================${NC}"
    echo -e "${PURPLE}       ZiVPN UDP ACCOUNT MANAGER          ${NC}"
    echo -e "${CYAN}==========================================${NC}"
    echo -e " ${YELLOW}Status${NC}    : ${GREEN}$(systemctl is-active zivpn.service)${NC}"
    echo -e " ${YELLOW}Server IP${NC} : ${GREEN}$(curl -4 -s ifconfig.me)${NC}"
    echo -e " ${YELLOW}UDP Ports${NC} : ${GREEN}6000:19999 (DNAT -> 5667)${NC}"
    echo -e "${CYAN}==========================================${NC}"
    echo -e " ${YELLOW}[1]${NC} Add New Password"
    echo -e " ${YELLOW}[2]${NC} Delete Password"
    echo -e " ${YELLOW}[3]${NC} Show Active Passwords"
    echo -e " ${YELLOW}[4]${NC} Restart ZiVPN Service"
    echo -e " ${YELLOW}[5]${NC} Uninstall ZiVPN UDP"
    echo -e " ${YELLOW}[0]${NC} Exit"
    echo -e "${CYAN}==========================================${NC}"
    read -p "//_ Choose an option: " opt

    case $opt in
        1)
            echo -e "\n${CYAN}--- Add New Password ---${NC}"
            read -p "Enter new password: " new_pass
            if [ -n "$new_pass" ]; then
                jq --arg p "$new_pass" '.auth.config += [$p]' "$CONFIG_FILE" > /tmp/zivpn.tmp && mv /tmp/zivpn.tmp "$CONFIG_FILE"
                systemctl restart zivpn.service
                echo -e "\n${GREEN}[✔] Password '$new_pass' added successfully!${NC}"
            else
                echo -e "\n${RED}[!] Password cannot be empty!${NC}"
            fi
            sleep 2
            zivpn_menu
            ;;
        2)
            echo -e "\n${CYAN}--- Delete Password ---${NC}"
            read -p "Enter password to delete: " del_pass
            if [ -n "$del_pass" ]; then
                jq --arg p "$del_pass" '.auth.config -= [$p]' "$CONFIG_FILE" > /tmp/zivpn.tmp && mv /tmp/zivpn.tmp "$CONFIG_FILE"
                systemctl restart zivpn.service
                echo -e "\n${GREEN}[✔] Password '$del_pass' deleted successfully!${NC}"
            else
                echo -e "\n${RED}[!] Password cannot be empty!${NC}"
            fi
            sleep 2
            zivpn_menu
            ;;
        3)
            echo -e "\n${CYAN}==========================================${NC}"
            echo -e "${PURPLE}       CURRENT ZIVPN PASSWORDS            ${NC}"
            echo -e "${CYAN}==========================================${NC}"
            jq -r '.auth.config[]' "$CONFIG_FILE" 2>/dev/null || echo -e "${RED}No passwords found.${NC}"
            echo -e "${CYAN}==========================================${NC}"
            read -p "Press Enter to return..."
            zivpn_menu
            ;;
        4)
            systemctl restart zivpn.service
            echo -e "\n${GREEN}[✔] ZiVPN Service Restarted!${NC}"
            sleep 2
            zivpn_menu
            ;;
        5)
            echo -e "\n${RED}==========================================${NC}"
            read -p "Are you sure you want to uninstall ZiVPN UDP? (y/n): " confirm
            if [[ "$confirm" =~ ^[Yy]$ ]]; then
                echo -e "\n${YELLOW}Removing ZiVPN UDP Service & Files...${NC}"
                systemctl stop zivpn.service 2>/dev/null
                systemctl disable zivpn.service 2>/dev/null
                rm -f /etc/systemd/system/zivpn.service
                systemctl daemon-reload
                rm -rf /etc/zivpn
                rm -f /usr/local/bin/zivpn-core
                
                # Clearing Firewall rules
                ufw delete allow 6000:19999/udp 2>/dev/null
                ufw delete allow 5667/udp 2>/dev/null
                IFACE=$(ip -4 route ls | grep default | grep -Po '(?<=dev )(\S+)' | head -1)
                if [ -n "$IFACE" ]; then
                    iptables -t nat -D PREROUTING -i "$IFACE" -p udp --dport 6000:19999 -j DNAT --to-destination :5667 2>/dev/null
                fi
                
                echo -e "\n${GREEN}[✔] ZiVPN UDP has been completely uninstalled!${NC}"
                rm -f /usr/local/bin/zivpn /usr/bin/zivpn 2>/dev/null
                exit 0
            else
                echo -e "\n${YELLOW}[!] Uninstallation canceled.${NC}"
                sleep 2
                zivpn_menu
            fi
            ;;
        0)
            exit 0
            ;;
        *)
            echo -e "\n${RED}[!] Invalid Option!${NC}"
            sleep 1
            zivpn_menu
            ;;
    esac
}

zivpn_menu
EOF

# Menu command ကို execute permission ပေးခြင်း
chmod +x /usr/local/bin/zivpn

clear
echo -e "${CYAN}==========================================${NC}"
echo -e "${GREEN}    ZIVPN UDP INSTALLATION COMPLETE!     ${NC}"
echo -e "${CYAN}==========================================${NC}"
echo -e " Type '${YELLOW}zivpn${NC}' anywhere to open manager.   "
echo -e "${CYAN}==========================================${NC}"
