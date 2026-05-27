package com.example.ecommerce.dto;

import lombok.AllArgsConstructor;
import lombok.Builder;
import lombok.Getter;
import lombok.NoArgsConstructor;
import lombok.Setter;

@Getter
@Setter
@NoArgsConstructor
@AllArgsConstructor
@Builder
public class PaymentNotificationPayload {

    private String gencode;
    private Integer orderId;
    private String orderCode;
    private String paymentStatus;
    private String message;
    private long timestamp;
}
