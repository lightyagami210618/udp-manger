#!/bin/bash
# Zivpn UDP Module All-in-One Installer & Manager Setup
# GitHub Repository: lightyagami210618/udp-manger

clear
echo "=========================================="
echo "   STARTING ZIVPN UDP AUTO INSTALLATION   "
echo "=========================================="
sleep 2

# ၁။ Server Update ပြုလုပ်ခြင်းနှင့် လိုအပ်သော Packages များ တင်ခြင်း
echo -e "\n[1/6] Updating system and installing dependencies..."
apt-get update -y
apt-get install -y wget curl jq openssl iptables ufw

# ၂။ ယခင် ရှိပြီးသား Service ကို ရပ်တန့်ခြင်း
systemctl stop zivpn.service 1> /dev/null 2> /dev/null

# ၃။ ZiVPN Binary ကို ဒေါင်းလုဒ်ဆွဲပြီး Permission ပေးခြင်း
echo -e "\n[2/6] Downloading ZiVPN UDP Binary..."
wget https://github.com/zahidbd2/udp-zivpn/releases/download/udp-zivpn_1.4.9/udp-zivpn-linux-amd64 -O /usr/local/bin/zivpn 1> /dev/null 2> /dev/null
chmod +x /usr/local/bin/zivpn

mkdir -p /etc/zivpn
wget https://raw.githubusercontent.com/zahidbd2/udp-zivpn/main/config.json -O /etc/zivpn/config.json 1> /dev/null 2> /dev/null

# ၄။ SSL Certificates နှင့် System Settings များ ပြုလုပ်ခြင်း
echo -e "\n[3/6] Generating SSL Certificates & Optimizing System..."
openssl req -new -newkey rsa:4096 -days 365 -nodes -x509 -subj "/C=US/ST=California/L=Los Angeles/O=Example Corp/OU=IT Department/CN=zivpn" -keyout "/etc/zivpn/zivpn.key" -out "/etc/zivpn/zivpn.crt" 1> /dev/null 2> /dev/null

sysctl -w net.core.rmem_max=16777216 1> /dev/null 2> /dev/null
sysctl -w net.core.wmem_max=16777216 1> /dev/null 2> /dev/null

# ၅။ Systemd Service ဖန်တီးခြင်း
echo -e "\n[4/6] Creating Systemd Service..."
cat <<EOF > /etc/systemd/system/zivpn.service
[Unit]
Description=zivpn VPN Server
After=network.target

[Service]
Type=simple
User=root
WorkingDirectory=/etc/zivpn
ExecStart=/usr/local/bin/zivpn server -c /etc/zivpn/config.json
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
echo -e "\n[5/6] Configuring Firewall & Port Forwarding..."
systemctl daemon-reload
systemctl enable zivpn.service
systemctl start zivpn.service

IFACE=$(ip -4 route ls | grep default | grep -Po '(?<=dev )(\S+)' | head -1)
iptables -t nat -A PREROUTING -i "$IFACE" -p udp --dport 6000:19999 -j DNAT --to-destination :5667
ufw allow 6000:19999/udp 1> /dev/null 2> /dev/null
ufw allow 5667/udp 1> /dev/null 2> /dev/null

# ၇။ Manager Menu Panel (Built-in Uninstall အပါအဝင်) ဖန်တီးခြင်း
echo -e "\n[6/6] Setting up ZiVPN Manager Menu Command..."
cat <<'EOF' > /usr/bin/zivpn
#!/bin/bash

CONFIG_FILE="/etc/zivpn/config.json"

