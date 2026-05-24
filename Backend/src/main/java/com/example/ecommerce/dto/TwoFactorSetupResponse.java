package com.example.ecommerce.dto;

import lombok.AllArgsConstructor;
import lombok.Getter;
import lombok.NoArgsConstructor;
import lombok.Setter;

@Getter
@Setter
@NoArgsConstructor
@AllArgsConstructor
public class TwoFactorSetupResponse {
    private String secret;
    private String qrCodeImage;
    private String manualEntryKey;
}
