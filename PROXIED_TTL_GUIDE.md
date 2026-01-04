# Hướng dẫn CF_PROXIED và CF_TTL

## CF_PROXIED

**true** = Proxy qua Cloudflare (🟠 Orange Cloud)
- ✅ Có CDN, DDoS protection, ẩn IP
- ❌ Chỉ cho HTTP/HTTPS, không dùng cho SSH/VPN/FTP/Game

**false** = Không proxy (⚪ Grey Cloud)
- ✅ Hiện IP thật, dùng cho mọi protocol
- ❌ Không có CDN, không ẩn IP

## Khi nào dùng true/false?

**TRUE (khuyên dùng cho):**
- Website, blog, web app
- API công khai
- Static site

**FALSE (khuyên dùng cho):**
- SSH server
- VPN server (OpenVPN, WireGuard)
- FTP/SFTP
- Mail server (SMTP)
- Game server
- API có whitelist IP

## CF_TTL (Time To Live)

TTL = Thời gian cache DNS (giây)

**Giá trị phổ biến:**
- 120 = 2 phút (khuyên dùng cho IP động)
- 300 = 5 phút (cân bằng)
- 3600 = 1 giờ (IP tĩnh/VPS)

**TTL thấp (120-300s):**
- ✅ Update nhanh khi IP đổi
- ❌ Tốn DNS queries

**TTL cao (3600s):**
- ✅ Giảm DNS queries
- ❌ Update chậm khi IP đổi

## Ví dụ

```bash
# Web chính → Proxy, TTL thấp
# VPN → Không proxy, TTL trung bình
# API → Không proxy, TTL cao

CF_DOMAINS="web.com,vpn.web.com,api.web.com"
CF_PROXIED="true,false,false"
CF_TTL="120,300,3600"
```

Xem full guide tại artifact "PROXIED_TTL_GUIDE.md"
