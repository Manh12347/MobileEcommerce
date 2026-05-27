package com.example.ecommerce.dto;

import lombok.Data;
import java.math.BigDecimal;
import java.time.LocalDateTime;

@Data
public class PromotionResponse {
    private Integer promotionId;
    private String promotionName;
    private Double discountPercent;
    private BigDecimal discountCost;
    private LocalDateTime startDate;
    private LocalDateTime endDate;
    private Boolean isActive;
}
