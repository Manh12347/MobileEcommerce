# Hướng dẫn cấu hình Environment Variables

## Tổng quan

Dự án đã được cấu hình để sử dụng file `.env` cho tất cả các thông tin nhạy cảm như:
- Database connection strings
- Email settings
- Banking configuration
- Webhook configuration
- Application domain

## Các bước thiết lập

### 1. Tạo file .env

Sao chép file `.env.example` thành `.env` và điền thông tin thực tế:

```bash
cp .env.example .env
```

### 2. Cấu hình các biến môi trường

Mở file `.env` và cập nhật các giá trị:

```env
# Database Configuration
DB_HOST=your-db-host
DB_DATABASE=your-database-name
DB_USERNAME=your-db-username
DB_PASSWORD=your-db-password

# Email Configuration
EMAIL_SMTP_SERVER=smtp.gmail.com
EMAIL_SMTP_PORT=587
EMAIL_SENDER_EMAIL=your-email@gmail.com
EMAIL_SENDER_NAME=PTVBTPM
EMAIL_APP_PASSWORD=your-app-password
EMAIL_ENABLE_SSL=true

# Banking Configuration (Sepay)
SEPAY_ACCOUNT_NUMBER=your-account-number
SEPAY_BANK_NAME=your-bank-name

# Webhook Configuration
HOOKS_API_KEY=your-webhook-api-key
HOOKS_ORDER_ID_PATTERN=ORDER_
HOOKS_AMOUNT_TOLERANCE=0

# Application Domain
APP_DOMAIN=your-domain.com
```

### 3. Đảm bảo .env không được commit

File `.env` đã được thêm vào `.gitignore`, nên sẽ không bị commit lên Git.

### 4. Cấu hình GitHub Secrets (cho CI/CD)

Để deploy tự động qua GitHub Actions, bạn cần thêm các secrets vào GitHub Repository:

1. Vào **Settings** > **Secrets and variables** > **Actions**
2. Thêm các secrets tương ứng với các biến trong `.env`

Xem chi tiết trong file `.github/SECRETS.md`

## Cách hoạt động

1. **Local Development**: 
   - File `.env` được load tự động khi chạy ứng dụng
   - `Program.cs` sẽ đọc các biến môi trường và override cấu hình từ `appsettings.json`

2. **Production (GitHub Actions)**:
   - GitHub Actions sẽ tạo file `.env` trên server từ các secrets
   - Ứng dụng sẽ đọc file `.env` này khi chạy

## Lưu ý

- **KHÔNG BAO GIỜ** commit file `.env` lên Git
- File `.env.example` có thể được commit để làm mẫu
- Luôn sử dụng GitHub Secrets cho các thông tin nhạy cảm trong CI/CD

