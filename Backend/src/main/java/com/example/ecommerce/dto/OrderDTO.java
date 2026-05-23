package com.example.ecommerce.dto;

import lombok.AllArgsConstructor;
import lombok.Data;
import lombok.NoArgsConstructor;

import java.math.BigDecimal;
import java.util.List;

@Data
@NoArgsConstructor
@AllArgsConstructor
public class OrderDTO {
    private Integer orderId;
    private String orderCode;
    private Integer accountId;
    private String status;
    private String paymentStatus;
    private String paymentMethod;
    private String shippingAddress;
    private String phone;
    private BigDecimal totalPrice;
    private String createdOn;
    private List<OrderItemDTO> items;
}
