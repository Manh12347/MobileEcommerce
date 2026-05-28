package com.example.ecommerce.dto;

import jakarta.validation.constraints.NotBlank;
import lombok.AllArgsConstructor;
import lombok.Data;
import lombok.NoArgsConstructor;

@Data
@NoArgsConstructor
@AllArgsConstructor
public class CreateOrderRequest {
    @NotBlank(message = "Địa chỉ giao hàng là bắt buộc")
    private String shippingAddress;

    @NotBlank(message = "Số điện thoại là bắt buộc")
    private String phone;

    private Integer provinceId;
    private Integer districtId;
    private String wardCode;
    private String provinceName;
    private String districtName;
    private String wardName;

    private String paymentMethod = "COD";
}
