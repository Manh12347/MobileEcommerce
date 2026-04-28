package com.example.ecommerce.service;

import com.example.ecommerce.dto.OtpSendResponse;
import com.example.ecommerce.dto.PendingRegistration;
import com.example.ecommerce.entity.Account;
import com.example.ecommerce.repository.AccountRepository;
import com.example.ecommerce.util.OtpUtil;
import com.fasterxml.jackson.databind.ObjectMapper;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.data.redis.core.StringRedisTemplate;
import org.springframework.stereotype.Service;

import java.util.concurrent.TimeUnit;

@Service
@RequiredArgsConstructor
@Slf4j
public class OtpService {

    private final MailService mailService;
    private final StringRedisTemplate redisTemplate;
    private final AccountRepository accountRepository;
    private final ObjectMapper objectMapper;
    private final CaptchaService captchaService;

    @Value("${recaptcha.site-key:}")
    private String recaptchaSiteKey;
    
    // Redis key prefix for OTP
    private static final String OTP_KEY_PREFIX = "otp:";
    
    // Redis key prefix for pending registration
    private static final String PENDING_REGISTER_KEY_PREFIX = "pending_register:";
    
    // Redis key prefix for OTP send attempts
    private static final String OTP_ATTEMPTS_KEY_PREFIX = "otp_attempts:";
    
    // Redis key prefix for locked emails
    private static final String OTP_LOCKED_KEY_PREFIX = "otp_locked:";
    
    // Redis key prefix for expired OTP (to prevent reuse)
    private static final String OTP_EXPIRED_KEY_PREFIX = "otp_expired:";
    
    // Pending registration expiration time in minutes
    private static final int PENDING_REGISTER_EXPIRY_MINUTES = 10;
    
    // OTP active expiration time in SECONDS (for testing: 10 seconds)
    private static final int OTP_EXPIRY_SECONDS = 10;
    
    // Expired OTP storage time in minutes (1 hour)
    private static final int EXPIRED_OTP_STORAGE_MINUTES = 60;
    
    // Rate limiting thresholds
    private static final int OTP_ATTEMPTS_CAPTCHA_THRESHOLD = 5;    // 1-5: send OTP
    private static final int OTP_ATTEMPTS_LOCK_THRESHOLD = 10;       // 6-10: require CAPTCHA
    // >10: lock for 15-30 minutes
    
    // Lock duration in minutes
    private static final int LOCK_DURATION_MINUTES = 25;  // 15-30 minutes (using 25 as average)

    /**
     * Generate and send OTP via email with advanced rate limiting
     * Uses reCAPTCHA v3 for anti-spam protection
     * 1-5 attempts: Send OTP directly (no CAPTCHA)
     * 6-10 attempts: Require CAPTCHA verification
     * >10 attempts: Lock for 15-30 minutes
     * Returns information about rate limit status
     */
    public OtpSendResponse generateAndSendOtp(String email) {
        if (email == null || email.isEmpty()) {
            throw new IllegalArgumentException("Email không được để trống");
        }

        // Check if email is locked
        if (isEmailLocked(email)) {
            throw new IllegalArgumentException("Email đã bị khóa do gửi OTP quá nhiều lần. Vui lòng thử lại sau 15-30 phút");
        }

        // Get attempt count and check rate limit level
        int attempts = getCurrentAttempts(email);
        
        // >20 attempts: Lock immediately
        if (attempts > OTP_ATTEMPTS_LOCK_THRESHOLD) {
            lockEmail(email);
            throw new IllegalArgumentException("Email đã bị khóa do gửi OTP quá nhiều lần. Vui lòng thử lại sau 15-30 phút");
        }

        String otp = OtpUtil.generateOtp();
        String redisKey = OTP_KEY_PREFIX + email;
        
        // Save OTP to Redis with 10 second active expiration (for testing)
        redisTemplate.opsForValue().set(redisKey, otp, OTP_EXPIRY_SECONDS, TimeUnit.SECONDS);
        
        // Also save to expired OTP set (to prevent reuse after expiration)
        String expiredOtpKey = OTP_EXPIRED_KEY_PREFIX + email;
        redisTemplate.opsForValue().set(expiredOtpKey, otp, EXPIRED_OTP_STORAGE_MINUTES, TimeUnit.MINUTES);
        
        // Send OTP via email
        mailService.sendOtpEmail(email, otp);
        
        // Increment attempt counter
        incrementAttempts(email);
        
        int newAttempts = getCurrentAttempts(email);
        boolean requiresCaptcha = newAttempts > OTP_ATTEMPTS_CAPTCHA_THRESHOLD;
        
        OtpSendResponse response = new OtpSendResponse();
        response.setSuccess(true);
        response.setRequiresCaptcha(requiresCaptcha);
        
        if (requiresCaptcha) {
            // Return Google reCAPTCHA v3 site key for frontend to execute
            response.setRecaptchaSiteKey(recaptchaSiteKey);
            response.setMessage("OTP đã được gửi. Vui lòng xác thực CAPTCHA (chạy nền) để tiếp tục gửi lại OTP");
        } else {
            response.setMessage("OTP đã được gửi đến email của bạn");
        }
        
        log.info("OTP sent to email: {} (attempt {})", email, newAttempts);
        return response;
    }

