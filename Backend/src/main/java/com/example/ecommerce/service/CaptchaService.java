package com.example.ecommerce.service;

import com.fasterxml.jackson.databind.ObjectMapper;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.data.redis.core.StringRedisTemplate;
import org.springframework.http.HttpEntity;
import org.springframework.http.HttpHeaders;
import org.springframework.http.MediaType;
import org.springframework.http.ResponseEntity;
import org.springframework.stereotype.Service;
import org.springframework.web.client.RestTemplate;

import java.util.Map;
import java.util.concurrent.TimeUnit;

/**
 * CAPTCHA Service for anti-spam protection using Google reCAPTCHA v2 (Checkbox)
 * Manages CAPTCHA verification for OTP requests
 */
@Service
@RequiredArgsConstructor
@Slf4j
public class CaptchaService {

    private final StringRedisTemplate redisTemplate;
    private final RestTemplate restTemplate;
    private final ObjectMapper objectMapper;

    @Value("${recaptcha.secret-key:}")
    private String recaptchaSecretKey;

    @Value("${recaptcha.verify-url:https://www.google.com/recaptcha/api/siteverify}")
    private String recaptchaVerifyUrl;

    @Value("${recaptcha.score-threshold:0.5}")
    private double scoreThreshold;

    // Redis key prefix for CAPTCHA verification status
    private static final String CAPTCHA_VERIFIED_KEY_PREFIX = "captcha_verified:";
    
    // CAPTCHA verification validity in minutes (10 minutes)
    private static final int CAPTCHA_VERIFIED_EXPIRY_MINUTES = 10;

    /**
     * Verify reCAPTCHA v3 token with Google
     * v3 is invisible - runs in background without user interaction
     * Returns score evaluation (0-1, higher = more likely human)
     * Requires score >= scoreThreshold to pass
     */
    @SuppressWarnings("unchecked")
    public boolean verifyCaptcha(String email, String recaptchaToken) {
        if (email == null || email.isEmpty() || recaptchaToken == null || recaptchaToken.isEmpty()) {
            log.warn("Invalid CAPTCHA verification request");
            return false;
        }

        if (recaptchaSecretKey == null || recaptchaSecretKey.isEmpty()) {
            log.warn("reCAPTCHA secret key not configured");
            return false;
        }

        try {
            // Prepare request to Google reCAPTCHA API
            HttpHeaders headers = new HttpHeaders();
            headers.setContentType(MediaType.APPLICATION_FORM_URLENCODED);

            String body = "secret=" + recaptchaSecretKey + "&response=" + recaptchaToken;
            HttpEntity<String> request = new HttpEntity<>(body, headers);

            // Call Google API
            ResponseEntity<String> response = restTemplate.postForEntity(recaptchaVerifyUrl, request, String.class);
            
            if (response.getStatusCode().is2xxSuccessful() && response.getBody() != null) {
                // Parse response
                Map<String, Object> responseBody = objectMapper.readValue(response.getBody(), Map.class);
                boolean success = (Boolean) responseBody.getOrDefault("success", false);
                double score = ((Number) responseBody.getOrDefault("score", 0)).doubleValue();
                String action = (String) responseBody.getOrDefault("action", "");
                
                log.info("reCAPTCHA v3 response - email: {}, success: {}, score: {}, action: {}", 
                    email, success, score, action);
                
                // Check success and score >= threshold
                if (success && score >= scoreThreshold) {
                    log.info("reCAPTCHA verification passed - email: {}, score: {} >= threshold: {}", 
                        email, score, scoreThreshold);
                    markCaptchaVerified(email);
                    return true;
                } else {
                    log.warn("reCAPTCHA verification failed - email: {}, score: {}, threshold: {}", 
                        email, score, scoreThreshold);
                    return false;
                }
            } else {
                log.error("reCAPTCHA API returned error: {}", response.getStatusCode());
                return false;
            }

        } catch (Exception e) {
            log.error("Error verifying reCAPTCHA", e);
            return false;
        }
    }

    /**
     * Mark CAPTCHA as verified for email
     * Allows resend OTP without CAPTCHA requirement for this verification window
     */
    private void markCaptchaVerified(String email) {
        String verifiedKey = CAPTCHA_VERIFIED_KEY_PREFIX + email;
        redisTemplate.opsForValue().set(verifiedKey, "verified", CAPTCHA_VERIFIED_EXPIRY_MINUTES, TimeUnit.MINUTES);
    }

    /**
     * Check if CAPTCHA is already verified for email
     */
    public boolean isCaptchaVerified(String email) {
        String verifiedKey = CAPTCHA_VERIFIED_KEY_PREFIX + email;
        return redisTemplate.hasKey(verifiedKey);
    }

    /**
     * Clear CAPTCHA verification for email
     * Called when OTP verification is successful
     */
    public void clearCaptchaVerification(String email) {
        String verifiedKey = CAPTCHA_VERIFIED_KEY_PREFIX + email;
        redisTemplate.delete(verifiedKey);
        log.info("CAPTCHA verification cleared for email: {}", email);
    }
}
