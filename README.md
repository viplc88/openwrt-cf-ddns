# Cloudflare DDNS for OpenWRT - Multi-Zone Support

Version 2.0

## Features
- Multiple domains across different Cloudflare zones
- Each domain can use different WAN interface
- Smart caching per domain
- Detailed logging

## Quick Start

1. Upload files to OpenWRT:
   ```
   scp * root@192.168.1.1:/tmp/
   ```

2. Install:
   ```
   ssh root@192.168.1.1
   cd /tmp
   sh install.sh
   ```

3. Configure:
   ```
   vi /etc/cloudflare-ddns/cloudflare-ddns.conf
   ```

4. Get Record IDs:
   ```
   cloudflare-ddns --get-record-id
   ```

5. Test:
   ```
   cloudflare-ddns --force
   ```

## Configuration Example

```bash
DEFAULT_API_TOKEN="your_token"
DEFAULT_INTERFACE="wan"

CF_DOMAINS="domain1.com,domain2.com"
CF_ZONE_IDS="zone_id_1,zone_id_2"
CF_INTERFACES="wan,wanvnpt"
CF_RECORD_IDS="rec_id_1,rec_id_2"
```

## Commands

- `cloudflare-ddns` - Update DNS (if IP changed)
- `cloudflare-ddns --force` - Force update
- `cloudflare-ddns --status` - Show status
- `cloudflare-ddns --get-record-id` - Get Record IDs
- `cloudflare-ddns --help` - Show help

## License

MIT License
