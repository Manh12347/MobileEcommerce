package com.example.ecommerce.dto;

import jakarta.validation.constraints.NotBlank;
import lombok.AllArgsConstructor;
import lombok.Data;
import lombok.NoArgsConstructor;

@Data
@NoArgsConstructor
@AllArgsConstructor
public class OAuthLoginRequest {

    @NotBlank(message = "Provider is required")
    private String provider;

    @NotBlank(message = "Provider user ID is required")
    private String providerUserId;

    @NotBlank(message = "Email is required")
    private String email;

    private String fullName;
    private String avatarUrl;
}
