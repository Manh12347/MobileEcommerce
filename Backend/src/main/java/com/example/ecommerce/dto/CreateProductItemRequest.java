package com.example.ecommerce.dto;

import jakarta.validation.constraints.Min;
import jakarta.validation.constraints.NotNull;
import lombok.AllArgsConstructor;
import lombok.Data;
import lombok.NoArgsConstructor;
import java.math.BigDecimal;

@Data
@NoArgsConstructor
@AllArgsConstructor
public class CreateProductItemRequest {

    @NotNull(message = "Product ID không được để trống")
    private Integer productId;

    private String sku;
    private String description;

    @NotNull(message = "Số lượng tồn kho không được để trống")
    @Min(value = 1, message = "Số lượng tồn kho phải >= 1")
    private Integer stockQuantity;

    private String status;
    private BigDecimal price;
    private BigDecimal salePrice;
    private String specifications;
    private String images;
    private String mainImageUrl;
}
