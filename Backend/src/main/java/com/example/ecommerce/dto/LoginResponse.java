package com.example.ecommerce.dto;

import lombok.AllArgsConstructor;
import lombok.Getter;
import lombok.NoArgsConstructor;
import lombok.Setter;

@Getter @Setter
@NoArgsConstructor
@AllArgsConstructor
public class LoginResponse {
    private Integer accountId;
    private String email;
    private String role;
    private String accessToken;
    private String refreshToken;
    private Boolean require2FA;
    private String message;
}
