package com.example.ecommerce.dto;

import lombok.AllArgsConstructor;
import lombok.Builder;
import lombok.Getter;
import lombok.NoArgsConstructor;
import lombok.Setter;

import java.io.Serializable;
import java.math.BigDecimal;
import java.time.LocalDateTime;
import java.util.List;

@Getter
@Setter
@NoArgsConstructor
@AllArgsConstructor
@Builder
public class PaymentCacheInfo implements Serializable {

    private Integer orderId;
    private String orderCode;   // mã đơn hàng từ DB (ORDER_xxx)
    private String gencode;     // mã thanh toán ngân hàng (ORDER_xxxxxxxxxxxxxxx)
    private Integer accountId;
    private BigDecimal totalAmount;
    private String paymentStatus; // pending, paid
    private LocalDateTime createdAt;
    private Integer expiresInMinutes;

    /** Snapshot giỏ hàng để hoàn lại nếu thanh toán timeout */
    private List<CartSnapshotItem> cartSnapshot;

    @Getter
    @Setter
    @NoArgsConstructor
    @AllArgsConstructor
    @Builder
    public static class CartSnapshotItem implements Serializable {
        private Integer productItemId;
        private Integer quantity;
        private BigDecimal price;
    }
}
