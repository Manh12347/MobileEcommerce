package com.example.ecommerce.dto;

import lombok.Data;
import java.math.BigDecimal;

@Data
public class ApplyPromotionRequest {
    private Integer productId;
    private Integer promotionId;
}
