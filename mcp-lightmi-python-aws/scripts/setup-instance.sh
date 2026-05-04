#!/bin/bash
# setup-instance.sh - Initial setup for Lightsail Managed Instance

# Detect package manager
if command -v dnf &> /dev/null; then
    PKM="dnf"
elif command -v apt-get &> /dev/null; then
    PKM="apt"
else
    echo "Unknown package manager"
    exit 1
fi

echo "Detected package manager: $PKM"

if [ "$PKM" == "dnf" ]; then
    dnf update -y
    dnf install -y python3-pip rsync tar
elif [ "$PKM" == "apt" ]; then
    apt-get update -y
    apt-get install -y python3-pip python3-venv rsync tar
fi

# Create application directory
# Create application directory
# On Debian/Ubuntu the default user is 'admin' or 'debian', on AL2023 it is 'ec2-user'
if id "admin" &>/dev/null; then
    APP_USER="admin"
elif id "debian" &>/dev/null; then
    APP_USER="debian"
elif id "ec2-user" &>/dev/null; then
    APP_USER="ec2-user"
else
    APP_USER="root"
fi

echo "Using application user: $APP_USER"
mkdir -p /opt/mcp-server
chown $APP_USER:$APP_USER /opt/mcp-server

# Pre-configure systemd service
cat <<EOF > /etc/systemd/system/mcp-server.service
[Unit]
Description=MCP Python Server
After=network.target

[Service]
User=$APP_USER
WorkingDirectory=/opt/mcp-server
ExecStart=/usr/bin/python3 main.py
Restart=always
Environment=PORT=8080

[Install]
WantedBy=multi-user.target
EOF


systemctl daemon-reload
systemctl enable mcp-server.service
