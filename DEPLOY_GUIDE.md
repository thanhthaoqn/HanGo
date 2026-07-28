# Hướng Dẫn Triển Khai: Dự Án HanGo (AWS EC2 & GoDaddy)

Tài liệu này hướng dẫn chi tiết các bước từ cấu hình DNS tên miền, thiết lập AWS EC2, đóng gói và tải dữ liệu lên server, cho đến việc thiết lập **CI/CD tự động bằng GitHub Actions** để tự động triển khai mỗi khi đẩy code lên nhánh `dev` hoặc `main`.

---

## 📋 Tóm Tắt Sơ Đồ Hệ Thống Triển Khai
```
                        [ HTTPS: Port 443 ]
                                │
                                ▼
                       ┌─────────────────┐
                       │   Nginx Proxy   │ (hango-nginx)
                       └────────+────────┘
                                │
               ┌────────────────┴────────────────┐
               ▼ (Port 80)                       ▼ (Port 8080)
      ┌─────────────────┐               ┌─────────────────┐
      │   Frontend App  │ (Flutter Web) │   Backend App   │ (Spring Boot JAR)
      │ (hango-frontend)│               │ (hango-backend) │
      └─────────────────┘               └────────+────────┘
                                                 │
                                                 ▼
                                        ┌─────────────────┐
                                        │  MySQL Database │ (Aiven Cloud)
                                        └─────────────────┘
```

- **Tên miền:** `hangog92.online` (và `www.hangog92.online`) -> Chạy ứng dụng Flutter Web.
- **Tên miền phụ (Subdomain):** `api.hangog92.online` -> Chạy API Spring Boot.
- **Database:** Kết nối trực tiếp từ Backend tới Cloud MySQL (Aiven) đã cấu hình.

---

## 🌐 PHẦN 1: Cấu Hình DNS (GoDaddy & AWS Route 53)

Bạn có hai cách để cấu hình DNS:
* **Cách 1 (Đơn giản nhất):** Cấu hình các bản ghi DNS trực tiếp trên giao diện của GoDaddy.
* **Cách 2 (Khuyên dùng cho hạ tầng AWS):** Ủy quyền quản lý DNS từ GoDaddy sang **Amazon Route 53**.

### Cách 1: Cấu hình DNS trực tiếp trên GoDaddy
Đăng nhập vào trang quản trị DNS của GoDaddy cho tên miền `hangog92.online` và tạo/chỉnh sửa các bản ghi (Records) như sau:
- **Bản ghi A:** `@` trỏ về `IP_PUBLIC_CỦA_EC2`
- **Bản ghi A:** `api` trỏ về `IP_PUBLIC_CỦA_EC2`
- **Bản ghi CNAME:** `www` trỏ về `@`

### Cách 2: Ủy quyền quản lý DNS sang Amazon Route 53
1. **Tạo Hosted Zone trên AWS Route 53:**
   - Truy cập **AWS Console** -> Tìm dịch vụ **Route 53**.
   - Tạo Hosted Zone với tên miền: `hangog92.online` (Public Hosted Zone).
2. **Thay đổi Name Servers trên GoDaddy:**
   - Copy 4 địa chỉ máy chủ phân giải tên miền (NS) được tạo trong Route 53.
   - Đăng nhập GoDaddy, thay thế Name Servers mặc định bằng 4 địa chỉ NS của Route 53 này.
3. **Tạo các bản ghi định tuyến trên Route 53:**
   - Tạo bản ghi **A** cho `@` trỏ về `IP_PUBLIC_CỦA_EC2`.
   - Tạo bản ghi **A** cho `api` trỏ về `IP_PUBLIC_CỦA_EC2`.
   - Tạo bản ghi **CNAME** cho `www` trỏ về `hangog92.online`.

---

## ☁️ PHẦN 2: Thiết Lập Máy Chủ AWS EC2

1. **Tạo Instance:**
   - Hệ điều hành: `Ubuntu Server 24.04 LTS`.
   - Instance Type: `t3.micro` hoặc `t3.small`.
   - Tải file khóa `.pem` (Keypair) về máy để kết nối SSH.
2. **Cấu hình Security Group (Mở Port):**
   - Mở cổng **22 (SSH)** để quản trị.
   - Mở cổng **80 (HTTP)** và **443 (HTTPS)** cho truy cập bên ngoài.

---

## 📦 PHẦN 3: Cài Đặt Docker & Khởi Tạo Trên EC2

SSH vào máy chủ EC2:
```bash
ssh -i "duong/dan/toi/keypair.pem" ubuntu@<IP_PUBLIC_CỦA_EC2>
```

