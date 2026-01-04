#!/bin/sh

echo "=================================="
echo "Cloudflare DDNS Uninstaller"
echo "=================================="
echo ""

if [ "$(id -u)" != "0" ]; then
   echo "Error: This script must be run as root"
   exit 1
fi

read -p "Are you sure? (y/N) " -n 1 -r
echo ""

if [[ ! $REPLY =~ ^[Yy]$ ]]; then
    echo "Uninstallation cancelled."
    exit 0
fi

echo "Removing files..."
rm -f /usr/bin/cloudflare-ddns
echo "✓ Removed script"

if [ -d "/etc/cloudflare-ddns" ]; then
    if [ -f "/etc/cloudflare-ddns/cloudflare-ddns.conf" ]; then
        cp /etc/cloudflare-ddns/cloudflare-ddns.conf /tmp/cloudflare-ddns.conf.backup
        echo "! Config backup: /tmp/cloudflare-ddns.conf.backup"
    fi
    rm -rf /etc/cloudflare-ddns
    echo "✓ Removed config"
fi

if grep -q "cloudflare-ddns" /etc/crontabs/root 2>/dev/null; then
    sed -i '/cloudflare-ddns/d' /etc/crontabs/root
    /etc/init.d/cron restart
    echo "✓ Removed cronjob"
fi

rm -f /tmp/cf_ddns.log
rm -f /tmp/cf_ddns_ip_cache_*
echo "✓ Removed cache and logs"

echo ""
echo "Uninstallation completed!"
echo ""
