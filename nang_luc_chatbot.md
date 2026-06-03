# Tài Liệu Năng Lực Chatbot AI - TechShop

Tài liệu này tổng hợp toàn bộ các năng lực, tính năng hỗ trợ khách hàng và các kịch bản tương tác tự động mà **Chatbot AI TechShop** có thể thực hiện trên ứng dụng di động (Flutter) và máy chủ (FastAPI).

---

## 🚀 Danh Sách Năng Lực Cốt Lõi

### 1. Phân Tích Bối Cảnh Màn Hình (Screen Awareness)
Chatbot tự động nhận diện màn hình khách hàng đang truy cập để đưa ra phản hồi phù hợp:
*   **Màn hình Thanh toán (Checkout)**: Nhận biết khách hàng đang chuẩn bị hoàn tất đơn hàng và ưu tiên trả lời các vấn đề về giao dịch, chuyển khoản.
*   **Màn hình Chi tiết sản phẩm (ProductDetail)**: Nhận biết sản phẩm (ID, tên, thông số kỹ thuật) khách hàng đang xem để so sánh, tư vấn trực tiếp.
*   **Màn hình Xây dựng cấu hình (PCBuild)**: Nhận biết giỏ linh kiện tự dựng để kiểm tra tính tương thích.

---

## 💡 Các Kịch Bản Hỗ Trợ Chi Tiết

### 🛠️ Kịch Bản 1: Tư Vấn & Xây Dựng Cấu Hình PC (one-click import)
*   **Mô tả**: Chatbot đề xuất bộ PC đầy đủ linh kiện tương thích (CPU, Mainboard, RAM, PSU, SSD/HDD, Case, VGA) tối ưu nhất theo tầm giá yêu cầu.
*   **Tính năng đặc biệt**: 
    *   Hiển thị nút **"Áp dụng cấu hình này"** trên khung chat FE. Khi bấm, toàn bộ linh kiện đề xuất sẽ tự động được thêm vào cấu hình PC của khách hàng.
    *   *Câu hỏi mẫu*: `"tư vấn cấu hình máy tính chơi game 20tr"` hoặc chỉ cần gõ ngân sách nhanh như `"25 tr"`.

### 🔍 Kịch Bản 2: Đề Xuất Linh Kiện Giá Rẻ Hơn (Cheaper Alternatives)
*   **Mô tả**: Khi đang xem một linh kiện đắt tiền, chatbot giúp khách hàng tìm kiếm các linh kiện cùng loại trong kho có thông số tương đương nhưng mức giá tốt hơn.
*   **Tính năng đặc biệt**: Tự động trả về danh sách các sản phẩm thay thế hiển thị trực quan dưới dạng thẻ sản phẩm trên giao diện.
*   **Câu hỏi mẫu**: *"Có sản phẩm nào cùng thông số hay tốt hơn nhưng giá rẻ hơn không?"*

### ⚙️ Kịch Bản 3: Kiểm Tra Tương Thích Linh Kiện Phần Cứng
*   **Mô tả**: Đánh giá chi tiết khả năng tương thích của linh kiện đang xem với các hệ thống phổ biến.
*   **Câu hỏi mẫu**: *"sản phẩm này kết nối được b760 ddr5 ko"*
*   **Cơ chế hoạt động**: Phân tích socket CPU (LGA1700), loại bộ nhớ RAM (DDR5 vs DDR4) để đưa ra câu trả lời chính xác 100%.

### 💳 Kịch Bản 4: Hỗ Trợ Thanh Toán QR Tự Động
*   **Mô tả**: Giải đáp quy trình đối soát thanh toán khi khách hàng thực hiện quét mã chuyển khoản QR.
*   **Câu hỏi mẫu**: *"Thanh toán QR là ntn?"*
*   **Câu trả lời của AI**: Thông báo hệ thống quét tự động sẽ duyệt đơn hàng sau từ **1 đến 3 phút**.

### 💼 Kịch Bản 5: Tư Vấn Nâng Cấp PC (Upgrade / Migration)
*   **Mô tả**: Xây dựng cấu hình xung quanh các linh kiện cũ đã có sẵn của khách hàng.
*   **Câu hỏi mẫu**: *"Tôi đang có main H610 và CPU i5-12400, hãy build tiếp các linh kiện còn lại trong tầm giá 8tr"*
*   **Cơ chế hoạt động**: Đặt giá của linh kiện có sẵn là 0 VNĐ và phân bổ tối ưu ngân sách còn lại cho RAM, GPU, nguồn, ổ cứng, vỏ case.

### 📉 Kịch Bản 6: Xử Lý Ngân Sách Thấp (APU Fallback)
*   **Mô tả**: Nếu ngân sách khách hàng quá thấp (dưới 10M), chatbot sẽ không chọn VGA rời mà tối ưu hóa bằng CPU tích hợp đồ họa (APU), đồng thời định hướng nâng cấp sau này.

---

## 🚫 Chính Sách Hạn Chế Tán Gẫu (PC & Shop Only)
*   Chatbot được thiết lập cấu hình **hạn chế tối đa việc tán gẫu các chủ đề không liên quan**.
*   AI sẽ **từ chối một cách lịch sự** đối với các câu hỏi không liên quan đến công nghệ, linh kiện máy tính hoặc chính sách cửa hàng (ví dụ: công thức nấu ăn, thời tiết, giải toán, v.v.) và định hướng khách hàng quay trở lại chủ đề mua sắm phần cứng.
