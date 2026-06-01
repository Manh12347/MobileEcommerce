package com.example.ecommerce.dto;

import lombok.Data;
import java.math.BigDecimal;

@Data
public class ProductItemVariantDto {
    private Integer productItemId;
    private String sku;
    private String description;
    private Integer stockQuantity;
    private String status;
    private BigDecimal price;
    private BigDecimal salePrice;
    private String images;
    private String mainImageUrl;
}