    /**
     * Check if email is currently locked
     */
    private boolean isEmailLocked(String email) {
        String redisKey = OTP_LOCKED_KEY_PREFIX + email;
        return redisTemplate.hasKey(redisKey);
    }

    /**
     * Lock email for 15-30 minutes
     */
    private void lockEmail(String email) {
        String redisKey = OTP_LOCKED_KEY_PREFIX + email;
        redisTemplate.opsForValue().set(redisKey, "locked", LOCK_DURATION_MINUTES, TimeUnit.MINUTES);
        log.warn("Email locked due to too many OTP attempts: {}", email);
    }

    /**
     * Get current OTP send attempt count
     */
    private int getCurrentAttempts(String email) {
        String attemptsKey = OTP_ATTEMPTS_KEY_PREFIX + email;
        String attemptsStr = redisTemplate.opsForValue().get(attemptsKey);
        return attemptsStr != null ? Integer.parseInt(attemptsStr) : 0;
    }

    /**
     * Increment OTP send attempt counter (expires in PENDING_REGISTER_EXPIRY_MINUTES = 10p)
     */
    private void incrementAttempts(String email) {
        String attemptsKey = OTP_ATTEMPTS_KEY_PREFIX + email;
        
        int attempts = getCurrentAttempts(email);
        attempts++;
        
        // Set expiry to 10 minutes (attempt window)
        redisTemplate.opsForValue().set(attemptsKey, String.valueOf(attempts), PENDING_REGISTER_EXPIRY_MINUTES, TimeUnit.MINUTES);
    }

    /**
     * Reset OTP attempts after successful verification
     */
    private void resetOtpAttempts(String email) {
        String attemptsKey = OTP_ATTEMPTS_KEY_PREFIX + email;
        redisTemplate.delete(attemptsKey);
        log.info("OTP attempts reset for email: {}", email);
    }

    /**
     * Cleanup expired OTP and pending registration data
     * Called if OTP is not verified within EXPIRED_OTP_STORAGE_MINUTES (1 hour)
     */
    private void cleanupExpiredData(String email) {
        String otpKey = OTP_KEY_PREFIX + email;
        String pendingKey = PENDING_REGISTER_KEY_PREFIX + email;
        String expiredOtpKey = OTP_EXPIRED_KEY_PREFIX + email;
        String attemptsKey = OTP_ATTEMPTS_KEY_PREFIX + email;
        
        redisTemplate.delete(otpKey);
        redisTemplate.delete(pendingKey);
        redisTemplate.delete(expiredOtpKey);
        redisTemplate.delete(attemptsKey);
        
        log.info("Expired OTP and registration data cleaned up for email: {}", email);
    }

    /**
     * Save pending registration to Redis with OTP expiry time
     * Data will be automatically deleted if OTP expires
     */
    public void savePendingRegistration(String email, String passwordHash) {
        String redisKey = PENDING_REGISTER_KEY_PREFIX + email;
        PendingRegistration pending = new PendingRegistration(email, passwordHash);
        
        try {
            String jsonData = objectMapper.writeValueAsString(pending);
            // Store with pending registration expiry (1 minute)
            redisTemplate.opsForValue().set(redisKey, jsonData, PENDING_REGISTER_EXPIRY_MINUTES, TimeUnit.MINUTES);
            log.info("Pending registration saved to Redis for email: {}", email);
        } catch (Exception e) {
            log.error("Error saving pending registration", e);
            throw new RuntimeException("Error saving pending registration");
        }
    }

    /**
     * Get pending registration from Redis
     */
    public PendingRegistration getPendingRegistration(String email) {
        String redisKey = PENDING_REGISTER_KEY_PREFIX + email;
        String jsonData = redisTemplate.opsForValue().get(redisKey);
        
        if (jsonData == null) {
            log.warn("No pending registration found for email: {}", email);
            return null;
        }
        
        try {
            return objectMapper.readValue(jsonData, PendingRegistration.class);
        } catch (Exception e) {
            log.error("Error deserializing pending registration", e);
            return null;
        }
    }

    /**
     * Delete pending registration from Redis
     */
    public void removePendingRegistration(String email) {
        String redisKey = PENDING_REGISTER_KEY_PREFIX + email;
        redisTemplate.delete(redisKey);
        log.info("Pending registration removed for email: {}", email);
    }

