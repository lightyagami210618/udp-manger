#!/bin/bash

# ၁။ Root User ဟုတ်/မဟုတ် စစ်ဆေးခြင်း
if [ "$EUID" -ne 0 ]; then
  echo "Error: Please run as root user!"
  exit 1
fi

clear
echo "=========================================="
echo "    STARTING UDP CUSTOM AUTO INSTALLER    "
echo "=========================================="
sleep 2

# ၂။ လိုအပ်သည့် Packages များကို Install တင်ခြင်း
echo "[1/4] Installing dependencies..."
apt-get update -y
apt-get install -y curl wget jq net-tools iptables

# ၃။ Directory ပြုလုပ်ခြင်းနှင့် Binary/Config ထည့်သွင်းခြင်း
echo "[2/4] Setting up UDP Custom binaries..."
mkdir -p /root/udp

# Config.json အလွတ်တစ်ခု ဖန်တီးခြင်း
cat <<EOF > /root/udp/config.json
{
  "listen": ":7300",
  "stream_buffer": 32768,
  "receive_buffer": 32768,
  "auth": {
    "users": []
  }
}
EOF

# UDP Custom Binary ကို ဒေါင်းလုဒ်ဆွဲခြင်း (မိမိ၏ Direct Download Link ထည့်ရန်)
# wget -O /root/udp/udp-custom https://example.com/udp-custom
# chmod +x /root/udp/udp-custom

# ၄။ Background Service (Systemd) ပြုလုပ်ခြင်း
echo "[3/4] Creating Systemd Service..."
cat <<EOF > /etc/systemd/system/udp-custom.service
[Unit]
Description=UDP Custom Server Service
After=network.target

[Service]
User=root
WorkingDirectory=/root/udp
ExecStart=/root/udp/udp-custom server
Restart=always

[Install]
WantedBy=multi-user.target
EOF

systemctl daemon-reload
systemctl enable udp-custom

# ၅။ Terminal မှ 'udp' ဟု ရိုက်လျှင် ခေါ်သုံးနိုင်မည့် Manager Script ဖန်တီးခြင်း
echo "[4/4] Setting up Manager Menu command..."
cat <<'EOF' > /usr/bin/udp
#!/bin/bash

CONFIG_FILE="/root/udp/config.json"

udp_menu() {
    clear
    echo "=================================="
    echo "     UDP CUSTOM MANAGER PANEL     "
    echo "=================================="
    echo "[1] Add UDP Account"
    echo "[2] Delete UDP Account"
    echo "[3] Show Active Accounts"
    echo "[0] Exit"
    echo "=================================="
    read -p "Choose option: " opt

    case $opt in
        1)
            read -p "Enter Username: " uname
            read -p "Enter Password: " upass
            jq --arg user "$uname:$upass" '.auth.users += [$user]' "$CONFIG_FILE" > /tmp/cfg.json && mv /tmp/cfg.json "$CONFIG_FILE"
            systemctl restart udp-custom
            echo -e "\nAccount $uname created successfully!"
            sleep 2
            udp_menu
            ;;
        2)
            read -p "Enter Username to Delete: " uname
            read -p "Enter Password: " upass
            jq --arg user "$uname:$upass" '.auth.users -= [$user]' "$CONFIG_FILE" > /tmp/cfg.json && mv /tmp/cfg.json "$CONFIG_FILE"
            systemctl restart udp-custom
            echo -e "\nAccount $uname deleted!"
            sleep 2
            udp_menu
            ;;
        3)
            echo -e "\n--- Current Users ---"
            jq '.auth.users[]' "$CONFIG_FILE"
            read -p "Press Enter to return..."
            udp_menu
            ;;
        0)
            exit 0
            ;;
        *)
            echo "Invalid Option!"
            sleep 1
            udp_menu
            ;;
    esac
}

udp_menu
EOF

# Menu command ကို run ခွင့်ပေးခြင်း
chmod +x /usr/bin/udp

clear
echo "=========================================="
echo "    INSTALLATION SUCCESSFUL!             "
echo "=========================================="
echo " Type 'udp' anywhere in terminal to start."
echo "=========================================="
