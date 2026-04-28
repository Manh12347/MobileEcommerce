package com.example.ecommerce.dto;

import lombok.AllArgsConstructor;
import lombok.Data;
import lombok.NoArgsConstructor;

/**
 * Holds pending registration data before email verification
 * Stored in Redis and deleted after successful OTP verification
 */
@Data
@NoArgsConstructor
@AllArgsConstructor
public class PendingRegistration {
    private String email;
    private String passwordHash;
}
