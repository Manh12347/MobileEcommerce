# API Documentation - Mobile Ecommerce Backend

## 📋 Mục lục
1. [Thông tin chung](#thông-tin-chung)
2. [Authentication APIs](#authentication-apis)
3. [Cấu trúc response](#cấu-trúc-response)
4. [Error Handling](#error-handling)

---

## 🌐 Thông tin chung

**Base URL**: `http://your-server:5000`

**API Version**: `v1`

**Authentication**: Token-based (to be implemented)

---

## 🔐 Authentication APIs

### OTP Service (xác thực qua email)

#### 1. Gửi OTP
- **Endpoint**: `POST /v1/api/auth/otp/send`
- **Description**: Gửi mã OTP tới email người dùng
- **Request Body**:
```json
{
  "email": "user@example.com"
}
```
- **Success Response** (200 OK):
```json
{
  "message": "Mã OTP đã được gửi đến email",
  "success": true
}
```
- **Error Response** (400 Bad Request):
```json
{
  "message": "Lỗi gửi OTP: [chi tiết lỗi]",
  "success": false
}
```

---

#### 2. Xác thực OTP
- **Endpoint**: `POST /v1/api/auth/otp/verify`
- **Description**: Xác thực mã OTP đã gửi
- **Request Body**:
```json
{
  "email": "user@example.com",
  "otp": "123456"
}
```
- **Success Response** (200 OK):
```json
{
  "message": "Xác thực OTP thành công",
  "success": true
}
```
- **Error Response** (400 Bad Request):
```json
{
  "message": "OTP không hợp lệ hoặc đã hết hạn",
  "success": false
}
```

---

## 📦 Cấu trúc Response

### Success Response Format
```json
{
  "message": "Mô tả kết quả",
  "success": true,
  "data": {}  // Tùy chọn - chứa dữ liệu response
}
```

### Error Response Format
```json
{
  "message": "Mô tả lỗi",
  "success": false,
  "errorCode": "ERROR_CODE"  // Tùy chọn
}
```

---

## 🚨 Error Handling

| HTTP Status | Error Type | Mô tả |
|---|---|---|
| 200 OK | Success | Request thành công |
| 400 Bad Request | Validation Error | Dữ liệu request không hợp lệ |
| 401 Unauthorized | Authentication Error | Token không hợp lệ hoặc không tồn tại |
| 403 Forbidden | Authorization Error | Người dùng không có quyền |
| 404 Not Found | Resource Error | Resource không tồn tại |
| 500 Internal Server Error | Server Error | Lỗi server |

---

## 📝 Cấu trúc Project Backend

```
Backend/
├── src/main/java/com/example/ecommerce/
│   ├── EcommerceApplication.java          # Main Spring Boot app
│   │
│   ├── config/                             # Configuration layer
│   │   ├── DotenvConfig.java              # Load .env variables
│   │   ├── SwaggerConfig.java             # Swagger/OpenAPI config
│   │   └── EnvironmentListener.java       # Environment setup
│   │
│   ├── controller/                         # REST API Endpoints
│   │   ├── OtpController.java             # Auth - OTP endpoints
│   │   └── TestController.java            # Test endpoints
│   │
│   ├── entity/                             # JPA Entities (Database Models)
│   │   ├── Account.java                   # User account
│   │   ├── Product.java                   # Product info
│   │   ├── Order.java                     # Order info
│   │   ├── Category.java                  # Product category
│   │   ├── Brand.java                     # Product brand
│   │   ├── Promotion.java                 # Promotional campaigns
│   │   └── ... (xem file)
│   │
│   ├── repository/                         # Data Access Layer (Spring Data JPA)
│   │   ├── AccountRepository.java
│   │   ├── ProductRepository.java
│   │   ├── OrderRepository.java
│   │   └── ... (JPA Repositories)
│   │
│   ├── service/                            # Business Logic Layer
│   │   ├── OtpService.java                # OTP generation & verification
│   │   ├── MailService.java               # Email sending
│   │   └── ... (Business logic)
│   │
│   └── util/                               # Utility Classes
│       └── OtpUtil.java                   # OTP utilities
│
├── resources/
│   └── application.properties              # Spring Boot configuration
│
└── test/
    └── DemoApplicationTests.java           # Unit tests
```

---

## 🔗 API Endpoints Summary

### Authentication
- `POST /v1/api/auth/otp/send` - Send OTP to email
- `POST /v1/api/auth/otp/verify` - Verify OTP code

### Coming Soon
- Product APIs
- Order APIs
- User Profile APIs
- Payment APIs

---

## 🚀 Swagger UI

View interactive API documentation at:
```
http://your-server:5000/swagger-ui/index.html
```

---

## 📞 Support

For issues or questions about APIs, check:
1. Swagger UI documentation
2. This API documentation
3. Check logs: `sudo journalctl -u ecommerce-backend -f`
