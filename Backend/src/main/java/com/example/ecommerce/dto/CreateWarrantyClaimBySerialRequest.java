package com.example.ecommerce.dto;

import jakarta.validation.constraints.NotBlank;
import lombok.AllArgsConstructor;
import lombok.Data;
import lombok.NoArgsConstructor;

@Data
@NoArgsConstructor
@AllArgsConstructor
public class CreateWarrantyClaimBySerialRequest {

    @NotBlank(message = "Số serial không được để trống")
    private String serialNumber;

    @NotBlank(message = "Mô tả lỗi không được để trống")
    private String description;
}
