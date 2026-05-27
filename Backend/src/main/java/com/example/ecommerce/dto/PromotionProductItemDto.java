package com.example.ecommerce.dto;

import lombok.Data;
import java.math.BigDecimal;

@Data
public class PromotionProductItemDto {
    private Integer productItemId;
    private String sku;
    private String productName;
    private Integer productId;
    private Integer promotionId;
    private java.math.BigDecimal salePrice;
    private java.math.BigDecimal originalPrice;
}
