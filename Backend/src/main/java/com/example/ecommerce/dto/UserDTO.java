package com.example.ecommerce.dto;

import lombok.AllArgsConstructor;
import lombok.Getter;
import lombok.NoArgsConstructor;
import lombok.Setter;

@Getter @Setter
@NoArgsConstructor
@AllArgsConstructor
public class UserDTO {
    private Integer accountId;
    private String email;
    private Boolean emailConfirm;
    private String role;
    private String status;
    private Boolean is2faEnabled;
    private String fullName;
    private String phone;
    private String address;
    private String avatarUrl;
    private String createdOn;
    private String modifiedOn;
}
