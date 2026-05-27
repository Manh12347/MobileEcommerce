using System;
using System.Collections.Generic;

namespace PTVBTPM.Models.DTOs
{
    /// <summary>
    /// Thông tin đơn hàng lưu trong cache để đối chiếu với biến động số dư
    /// </summary>
    public class OrderCacheInfo
    {
        public int OrderId { get; set; }
        public int? UserId { get; set; }
        public decimal TotalAmount { get; set; }
        public string PaymentType { get; set; } = string.Empty;
        public string Gencode { get; set; } = string.Empty;
        public string Status { get; set; } = string.Empty;
        public DateTime CreatedAt { get; set; }
        /// <summary>
        /// Số trang cần mua (chỉ dùng cho PaymentType = "PURCHASE_PAGES")
        /// </summary>
        public int? Pages { get; set; }
        
        /// <summary>
        /// Dung lượng MB cần mua (chỉ dùng cho PaymentType = "STORE")
        /// </summary>
        public long? StorageMb { get; set; }

        /// <summary>
        /// Danh sách items trong đơn hàng (chỉ dùng cho PaymentType = "ORDER")
        /// </summary>
        public List<OrderItemDto> Items { get; set; } = new List<OrderItemDto>();
    }
}

