package com.example.ecommerce.dto;

import lombok.AllArgsConstructor;
import lombok.Data;
import lombok.NoArgsConstructor;

import java.math.BigDecimal;

@Data
@NoArgsConstructor
@AllArgsConstructor
public class CartItemDTO {
    private Integer cartItemId;
    private Integer productItemId;
    private Integer quantity;
    private String sku;
    private String productName;
    private String mainImageUrl;
    private BigDecimal price;
    private BigDecimal salePrice;
    private BigDecimal lineTotal;
}
