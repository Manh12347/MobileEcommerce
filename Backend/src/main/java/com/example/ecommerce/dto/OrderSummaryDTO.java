package com.example.ecommerce.dto;

import lombok.AllArgsConstructor;
import lombok.Data;
import lombok.NoArgsConstructor;

import java.math.BigDecimal;
import java.util.List;

@Data
@NoArgsConstructor
@AllArgsConstructor
public class OrderSummaryDTO {
    private Integer orderId;
    private String orderCode;
    private String status;
    private String paymentStatus;
    private String paymentMethod;
    private BigDecimal totalPrice;
    private String createdOn;
    private Integer itemCount;
    private String warrantyEndDate;
    private Boolean isWarrantyExpired;
    private String warrantyRemainingText;
    private List<OrderSerialDTO> serials;
    // Customer info
    private String customerName;
    private String phone;
    private String email;
    private String shippingAddress;
}
