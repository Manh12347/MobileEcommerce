package com.example.ecommerce.dto;

import lombok.AllArgsConstructor;
import lombok.Data;
import lombok.NoArgsConstructor;

import java.util.List;

@Data
@NoArgsConstructor
@AllArgsConstructor
public class OrderTrackDTO {
    private Integer orderId;
    private String orderCode;
    private String currentStatus;
    private String statusMessage;
    private List<OrderStatusStepDTO> timeline;
}
