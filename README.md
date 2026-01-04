# Cloudflare DDNS cho OpenWRT

**Multi-Zone + Multi-Interface Support**  
Version 2.0

Script DDNS cập nhật IP lên Cloudflare DNS cho OpenWRT. Hỗ trợ **nhiều domain ở nhiều Zone ID khác nhau**, mỗi domain có thể dùng interface và API token riêng!

## ✨ Tính năng

* 🌍 **Multi-Zone Support** - domain1.com (Zone A) và domain2.com (Zone B) cùng 1 script
* 🔄 **Multi-Domain** - Không giới hạn số lượng domain
* 🌐 **Multi-Interface** - Mỗi domain dùng WAN riêng (wan, wanvnpt, wanfpt...)
* 🔑 **Multi-Token** - Mỗi domain có thể dùng API token khác nhau
* 🟠 **Custom Proxied** - Mỗi domain có thể proxy qua Cloudflare CDN hoặc không
* ⏱️ **Custom TTL** - Mỗi domain có thể có TTL riêng (60s - 86400s)
* ⚡ **Smart Cache** - Cache riêng cho từng domain, chỉ update khi IP thay đổi
* 📊 **Detailed Logs** - Log chi tiết với summary
* ⏰ **Auto Cronjob** - Tự động chạy mỗi 5 phút

---

## 📦 Download & Cài đặt

### **Cách 1: Download từng file (Khuyên dùng)**

Click vào từng file và copy nội dung:

1. **cloudflare-ddns.sh** - Script chính
2. **cloudflare-ddns.conf** - File cấu hình
3. **install.sh** - Script cài đặt
4. **uninstall.sh** - Script gỡ cài đặt
5. **README.md** - Hướng dẫn này
6. **EXAMPLES.md** - Các ví dụ cấu hình

### **Cách 2: Tạo ZIP package (Nếu có Git)**

```bash
# Clone hoặc tạo thư mục
mkdir cloudflare-ddns-openwrt
cd cloudflare-ddns-openwrt

# Copy tất cả file vào thư mục này
# Sau đó chạy:
chmod +x package.sh
./package.sh

# Sẽ tạo file: cloudflare-ddns-openwrt-multizone-v2.0.zip
```

### **Cách 3: Upload trực tiếp lên OpenWRT**

```bash
# Upload từng file
scp cloudflare-ddns.sh root@192.168.1.1:/tmp/
scp cloudflare-ddns.conf root@192.168.1.1:/tmp/
scp install.sh root@192.168.1.1:/tmp/

# SSH vào OpenWRT
ssh root@192.168.1.1
cd /tmp
sh install.sh
```

---

## 🚀 Quick Start

### **Bước 1: Cài đặt**

```bash
# SSH vào OpenWRT
ssh root@192.168.1.1

# Upload và giải nén (nếu dùng ZIP)
cd /tmp
unzip cloudflare-ddns-openwrt-multizone-v2.0.zip

# Chạy installer
sh install.sh
```

### **Bước 2: Lấy thông tin Cloudflare**

#### **2.1 API Token:**
1. Vào https://dash.cloudflare.com/profile/api-tokens
2. **Create Token** → **Edit zone DNS**
3. **Permissions:** Zone.DNS.Edit
4. **Zone Resources:** Chọn zone cần access (hoặc All zones)
5. Copy token

#### **2.2 Zone ID:**
1. Cloudflare Dashboard → Chọn domain
2. Sidebar bên phải → **API** section
3. Copy **Zone ID**

**Lưu ý:** Mỗi domain khác nhau (domain1.com ≠ domain2.com) có Zone ID khác nhau!

### **Bước 3: Cấu hình**

```bash
vi /etc/cloudflare-ddns/cloudflare-ddns.conf
```

#### **Ví dụ: 2 zone khác nhau - domain1.com và domain2.com**

```bash
# ============ DEFAULT VALUES ============
DEFAULT_API_TOKEN="your_api_token_if_same_for_all"
DEFAULT_ZONE_ID=""  # Để trống vì mỗi domain khác zone
DEFAULT_INTERFACE="wan"

# ============ DOMAINS ============
CF_DOMAINS="domain1.com,sub.domain1.com,domain2.com,sub.domain2.com"

# ============ API TOKENS (Nếu dùng chung token) ============
CF_API_TOKENS=""  # Để trống để dùng DEFAULT_API_TOKEN
# Hoặc chỉ định riêng:
# CF_API_TOKENS="token1,token1,token2,token2"

# ============ ZONE IDS (BẮT BUỘC - MỖI DOMAIN KHÁC ZONE) ============
CF_ZONE_IDS="zone_id_domain1,zone_id_domain1,zone_id_domain2,zone_id_domain2"
#            ↑ domain1.com      ↑ sub.domain1  ↑ domain2.com    ↑ sub.domain2
#            (cùng zone 1)                      (cùng zone 2)

# ============ INTERFACES (Tùy chọn) ============
CF_INTERFACES="wan,wanvnpt,wan,wanfpt"
# domain1.com → wan, sub.domain1.com → wanvnpt
# domain2.com → wan, sub.domain2.com → wanfpt

# ============ RECORD IDS (Lấy sau) ============
CF_RECORD_IDS=""  # Sẽ điền sau khi chạy --get-record-id
```