Chạy các lệnh sau để cài đặt Docker và chuẩn bị môi trường:
```bash
# 1. Cập nhật hệ thống
sudo apt update && sudo apt upgrade -y

# 2. Cài đặt Docker
sudo apt install docker.io -y
sudo systemctl enable --now docker

# 3. Cài đặt Docker Compose
sudo curl -L "https://github.com/docker/compose/releases/download/v2.24.5/docker-compose-$(uname -s)-$(uname -m)" -o /usr/local/bin/docker-compose
sudo chmod +x /usr/local/bin/docker-compose

# 4. Phân quyền chạy Docker
sudo usermod -aG docker $USER
newgrp docker

# 5. Tạo thư mục chứa code
mkdir -p ~/hango/nginx/conf.d
mkdir -p ~/hango/hango-backend/target
mkdir -p ~/hango/hango-frontend/build
```

---

## 🔑 PHẦN 4: Thiết Lập Cấu Hình File `.env` Trên EC2
Để cấu hình bảo mật thông tin nhạy cảm của cổng thanh toán PayOS, hãy chạy lệnh sau trên EC2 để tạo file `.env`:

```bash
cat << 'EOF' > ~/hango/.env
PAYOS_CLIENT_ID=YOUR_PAYOS_CLIENT_ID
PAYOS_API_KEY=YOUR_PAYOS_API_KEY
PAYOS_CHECKSUM_KEY=YOUR_PAYOS_CHECKSUM_KEY
EOF

# Khóa quyền truy cập file .env chỉ cho riêng user ubuntu
chmod 600 ~/hango/.env
```

> ⚠️ **Không bao giờ commit giá trị thật của các biến trên vào Git** (kể cả trong tài liệu). Lấy giá trị thật từ PayOS Merchant Dashboard và dán trực tiếp trên server khi chạy lệnh này, không lưu lại trong bất kỳ file nào được track bởi git. Nếu bạn tìm thấy giá trị thật đã từng bị commit (kể cả trong lịch sử git cũ), hãy coi như đã bị lộ và rotate lại key ngay trên PayOS Dashboard.

---

## 🤖 PHẦN 5: Triển Khai Tự Động Với CI/CD GitHub Actions

Với cấu hình CI/CD đã thiết lập, bạn chỉ cần cấu hình khóa SSH trên GitHub một lần duy nhất. Sau đó, mỗi khi có bất kỳ thành viên nào `git push` code lên nhánh `dev`, hệ thống sẽ tự động build và deploy lên EC2.

### Bước 1: Thêm khóa SSH vào GitHub Secrets
1. Đăng nhập vào GitHub -> Đi tới Repository dự án của bạn.
2. Chọn **Settings** -> **Secrets and variables** -> **Actions** -> Click **New repository secret**.
3. **Name:** `EC2_SSH_KEY`
4. **Value:** Mở file khóa `hango-keypair.pem` của bạn ở máy local ra, copy toàn bộ nội dung của nó và dán vào -> Click **Add secret**.

### Bước 2: Đẩy cấu hình lên GitHub
Khi bạn đẩy code có chứa thư mục cấu hình `.github/workflows/deploy.yml` lên nhánh `dev`, GitHub Actions sẽ tự động:
1. Tạo môi trường ảo JDK 21 để build dự án Spring Boot thành file JAR.
2. Tạo môi trường Flutter để build dự án Web thành thư mục tĩnh.
3. Nén tất cả bản build và cấu hình Docker thành file `deploy.zip`.
4. Dùng SCP để đẩy file lên EC2 và giải nén.
5. Khởi chạy cập nhật dự án trên Docker mà không gây gián đoạn dịch vụ.

---

## 🔐 PHẦN 6: Đăng Ký Chứng Chỉ SSL (HTTPS) Đầu Lần

*Do hệ thống SSL yêu cầu sinh chứng chỉ Let's Encrypt trên server, bạn chỉ cần thực hiện việc này một lần đầu tiên khi dựng server:*

1. **Dừng Nginx tạm thời trên EC2:**
   ```bash
   docker-compose stop nginx
   ```
2. **Cài đặt Certbot trực tiếp trên EC2:**
   ```bash
   sudo apt update && sudo apt install certbot -y
   ```
3. **Sinh chứng chỉ SSL:**
   ```bash
   sudo certbot certonly --standalone -d hangog92.online -d www.hangog92.online -d api.hangog92.online --email hangog92su26@gmail.com --agree-tos --no-eff-email
   ```
4. **Copy chứng chỉ vào thư mục chia sẻ của Docker:**
   ```bash
   sudo cp -L -r /etc/letsencrypt/* ~/hango/nginx/certbot/conf/
   ```
5. **Khởi chạy lại Nginx:**
   ```bash
   docker-compose start nginx
   ```
6. **Kiểm tra trạng thái:** Truy cập `https://hangog92.online` trên trình duyệt để tận hưởng kết quả bảo mật HTTPS!
