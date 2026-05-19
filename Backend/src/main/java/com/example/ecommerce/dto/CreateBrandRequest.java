package com.example.ecommerce.dto;

import jakarta.validation.constraints.NotBlank;
import lombok.AllArgsConstructor;
import lombok.Data;
import lombok.NoArgsConstructor;

@Data
@NoArgsConstructor
@AllArgsConstructor
public class CreateBrandRequest {
    @NotBlank(message = "Tên brand không được để trống")
    private String name;
    
    private String country;
}
