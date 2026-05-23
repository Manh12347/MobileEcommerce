package com.example.ecommerce.dto.cart;

import jakarta.validation.constraints.NotNull;
import lombok.AllArgsConstructor;
import lombok.Data;
import lombok.NoArgsConstructor;

@Data
@NoArgsConstructor
@AllArgsConstructor
public class UpdateCartRequest {

    @NotNull(message = "cartItemId is required")
    private Integer cartItemId;

    @NotNull(message = "quantity is required")
    private Integer quantity;
}
