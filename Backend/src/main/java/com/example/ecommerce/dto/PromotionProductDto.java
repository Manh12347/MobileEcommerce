package com.example.ecommerce.dto;

import lombok.Data;
import java.math.BigDecimal;

@Data
public class PromotionProductDto {
    private Integer productId;
    private String productName;
    private Integer promotionId;
    private String promotionName;
    private Double discountPercent;
    private BigDecimal discountCost;
}
