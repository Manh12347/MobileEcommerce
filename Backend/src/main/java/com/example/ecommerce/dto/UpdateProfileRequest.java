package com.example.ecommerce.dto;

import lombok.AllArgsConstructor;
import lombok.Getter;
import lombok.NoArgsConstructor;
import lombok.Setter;

@Getter
@Setter
@NoArgsConstructor
@AllArgsConstructor
public class UpdateProfileRequest {
    private String fullName;
    private String phone;
    private String address;
    private String avatarUrl;
    private Integer provinceId;
    private String provinceName;
    private Integer districtId;
    private String districtName;
    private String wardCode;
    private String wardName;
}
