# Hướng dẫn cài đặt LibreOffice cho Document Preview

## Vấn đề
Backend cần LibreOffice để:
1. Convert file DOCX sang PDF
2. Extract trang từ PDF và convert sang PNG image để preview

## Cài đặt trên Windows (Development)

### Cách 1: Tải và cài đặt từ website chính thức
1. Truy cập: https://www.libreoffice.org/download/
2. Tải phiên bản mới nhất cho Windows
3. Chạy file installer và cài đặt
4. Mặc định sẽ cài vào: `C:\Program Files\LibreOffice\program\soffice.exe`

### Cách 2: Sử dụng Chocolatey (nếu đã cài)
```powershell
choco install libreoffice
```

### Cách 3: Sử dụng winget (Windows 10/11)
```powershell
winget install LibreOffice.LibreOffice
```

## Kiểm tra cài đặt

Sau khi cài đặt, kiểm tra bằng cách:
```powershell
# Kiểm tra đường dẫn
Test-Path "C:\Program Files\LibreOffice\program\soffice.exe"

# Hoặc chạy lệnh
& "C:\Program Files\LibreOffice\program\soffice.exe" --version
```

## Cài đặt trên Linux (Production Server)

### Ubuntu/Debian
```bash
sudo apt-get update
sudo apt-get install libreoffice
```

### CentOS/RHEL
```bash
sudo yum install libreoffice
# hoặc
sudo dnf install libreoffice
```

## Kiểm tra sau khi cài đặt

1. Khởi động lại backend server
2. Thử upload và preview một file DOCX hoặc PDF
3. Kiểm tra logs để xem LibreOffice có được tìm thấy không:
   - Tìm log: "Found LibreOffice at: ..."
   - Nếu không thấy, sẽ có warning: "LibreOffice not found on system"

## Lưu ý

- Backend sẽ tự động tìm LibreOffice ở các vị trí phổ biến
- Nếu cài ở vị trí khác, đảm bảo thêm vào PATH environment variable
- Trên Windows, có thể cần restart terminal/IDE sau khi cài đặt

## Troubleshooting

### LibreOffice không được tìm thấy
1. Kiểm tra file `soffice.exe` có tồn tại không
2. Kiểm tra PATH environment variable
3. Thử chạy thủ công: `soffice.exe --version`
4. Xem logs của backend để biết đường dẫn nào đã được kiểm tra

### Lỗi khi convert
1. Kiểm tra quyền truy cập file
2. Kiểm tra đủ dung lượng ổ đĩa
3. Xem logs chi tiết trong backend console