    /**
     * Verify OTP
     * - Check against active OTP (valid for 10 seconds - for testing)
     * - Prevent reuse of expired OTP (stored for 1 hour)
     * - Create account if pending registration exists
     * - Cleanup expired data after 1 hour of inactivity
     */
    public boolean verifyOtp(String email, String otp) {
        String redisKey = OTP_KEY_PREFIX + email;
        String expiredOtpKey = OTP_EXPIRED_KEY_PREFIX + email;
        String activeOtp = redisTemplate.opsForValue().get(redisKey);
        
        if (activeOtp == null) {
            // OTP has expired, check if it's in the expired OTP set
            String expiredOtp = redisTemplate.opsForValue().get(expiredOtpKey);
            if (expiredOtp != null) {
                log.warn("Attempt to reuse expired OTP for email: {}", email);
                throw new IllegalArgumentException("OTP đã hết hạn. Vui lòng gửi lại OTP");
            }
            
            log.warn("No OTP found for email: {} or OTP expired", email);
            throw new IllegalArgumentException("OTP không tồn tại hoặc đã hết hạn");
        }

        // Verify OTP matches
        if (!activeOtp.equals(otp)) {
            log.warn("Invalid OTP for email: {}", email);
            throw new IllegalArgumentException("OTP không chính xác");
        }

        // OTP correct - finalize registration and cleanup
        redisTemplate.delete(redisKey);
        redisTemplate.delete(expiredOtpKey);
        
        // Try to finalize pending registration
        finalizePendingRegistration(email);
        
        log.info("OTP verified successfully for email: {}", email);
        return true;
    }

    /**
     * Finalize pending registration by creating account in DB
     * This is called after OTP verification succeeds
     */
    private void finalizePendingRegistration(String email) {
        PendingRegistration pending = getPendingRegistration(email);
        
        if (pending == null) {
            // No pending registration, this might be email verification for existing account
            Account account = accountRepository.findByEmail(email).orElse(null);
            if (account != null) {
                account.setEmailConfirm(true);
                accountRepository.save(account);
                resetOtpAttempts(email);
                captchaService.clearCaptchaVerification(email);
                log.info("Email confirmed for existing account: {}", email);
            }
            return;
        }

        // Create new account from pending registration
        Account account = new Account();
        account.setEmail(pending.getEmail());
        account.setPasswordHash(pending.getPasswordHash());
        account.setRole("customer");
        account.setStatus("active");
        account.setEmailConfirm(true);  // Set to true since OTP is verified
        account.setIs2faEnabled(false);
        account.setFailedLoginAttempts(0);
        
        accountRepository.save(account);
        removePendingRegistration(email);
        resetOtpAttempts(email);
        captchaService.clearCaptchaVerification(email);
        
        log.info("Account created successfully after OTP verification: {}", email);
    }

    /**
     * Delete OTP
     */
    public void removeOtp(String email) {
        String redisKey = OTP_KEY_PREFIX + email;
        redisTemplate.delete(redisKey);
        log.info("OTP removed for email: {}", email);
    }

    /**
     * Resend OTP
     * Checks if email has pending registration or existing unconfirmed account
     * Regenerates and sends new OTP with advanced rate limiting
     */
    public OtpSendResponse resendOtp(String email) {
        if (email == null || email.isEmpty()) {
            throw new IllegalArgumentException("Email không được để trống");
        }

        // Check if email is locked
        if (isEmailLocked(email)) {
            throw new IllegalArgumentException("Email đã bị khóa do gửi OTP quá nhiều lần. Vui lòng thử lại sau 15-30 phút");
        }

        // Check if pending registration exists
        PendingRegistration pending = getPendingRegistration(email);
        if (pending != null) {
            // Resend OTP for pending registration (with rate limiting)
            log.info("OTP resent for pending registration: {}", email);
            return generateAndSendOtp(email);
        }

        // Check if account exists and email is not confirmed
        Account account = accountRepository.findByEmail(email).orElse(null);
        if (account != null && !account.getEmailConfirm()) {
            // Resend OTP for unconfirmed account (with rate limiting)
            log.info("OTP resent for unconfirmed account: {}", email);
            return generateAndSendOtp(email);
        }

        // Email not found or already confirmed
        throw new IllegalArgumentException("Email không hợp lệ hoặc đã được xác thực");
    }

    /**
     * Resend OTP with reCAPTCHA v3 verification
     * Used when CAPTCHA is required (6-10 attempts)
     * Verifies reCAPTCHA v3 token with Google before allowing resend
     * v3 runs invisibly in background - no user interaction needed
     */
    public OtpSendResponse resendOtpWithCaptcha(String email, String recaptchaToken) {
        if (email == null || email.isEmpty()) {
            throw new IllegalArgumentException("Email không được để trống");
        }
        if (recaptchaToken == null || recaptchaToken.isEmpty()) {
            throw new IllegalArgumentException("reCAPTCHA token không được để trống");
        }

        // Verify reCAPTCHA with Google
        if (!captchaService.verifyCaptcha(email, recaptchaToken)) {
            throw new IllegalArgumentException("CAPTCHA xác thực không thành công. Vui lòng thử lại");
        }

        // CAPTCHA verified, proceed with resend OTP
        log.info("CAPTCHA verified, proceeding with OTP resend for: {}", email);
        
        // Call regular resend - will perform rate limiting check
        OtpSendResponse response = resendOtp(email);
        
        return response;
    }
}
