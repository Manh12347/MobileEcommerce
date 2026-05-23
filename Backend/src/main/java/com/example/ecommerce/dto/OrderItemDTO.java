package com.example.ecommerce.dto;

import lombok.AllArgsConstructor;
import lombok.Data;
import lombok.NoArgsConstructor;

import java.math.BigDecimal;
import java.util.List;

@Data
@NoArgsConstructor
@AllArgsConstructor
public class OrderItemDTO {
    private Integer orderItemId;
    private Integer productItemId;
    private String sku;
    private String productName;
    private String mainImageUrl;
    private Integer quantity;
    private BigDecimal price;
    private BigDecimal lineTotal;
    private List<OrderSerialDTO> serials;
}
