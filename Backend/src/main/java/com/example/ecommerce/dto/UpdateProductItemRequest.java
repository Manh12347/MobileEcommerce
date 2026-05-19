package com.example.ecommerce.dto;

import lombok.AllArgsConstructor;
import lombok.Data;
import lombok.NoArgsConstructor;
import java.math.BigDecimal;

@Data
@NoArgsConstructor
@AllArgsConstructor
public class UpdateProductItemRequest {
    private String sku;
    private String description;
    private Integer stockQuantity;
    private String status;
    private BigDecimal price;
    private BigDecimal salePrice;
    private String specifications;
    private String images;
    private String mainImageUrl;
}
