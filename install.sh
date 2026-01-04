#!/bin/sh

echo "=================================="
echo "Cloudflare DDNS Installer"
echo "Multi-Zone Support Version 2.0"
echo "=================================="
echo ""

if [ "$(id -u)" != "0" ]; then
   echo "Error: This script must be run as root"
   exit 1
fi

if ! command -v curl >/dev/null 2>&1; then
    echo "Installing curl..."
    opkg update
    opkg install curl
fi

echo "Creating directories..."
mkdir -p /etc/cloudflare-ddns

echo "Installing main script..."
if [ -f "cloudflare-ddns.sh" ]; then
    cp cloudflare-ddns.sh /usr/bin/cloudflare-ddns
    chmod +x /usr/bin/cloudflare-ddns
    echo "✓ Script installed to /usr/bin/cloudflare-ddns"
else
    echo "✗ Error: cloudflare-ddns.sh not found!"
    exit 1
fi

echo "Installing configuration..."
if [ -f "cloudflare-ddns.conf" ]; then
    if [ -f "/etc/cloudflare-ddns/cloudflare-ddns.conf" ]; then
        echo "! Config file exists. Creating backup..."
        cp /etc/cloudflare-ddns/cloudflare-ddns.conf /etc/cloudflare-ddns/cloudflare-ddns.conf.backup
    fi
    cp cloudflare-ddns.conf /etc/cloudflare-ddns/cloudflare-ddns.conf
    echo "✓ Config installed"
else
    echo "✗ Warning: cloudflare-ddns.conf not found!"
fi

echo "Setting up cronjob..."
if grep -q "cloudflare-ddns" /etc/crontabs/root 2>/dev/null; then
    echo "! Cronjob already exists"
else
    echo "*/5 * * * * /usr/bin/cloudflare-ddns >/dev/null 2>&1" >> /etc/crontabs/root
    /etc/init.d/cron restart
    echo "✓ Cronjob added (runs every 5 minutes)"
fi

echo ""
echo "=================================="
echo "Installation completed!"
echo "=================================="
echo ""
echo "Next steps:"
echo "1. Edit config: vi /etc/cloudflare-ddns/cloudflare-ddns.conf"
echo "2. Get Record IDs: cloudflare-ddns --get-record-id"
echo "3. Test: cloudflare-ddns --force"
echo "4. Check status: cloudflare-ddns --status"
echo ""
