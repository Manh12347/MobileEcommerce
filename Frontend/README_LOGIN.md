# TechShop Mobile App - Login Feature

## 📱 Tính năng

Giao diện đăng nhập hoàn chỉnh với:
- ✅ Form validation (email, password)
- ✅ Integration với Backend API
- ✅ Loading state và error handling
- ✅ UI giống thiết kế TechShop
- ✅ Toggle show/hide password
- ✅ OTP login option
- ✅ Forgot password link
- ✅ Register link

## 📂 Cấu trúc Project

```
lib/
├── config/
│   └── api_config.dart          # Cấu hình API URL
├── models/
│   ├── login_request.dart       # Request model
│   └── login_response.dart      # Response model
├── providers/
│   └── login_provider.dart      # State management
├── screens/
│   └── login_screen.dart        # UI Giao diện đăng nhập
├── services/
│   └── api_service.dart         # API calls
└── main.dart                    # Entry point
```

## 🔧 Cấu hình

### 1. Cập nhật API URL

Mở file `lib/config/api_config.dart` và thay đổi:

```dart
// Production server
const String API_BASE_URL = 'https://doantrang.online/v1/api';

// Nếu chạy local backend, đổi sang:
// const String API_BASE_URL = 'http://localhost:5000/v1/api';
```

### 2. Chạy ứng dụng

```bash
# Development
flutter run

# Release
flutter build apk  # Android
flutter build ios  # iOS
```

## 🚀 API Integration

### Login Endpoint

**URL:** `POST /v1/api/auth/login`

**Request Body:**
```json
{
  "email": "user@domain.com",
  "password": "password123"
}
```

**Response (Success):**
```json
{
  "success": true,
  "message": "Đăng nhập thành công",
  "data": {
    "token": "jwt_token_here",
    "accountId": "account_id",
    "email": "user@domain.com"
  }
}
```

**Response (Error):**
```json
{
  "success": false,
  "message": "Email hoặc mật khẩu không chính xác",
  "data": null
}
```

## ⚙️ Backend Requirements

Backend cần hỗ trợ:

1. ✅ CORS (Cross-Origin Resource Sharing)
2. ✅ Login endpoint tại `/v1/api/auth/login`
3. ✅ Email và Password validation
4. ✅ Response format theo định dạng ApiResponse

## 📋 Validation Rules

- **Email:** Phải là email hợp lệ (có @)
- **Password:** Tối thiểu 6 ký tự

## 🔐 State Management

Sử dụng **Provider** package:
- `LoginProvider` quản lý: isLoading, errorMessage, loginResponse
- Tự động notify UI khi state thay đổi

## 🎨 UI Customization

Màu chính: `Color(0xFF1976D2)` (Blue)

Để thay đổi màu, sửa:
1. `main.dart` - `colorScheme`
2. `login_screen.dart` - `Color(0xFF1976D2)`

## 📝 TODO

Các tính năng cần implement:

- [ ] Navigate to Home screen sau khi login
- [ ] Forgot Password screen
- [ ] OTP Login screen
- [ ] Register screen
- [ ] Token storage (SharedPreferences)
- [ ] Token refresh logic
- [ ] Logout functionality
- [ ] Session management

## 🐛 Troubleshooting

### Lỗi: "Connection refused"
- Kiểm tra Backend server có đang chạy
- Kiểm tra URL trong `api_config.dart` có đúng không

### Lỗi: "Email hoặc mật khẩu không chính xác"
- Kiểm tra email/password có đúng không
- Kiểm tra tài khoản đã được activate chưa

### Lỗi: CORS error
- Kiểm tra Backend có enable CORS không
- Backend phải có `@CrossOrigin(origins = "*")`

## 📦 Dependencies

- `http: ^1.6.0` - HTTP client
- `provider: ^6.1.5` - State management

## 📞 Support

Nếu có lỗi, kiểm tra:
1. Backend API documentation
2. Network connectivity
3. API configuration
4. Flutter console errors
