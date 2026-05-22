# Python Backend

Đây là service Python của dự án MobileEcommerce, xây dựng bằng FastAPI.

## Yêu cầu

- Python 3.10+.
- Có quyền truy cập PostgreSQL.
- File cấu hình `Backend/.env` phải tồn tại trước khi chạy.

## Cài đặt

Mở terminal tại thư mục gốc của dự án, sau đó chạy:

```bash
cd Python
python -m venv .venv
```

Kích hoạt môi trường ảo:

```bash
.venv\Scripts\activate
```

Nếu dùng PowerShell:

```powershell
.venv\Scripts\Activate.ps1
```

Sau đó cài thư viện:

```bash
pip install -r requirements.txt
```

## Cấu hình môi trường

Ứng dụng đọc biến môi trường từ `Backend/.env`. Tối thiểu cần có:

```env
SPRING_DATASOURCE_URL=jdbc:postgresql://localhost:5432/ten_database
SPRING_DATASOURCE_USERNAME=postgres
SPRING_DATASOURCE_PASSWORD=mat_khau_cua_ban
```

## Chạy ứng dụng

Trong thư mục `Python`, chạy:

```bash
uvicorn app.main:app --reload --host 0.0.0.0 --port 8000
```

Sau khi chạy xong, API sẽ sẵn sàng tại:

- `http://localhost:8000`
- `http://localhost:8000/health`

## Ghi chú

- Nếu bạn đang chạy trên Linux server, có thể tham khảo `app/start.sh`.
- Khi cập nhật code, chỉ cần lưu file và để `--reload` tự nạp lại.
