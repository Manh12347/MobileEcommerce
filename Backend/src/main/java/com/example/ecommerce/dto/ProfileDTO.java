package com.example.ecommerce.dto;

import lombok.AllArgsConstructor;
import lombok.Getter;
import lombok.NoArgsConstructor;
import lombok.Setter;

@Getter
@Setter
@NoArgsConstructor
@AllArgsConstructor
public class ProfileDTO {
    private Integer accountId;
    private String email;
    private String fullName;
    private String phone;
    private String address;
    private String avatarUrl;
    private String createdOn;
}