zivpn_menu() {
    clear
    echo "=========================================="
    echo "       ZiVPN UDP ACCOUNT MANAGER          "
    echo "=========================================="
    echo " Status    : $(systemctl is-active zivpn.service)"
    echo " Server IP : $(curl -s ifconfig.me)"
    echo " UDP Ports : 6000:19999 (DNAT -> 5667)"
    echo "=========================================="
    echo "[1] Add New Password"
    echo "[2] Delete Password"
    echo "[3] Show Active Passwords"
    echo "[4] Restart ZiVPN Service"
    echo "[5] Uninstall ZiVPN UDP"
    echo "[0] Exit"
    echo "=========================================="
    read -p "//_ Choose an option: " opt

    case $opt in
        1)
            echo -e "\n--- Add New Password ---"
            read -p "Enter new password: " new_pass
            if [ -n "$new_pass" ]; then
                jq --arg p "$new_pass" '.config += [$p]' "$CONFIG_FILE" > /tmp/zivpn.tmp && mv /tmp/zivpn.tmp "$CONFIG_FILE"
                systemctl restart zivpn.service
                echo -e "\n[✔] Password '$new_pass' added successfully!"
            else
                echo -e "\n[!] Password cannot be empty!"
            fi
            sleep 2
            zivpn_menu
            ;;
        2)
            echo -e "\n--- Delete Password ---"
            read -p "Enter password to delete: " del_pass
            if [ -n "$del_pass" ]; then
                jq --arg p "$del_pass" '.config -= [$p]' "$CONFIG_FILE" > /tmp/zivpn.tmp && mv /tmp/zivpn.tmp "$CONFIG_FILE"
                systemctl restart zivpn.service
                echo -e "\n[✔] Password '$del_pass' deleted successfully!"
            else
                echo -e "\n[!] Password cannot be empty!"
            fi
            sleep 2
            zivpn_menu
            ;;
        3)
            echo -e "\n=========================================="
            echo "       CURRENT ZIVPN PASSWORDS            "
            echo "=========================================="
            jq -r '.config[]' "$CONFIG_FILE" 2>/dev/null || echo "No passwords found."
            echo "=========================================="
            read -p "Press Enter to return..."
            zivpn_menu
            ;;
        4)
            systemctl restart zivpn.service
            echo -e "\n[✔] ZiVPN Service Restarted!"
            sleep 2
            zivpn_menu
            ;;
        5)
            echo -e "\n=========================================="
            read -p "Are you sure you want to uninstall ZiVPN UDP? (y/N): " confirm
            if [[ "$confirm" =~ ^[Yy]$ ]]; then
                echo -e "\nRemoving ZiVPN UDP Service & Files..."
                systemctl stop zivpn.service 2>/dev/null
                systemctl disable zivpn.service 2>/dev/null
                rm -f /etc/systemd/system/zivpn.service
                systemctl daemon-reload
                rm -rf /etc/zivpn
                rm -f /usr/local/bin/zivpn
                
                # Clearing Firewall rules
                ufw delete allow 6000:19999/udp 2>/dev/null
                ufw delete allow 5667/udp 2>/dev/null
                IFACE=$(ip -4 route ls | grep default | grep -Po '(?<=dev )(\S+)' | head -1)
                if [ -n "$IFACE" ]; then
                    iptables -t nat -D PREROUTING -i "$IFACE" -p udp --dport 6000:19999 -j DNAT --to-destination :5667 2>/dev/null
                fi
                
                echo -e "\n[✔] ZiVPN UDP has been completely uninstalled!"
                rm -f /usr/bin/zivpn
                exit 0
            else
                echo -e "\n[!] Uninstallation canceled."
                sleep 2
                zivpn_menu
            fi
            ;;
        0)
            exit 0
            ;;
        *)
            echo -e "\n[!] Invalid Option!"
            sleep 1
            zivpn_menu
            ;;
    esac
}

zivpn_menu
EOF

# Menu command ကို execute permission ပေးခြင်း
chmod +x /usr/bin/zivpn

clear
echo "=========================================="
echo "    ZIVPN UDP INSTALLATION COMPLETE!     "
echo "=========================================="
echo " Type 'zivpn' anywhere to open manager.   "
echo "=========================================="
