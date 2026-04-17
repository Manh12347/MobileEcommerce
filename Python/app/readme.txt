trong file có chứa các file py tương ứng cho hệ thống RAG
docker-compose.yml chỉ chứa compose set up postgre và extension vector, gọi nhanh là pgvector -> tốt nhất phiên bản vector 0.8.1 , pg 17. Cần cài python, .net và react, riêng python thì cần cài !pip, cài thêm thư viện trong requirement.txt rồi chạy trong venv nếu được(chưa tìm hiểu cơ chế của docker), react cũng như thế sẽ cần thêm requiment để cài thư viện của react(maybe)
nginx_set_up.txt để chứa thông tin tham khảo set up reverse port cho chính dự án python này, cần chỉnh sửa lại theo port .net sau khi sửa lại main.py thuần api 
main.py có chứa 2 loại nguồn: code comment là cần xem lại, code không comment là code đã chạy trên server demo có view (cần xóa đi phần view để về thuần api)
start.sh để tham khảo chạy code trong main.py với biến app(biến khởi tạo)

nếu set up 1 server mới cần lưu ý về ssl vì chưa có cài (nhắc đến nginx_set_up)

để quán lý tất cả server -> gợi ý dùng pm2 để quản lý 