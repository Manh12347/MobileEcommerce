package com.example.ecommerce.dto;

import lombok.Data;
import java.math.BigDecimal;

@Data
public class UpdatePromotionRequest {
    private String promotionName;
    private Double discountPercent;
    private BigDecimal discountCost;
    private String startDate;
    private String endDate;
    private Boolean isActive;
}