### **Bước 4: Lấy Record ID**

```bash
cloudflare-ddns --get-record-id
```

**Output:**
```
=== Fetching all DNS records from Cloudflare ===
Fetching DNS records for Zone: domain1.com (ID: abc123...)
  Record: domain1.com | ID: rec_abc123 | IP: 1.2.3.4
  Record: sub.domain1.com | ID: rec_def456 | IP: 1.2.3.4

Fetching DNS records for Zone: domain2.com (ID: xyz789...)
  Record: domain2.com | ID: rec_xyz789 | IP: 5.6.7.8
  Record: sub.domain2.com | ID: rec_uvw012 | IP: 5.6.7.8
```

Copy các Record ID và điền vào config:
```bash
CF_RECORD_IDS="rec_abc123,rec_def456,rec_xyz789,rec_uvw012"
```

### **Bước 5: Test**

```bash
# Xem status
cloudflare-ddns --status

# Force update
cloudflare-ddns --force

# Xem log
cat /tmp/cf_ddns.log
```

---

## 📖 Các trường hợp sử dụng

### **Case 1: Đơn giản - Tất cả domain cùng zone**

```bash
# Tất cả domain là subdomain của example.com
CF_DOMAINS="example.com,www.example.com,api.example.com"
CF_API_TOKENS=""              # Dùng DEFAULT_API_TOKEN
CF_ZONE_IDS=""                # Dùng DEFAULT_ZONE_ID (chỉ 1 zone)
CF_INTERFACES=""              # Dùng DEFAULT_INTERFACE (wan)
CF_RECORD_IDS="id1,id2,id3"   # Lấy từ --get-record-id

DEFAULT_API_TOKEN="your_token"
DEFAULT_ZONE_ID="zone_example_com"
DEFAULT_INTERFACE="wan"
```

### **Case 2: Nhiều zone - domain1.com và domain2.com**

```bash
# 2 domain hoàn toàn khác nhau = 2 zone khác nhau
CF_DOMAINS="domain1.com,domain2.com"
CF_ZONE_IDS="zone_domain1,zone_domain2"  # BẮT BUỘC khác nhau
CF_RECORD_IDS="rec_id1,rec_id2"

# Có thể dùng chung token nếu 1 account quản lý cả 2 domain
DEFAULT_API_TOKEN="your_token"
DEFAULT_INTERFACE="wan"
```

### **Case 3: Multi-WAN + Multi-Zone**

```bash
# domain1.com qua wan, domain2.com qua wanvnpt
CF_DOMAINS="domain1.com,domain2.com"
CF_ZONE_IDS="zone1,zone2"
CF_INTERFACES="wan,wanvnpt"
CF_RECORD_IDS="rec1,rec2"
```

### **Case 4: Mỗi domain hoàn toàn độc lập**

```bash
# 3 domain, 3 zone, 3 interface, 3 token
CF_DOMAINS="web.com,shop.net,blog.org"
CF_API_TOKENS="token1,token2,token3"
CF_ZONE_IDS="zone1,zone2,zone3"
CF_INTERFACES="wan,wanvnpt,wanfpt"
CF_RECORD_IDS="rec1,rec2,rec3"
```

### **Case 5: Custom Proxied + TTL**

```bash
# Web chính → Proxy qua Cloudflare (CDN), TTL thấp
# API server → Không proxy (cần IP thật), TTL cao
# VPN server → Không proxy (không hoạt động qua proxy), TTL trung bình

CF_DOMAINS="example.com,api.example.com,vpn.example.com"
CF_PROXIED="true,false,false"
CF_TTL="120,3600,300"
CF_RECORD_IDS="rec1,rec2,rec3"

DEFAULT_API_TOKEN="your_token"
DEFAULT_ZONE_ID="zone_example_com"
DEFAULT_INTERFACE="wan"
```

**Giải thích:**
- `example.com`: Proxy = true (có CDN, ẩn IP), TTL = 120s (update nhanh)
- `api.example.com`: Proxy = false (hiện IP thật cho API), TTL = 3600s (1 giờ, IP ổn định)
- `vpn.example.com`: Proxy = false (VPN không chạy qua proxy), TTL = 300s (5 phút)

**💡 Xem thêm:** [PROXIED_TTL_GUIDE.md](PROXIED_TTL_GUIDE.md) để hiểu rõ về Proxied và TTL

