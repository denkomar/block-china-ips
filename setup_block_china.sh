#!/bin/bash

function info {
    echo -e "\e[32m[INFO]\e[0m $1"
}

function error {
    echo -e "\e[31m[ERROR]\e[0m $1"
}

info "Starting setup of China IP blocking..."
info "Updating package lists..."
apt-get update -y
info "Installing required packages..."
apt-get install -y ufw ipset iptables-persistent wget

info "Creating setup script for IPSet and IPTables..."
cat << 'EOF' > /usr/local/bin/setup_china_ipset.sh
#!/bin/bash

IPSET_NAME="china"
IPSET_TMP="/tmp/china.zone"

function info {
    echo -e "\e[32m[INFO]\e[0m $1"
}

function error {
    echo -e "\e[31m[ERROR]\e[0m $1"
}

info "Creating IPSet named $IPSET_NAME..."
ipset create $IPSET_NAME hash:net

info "Downloading China IP list..."
wget -q -O $IPSET_TMP http://www.ipdeny.com/ipblocks/data/countries/cn.zone

if [ -s $IPSET_TMP ]; then
  info "Adding IP addresses to IPSet..."
  while read -r ip; do
    ipset add $IPSET_NAME $ip
  done < $IPSET_TMP
else
  error "Failed to download IP list"
  exit 1
fi

info "Adding IPSet rule to IPTables..."
iptables -I INPUT -m set --match-set $IPSET_NAME src -j DROP
EOF

info "Making setup script executable..."
chmod +x /usr/local/bin/setup_china_ipset.sh

info "Creating systemd service for IPSet and IPTables setup..."
cat << 'EOF' > /etc/systemd/system/setup_china_ipset.service
[Unit]
Description=Setup China IPSet and IPTables
After=network.target

[Service]
ExecStart=/usr/local/bin/setup_china_ipset.sh
Type=oneshot
RemainAfterExit=true

[Install]
WantedBy=multi-user.target
EOF

info "Reloading systemd daemon and enabling service..."
systemctl daemon-reload
systemctl enable setup_china_ipset.service

info "Creating script for updating China IPSet..."
cat << 'EOF' > /usr/local/bin/update_china_ipset.sh
#!/bin/bash

IPSET_NAME="china"
IPSET_TMP="/tmp/china.zone"

function info {
    echo -e "\e[32m[INFO]\e[0m $1"
}

function error {
    echo -e "\e[31m[ERROR]\e[0m $1"
}

info "Downloading updated China IP list..."
wget -q -O $IPSET_TMP http://www.ipdeny.com/ipblocks/data/countries/cn.zone

if [ -s $IPSET_TMP ]; then
  info "Flushing old IP addresses from IPSet..."
  ipset flush $IPSET_NAME
  info "Adding new IP addresses to IPSet..."
  while read -r ip; do
    ipset add $IPSET_NAME $ip
  done < $IPSET_TMP
else
  error "Failed to download IP list"
  exit 1
fi
EOF

info "Making update script executable..."
chmod +x /usr/local/bin/update_china_ipset.sh

info "Adding cron job for updating China IPSet..."
(crontab -l ; echo "0 2 * * * /usr/local/bin/update_china_ipset.sh") | crontab -

info "Running initial setup script..."
/usr/local/bin/setup_china_ipset.sh

info "Setup complete. China IP blocking is now enabled."

