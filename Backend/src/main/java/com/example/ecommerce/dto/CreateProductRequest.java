package com.example.ecommerce.dto;

import jakarta.validation.constraints.NotBlank;
import lombok.AllArgsConstructor;
import lombok.Data;
import lombok.NoArgsConstructor;

@Data
@NoArgsConstructor
@AllArgsConstructor
public class CreateProductRequest {
    @NotBlank(message = "Tên sản phẩm không được để trống")
    private String name;
    
    private Integer brandId;
    private Integer categoryId;
    private String status;
}