---

## 📋 Cấu trúc file

```
/usr/bin/cloudflare-ddns              # Script chính
/etc/cloudflare-ddns/
└── cloudflare-ddns.conf              # File cấu hình
/tmp/cf_ddns.log                      # Log file
/tmp/cf_ddns_ip_cache_domain1_com     # Cache cho domain1.com
/tmp/cf_ddns_ip_cache_domain2_com     # Cache cho domain2.com
```

---

## 🔍 Commands

```bash
# Update DNS (chỉ khi IP thay đổi)
cloudflare-ddns

# Force update tất cả domain
cloudflare-ddns --force

# Xem status của tất cả domain
cloudflare-ddns --status

# Lấy Record ID cho tất cả zone
cloudflare-ddns --get-record-id

# Help
cloudflare-ddns --help
```

---

## 📊 Log Output

### **Multi-Zone Update:**
```
[2025-01-04 10:00:00] === Starting Cloudflare DDNS Update (Multi-Zone + Multi-Interface) ===
[2025-01-04 10:00:00] Domain: domain1.com | Zone: abc123... | Interface: wan | Device: eth0 | IP: 1.2.3.4
[2025-01-04 10:00:01] UPDATE: domain1.com - IP: 1.2.3.4 (from wan)
[2025-01-04 10:00:02] SUCCESS: domain1.com updated to 1.2.3.4
[2025-01-04 10:00:02] Domain: domain2.com | Zone: xyz789... | Interface: wanvnpt | Device: eth3 | IP: 5.6.7.8
[2025-01-04 10:00:03] UPDATE: domain2.com - IP: 5.6.7.8 (from wanvnpt)
[2025-01-04 10:00:04] SUCCESS: domain2.com updated to 5.6.7.8
[2025-01-04 10:00:04] === Summary: Updated=2, Skipped=0, Failed=0 ===
```

**Chú ý:**
- domain1.com (Zone A) → IP 1.2.3.4 từ wan
- domain2.com (Zone B) → IP 5.6.7.8 từ wanvnpt
- **Khác zone = Khác IP có thể**

---

## 🔧 Troubleshooting

### **Lỗi: "Missing configuration for domain"**
```
ERROR: Missing configuration for domain.com (API Token/Zone ID/Record ID)
```
**Giải pháp:** Kiểm tra config có đầy đủ Zone ID và Record ID cho domain đó không

### **Lỗi: Zone ID sai**
Triệu chứng: Update failed với lỗi "Zone not found"

**Giải pháp:**
```bash
# Kiểm tra Zone ID đúng chưa
# Vào Cloudflare Dashboard của domain đó
# Xem Zone ID ở sidebar bên phải
```

### **Lỗi: Thứ tự không khớp**
Triệu chứng: domain1.com update vào zone của domain2.com

**Giải pháp:**
```bash
# Kiểm tra thứ tự
CF_DOMAINS="domain1.com,domain2.com"
CF_ZONE_IDS="zone1,zone2"  # Phải khớp!
#            ↑ zone1 cho domain1.com
#                    ↑ zone2 cho domain2.com
```

### **Test từng zone riêng**
```bash
# Xóa cache của domain cụ thể
rm /tmp/cf_ddns_ip_cache_domain1_com

# Test với --status để xem config
cloudflare-ddns --status

# Force update
cloudflare-ddns --force
```

---

## ❓ FAQ

### **Q: Khi nào cần dùng Multi-Zone?**
A: Khi bạn có **nhiều tên miền hoàn toàn khác nhau**:
- ✅ domain1.com và domain2.com → Cần Multi-Zone
- ❌ example.com và sub.example.com → KHÔNG cần (cùng zone)

### **Q: Làm sao biết 2 domain có cùng zone không?**
A: Nếu domain B là subdomain của domain A → Cùng zone
- example.com và www.example.com → Cùng zone
- example.com và another.com → Khác zone

### **Q: Có thể dùng 1 API token cho nhiều zone không?**
A: Được! Khi tạo API token, chọn "All zones" hoặc chọn nhiều zone cụ thể.

### **Q: Tôi có 10 domain, mỗi domain 1 zone, có nặng không?**
A: Không! Script chỉ gọi API khi IP thay đổi, có cache riêng cho từng domain.

### **Q: Có giới hạn số lượng domain/zone không?**
A: Không giới hạn trong script, nhưng cẩn thận với rate limit của Cloudflare API (1200 req/5min).

---

## 📄 License

MIT License - Sử dụng tự do cho mọi mục đích

---

## 🙏 Credits

Developed for OpenWRT community with ❤️

---

## 📮 Support

- **Issues:** Create GitHub issue
- **Docs:** Xem EXAMPLES.md cho các ví dụ chi tiết
- **Help:** Run `cloudflare-ddns --help`

---

**Happy DDNS! 🚀**
