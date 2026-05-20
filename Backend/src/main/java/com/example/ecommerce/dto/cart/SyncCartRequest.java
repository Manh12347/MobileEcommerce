package com.example.ecommerce.dto.cart;

import com.fasterxml.jackson.annotation.JsonProperty;
import jakarta.validation.Valid;
import jakarta.validation.constraints.NotEmpty;
import jakarta.validation.constraints.NotNull;
import lombok.AllArgsConstructor;
import lombok.Data;
import lombok.NoArgsConstructor;

import java.util.List;

@Data
@NoArgsConstructor
@AllArgsConstructor
public class SyncCartRequest {

    @NotNull(message = "userId is required")
    @JsonProperty("userId")
    private Integer userId;

    @NotEmpty(message = "items must not be empty")
    @Valid
    private List<SyncCartItemRequest> items;
}
