namespace PTVBTPM.Models.Configurations
{
    /// <summary>
    /// Cấu hình cho webhook biến động số dư từ ngân hàng
    /// </summary>
    public class HooksConfig
    {
        /// <summary>
        /// API key để xác thực webhook từ ngân hàng
        /// </summary>
        public string ApiKey { get; set; } = string.Empty;

        /// <summary>
        /// Pattern để parse order ID từ nội dung chuyển khoản (ví dụ: ORDER_123)
        /// </summary>
        public string OrderIdPattern { get; set; } = "ORDER_";

        /// <summary>
        /// Số tiền chênh lệch cho phép (tolerance) khi so sánh số tiền thanh toán
        /// </summary>
        public decimal AmountTolerance { get; set; } = 0;
    }
}

