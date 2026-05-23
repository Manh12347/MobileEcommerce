# Frontend

Đây là phần giao diện người dùng của dự án MobileEcommerce, được xây dựng bằng Flutter.

## Yêu cầu

- Flutter SDK tương thích với Dart `^3.11.1`.
- Android Studio, VS Code hoặc IDE có hỗ trợ Flutter.
- Thiết bị thật, emulator, hoặc trình duyệt web để chạy thử.

## Cài đặt

Mở terminal tại thư mục gốc của dự án, sau đó chạy:

```bash
cd Frontend
flutter pub get
```

## Chạy ứng dụng

Sau khi cài dependency, chạy:

```bash
flutter run
```

Nếu bạn muốn chọn thiết bị cụ thể, có thể kiểm tra danh sách thiết bị bằng:

```bash
flutter devices
```

Rồi chạy với device id tương ứng:

```bash
flutter run -d <device_id>
```

## Cấu hình API

Frontend đang gọi backend qua file `lib/config/api_config.dart`.

```dart
const String API_BASE_URL = 'https://doantrang.online/v1/api';
```

Nếu bạn chạy backend ở môi trường khác, hãy đổi giá trị này cho đúng địa chỉ API của bạn.

## Ghi chú

- Điểm vào của ứng dụng là `lib/main.dart`.
- Màn hình đầu tiên là `LoginScreen`.
- Nếu đổi backend, nhớ kiểm tra lại các request đăng nhập, đăng ký và OTP trong `lib/services/api_service.dart`.
