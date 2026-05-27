namespace PTVBTPM.Models.DTOs
{
    /// <summary>
    /// Item trong đơn hàng
    /// </summary>
    public class OrderItemDto
    {
        /// <summary>
        /// ID sản phẩm
        /// </summary>
        public int ProductId { get; set; }

        /// <summary>
        /// Tên sản phẩm
        /// </summary>
        public string ProductName { get; set; } = string.Empty;

        /// <summary>
        /// Số lượng
        /// </summary>
        public int Quantity { get; set; }

        /// <summary>
        /// Giá mỗi sản phẩm
        /// </summary>
        public decimal Price { get; set; }

        /// <summary>
        /// Tổng tiền cho item này
        /// </summary>
        public decimal TotalPrice => Quantity * Price;
    }

    /// <summary>
    /// Request tạo đơn hàng
    /// </summary>
    public class CreateOrderRequestDto
    {
        /// <summary>
        /// Danh sách items trong đơn hàng
        /// </summary>
        public List<OrderItemDto> Items { get; set; } = new List<OrderItemDto>();

        /// <summary>
        /// Tổng tiền đơn hàng
        /// </summary>
        public decimal TotalAmount { get; set; }
    }

    /// <summary>
    /// Response tạo đơn hàng
    /// </summary>
    public class CreateOrderResponseDto
    {
        /// <summary>
        /// ID đơn hàng
        /// </summary>
        public int OrderId { get; set; }

        /// <summary>
        /// Mã gencode để thanh toán
        /// </summary>
        public string Gencode { get; set; } = string.Empty;

        /// <summary>
        /// Danh sách items
        /// </summary>
        public List<OrderItemDto> Items { get; set; } = new List<OrderItemDto>();

        /// <summary>
        /// Tổng tiền
        /// </summary>
        public decimal TotalAmount { get; set; }

        /// <summary>
        /// URL QR code
        /// </summary>
        public string QrUrl { get; set; } = string.Empty;

        /// <summary>
        /// Thời gian tạo
        /// </summary>
        public DateTime CreatedAt { get; set; }
    }
}
