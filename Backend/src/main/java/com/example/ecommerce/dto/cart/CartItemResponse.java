package com.example.ecommerce.dto.cart;

import lombok.AllArgsConstructor;
import lombok.Builder;
import lombok.Data;
import lombok.NoArgsConstructor;

import java.math.BigDecimal;

@Data
@NoArgsConstructor
@AllArgsConstructor
@Builder
public class CartItemResponse {

    private Integer cartItemId;
    private Integer productVariantId;
    private String productName;
    private String image;
    private String variant;
    private BigDecimal price;
    private Integer quantity;
    private BigDecimal subtotal;
}
