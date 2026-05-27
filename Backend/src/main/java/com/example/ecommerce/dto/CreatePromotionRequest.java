package com.example.ecommerce.dto;

import lombok.Data;
import java.math.BigDecimal;

@Data
public class CreatePromotionRequest {
    private String promotionName;
    private Double discountPercent;
    private BigDecimal discountCost;
    private String startDate;
    private String endDate;
}
