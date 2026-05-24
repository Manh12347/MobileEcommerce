package com.example.ecommerce.dto;

import lombok.AllArgsConstructor;
import lombok.Data;
import lombok.NoArgsConstructor;
import java.math.BigDecimal;

/**
 * DTO cho list view - không chứa serials để tăng performance
 */
@Data
@NoArgsConstructor
@AllArgsConstructor
public class ProductItemListDTO {
    private Integer productItemId;
    private String sku;
    private String description;
    private Integer stockQuantity;
    private Integer soldQuantity;
    private String status;
    private BigDecimal price;
    private BigDecimal salePrice;
    private Integer productId;
    private String productName;
    private String createdAt;
    private String specifications;
}
