package com.example.ecommerce.dto;

import jakarta.validation.constraints.Min;
import jakarta.validation.constraints.NotNull;
import lombok.AllArgsConstructor;
import lombok.Data;
import lombok.NoArgsConstructor;

@Data
@NoArgsConstructor
@AllArgsConstructor
public class AddCartItemRequest {
    @NotNull(message = "productItemId là bắt buộc")
    private Integer productItemId;

    @NotNull(message = "quantity là bắt buộc")
    @Min(value = 1, message = "quantity phải >= 1")
    private Integer quantity;
}
