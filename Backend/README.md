# Backend

Đây là backend của dự án MobileEcommerce, được xây dựng bằng Spring Boot.

## Yêu cầu

- Java 21
- PostgreSQL 17
- Extension `pgvector`
- Gradle Wrapper đã có sẵn trong dự án

## Cài đặt

Mở terminal tại thư mục `Backend`, sau đó chạy:

```bash
./gradlew build
```

Nếu dùng Windows PowerShell hoặc CMD, có thể chạy:

```bat
gradlew.bat build
```

## Cấu hình môi trường

Backend đọc các biến môi trường từ file `.env` hoặc từ môi trường hệ thống. Tối thiểu cần chuẩn bị các giá trị sau:

```env
SPRING_DATASOURCE_URL=jdbc:postgresql://localhost:5432/ten_database
SPRING_DATASOURCE_USERNAME=postgres
SPRING_DATASOURCE_PASSWORD=mat_khau_cua_ban
SPRING_MAIL_USERNAME=your_email@gmail.com
SPRING_MAIL_PASSWORD=your_gmail_app_password
SEPAY_ACCOUNT_NUMBER=your_account_number
HOOKS_API_KEY=your_hooks_key
RECAPTCHA_SITE_KEY=your_recaptcha_site_key
RECAPTCHA_SECRET_KEY=your_recaptcha_secret_key
REDIS_HOST=localhost
REDIS_PORT=6379
REDIS_PASSWORD=
GENAI_API_EMBED=your_embed_key
GENAI_API_DECISION=your_decision_key
GENAI_API_CHAT=your_chat_key
```

## Database

File `Database.sql` chứa toàn bộ schema của hệ thống. Trước khi chạy backend, hãy import file này vào PostgreSQL và đảm bảo extension `vector` đã được bật.

## Chạy ứng dụng

Sau khi cài dependency và cấu hình xong database, chạy:

```bash
./gradlew bootRun
```

Trên Windows:

```bat
gradlew.bat bootRun
```

Backend mặc định chạy ở:

- `http://localhost:5000`
- Swagger UI: `http://localhost:5000/swagger-ui/index.html`
- Health check: `http://localhost:5000/actuator/health`

## Build file JAR

Nếu muốn tạo file chạy độc lập:

```bash
./gradlew clean bootJar
```

File JAR sẽ được tạo với tên `app.jar` trong thư mục build.

## Ghi chú

- Điểm vào ứng dụng là `src/main/java/com/example/ecommerce/EcommerceApplication.java`.
- Backend có kết nối tới service Python qua `app.pythonApiUrl` trong `src/main/resources/application.properties`.
- Nếu triển khai lên server mới, nhớ cấu hình lại domain, mail, Redis, Recaptcha và các khóa API cần thiết.
