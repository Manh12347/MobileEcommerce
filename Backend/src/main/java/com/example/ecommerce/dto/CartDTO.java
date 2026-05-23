package com.example.ecommerce.dto;

import lombok.AllArgsConstructor;
import lombok.Data;
import lombok.NoArgsConstructor;

import java.math.BigDecimal;
import java.util.List;

@Data
@NoArgsConstructor
@AllArgsConstructor
public class CartDTO {
    private Integer cartId;
    private Integer accountId;
    private String createdOn;
    private String updatedOn;
    private List<CartItemDTO> items;
    private Integer totalItems;
    private BigDecimal totalAmount;
}
