package com.example.ecommerce.service;

import com.example.ecommerce.dto.LoginResponse;
import com.example.ecommerce.dto.TwoFactorSetupResponse;
import com.example.ecommerce.entity.Account;
import com.example.ecommerce.exception.AuthenticationException;
import com.example.ecommerce.repository.AccountRepository;
import com.example.ecommerce.security.JwtTokenProvider;
import com.fasterxml.jackson.databind.ObjectMapper;
import dev.samstevens.totp.code.CodeGenerator;
import dev.samstevens.totp.code.DefaultCodeGenerator;
import dev.samstevens.totp.code.DefaultCodeVerifier;
import dev.samstevens.totp.code.HashingAlgorithm;
import dev.samstevens.totp.exceptions.QrGenerationException;
import dev.samstevens.totp.qr.QrData;
import dev.samstevens.totp.secret.DefaultSecretGenerator;
import dev.samstevens.totp.secret.SecretGenerator;
import dev.samstevens.totp.time.SystemTimeProvider;
import dev.samstevens.totp.time.TimeProvider;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.data.redis.core.StringRedisTemplate;
import org.springframework.stereotype.Service;

import java.time.LocalDateTime;
import java.util.concurrent.TimeUnit;

@Service
@RequiredArgsConstructor
@Slf4j
public class TwoFactorService {

    private final AccountRepository accountRepository;
    private final JwtTokenProvider jwtTokenProvider;
    private final UserSessionService userSessionService;
    private final StringRedisTemplate redisTemplate;
    private final ObjectMapper objectMapper;

    @Value("${app.base-url:http://localhost:8080}")
    private String baseUrl;

    private static final String PENDING_TOKEN_PREFIX = "2fa_pending:";

    private final SecretGenerator secretGenerator = new DefaultSecretGenerator(32);
    private final CodeGenerator codeGenerator = new DefaultCodeGenerator(HashingAlgorithm.SHA1);
    private final TimeProvider timeProvider = new SystemTimeProvider();

    /**
     * Setup 2FA for an account - generates secret and QR code
     * Requires authentication (accountId from JWT)
     */
    public TwoFactorSetupResponse setup2FA(Integer accountId) {
        Account account = accountRepository.findById(accountId)
                .orElseThrow(() -> new AuthenticationException("Tài khoản không tồn tại"));

        String secret = secretGenerator.generate();

        QrData qrData = new QrData.Builder()
                .label(account.getEmail())
                .secret(secret)
                .issuer("MobileEcommerce")
                .algorithm(HashingAlgorithm.SHA1)
                .digits(6)
                .period(30)
                .build();

        String qrCodeImage;
        try {
            dev.samstevens.totp.qr.QrGenerator qrGenerator =
                    new dev.samstevens.totp.qr.ZxingPngQrGenerator();
            byte[] qrCodeBytes = qrGenerator.generate(qrData);
            qrCodeImage = "data:image/png;base64," + java.util.Base64.getEncoder().encodeToString(qrCodeBytes);
        } catch (QrGenerationException e) {
            log.error("Failed to generate QR code", e);
            throw new RuntimeException("Không thể tạo mã QR");
        }

        account.setTwofaSecret(secret);
        accountRepository.save(account);

        TwoFactorSetupResponse response = new TwoFactorSetupResponse();
        response.setSecret(secret);
        response.setQrCodeImage(qrCodeImage);
        response.setManualEntryKey(secret);

        log.info("2FA setup initiated for account: {}", accountId);
        return response;
    }

    /**
     * Enable 2FA after verifying the setup code
     * Requires authentication (accountId from JWT)
     */
    public void enable2FA(Integer accountId, String code) {
        Account account = accountRepository.findById(accountId)
                .orElseThrow(() -> new AuthenticationException("Tài khoản không tồn tại"));

        if (account.getTwofaSecret() == null || account.getTwofaSecret().isEmpty()) {
            throw new AuthenticationException("Vui lòng setup 2FA trước");
        }

        if (!verifyCode(account.getTwofaSecret(), code)) {
            throw new AuthenticationException("Mã xác thực không hợp lệ");
        }

        account.setIs2faEnabled(true);
        accountRepository.save(account);

        log.info("2FA enabled for account: {}", accountId);
    }

    /**
     * Disable 2FA for an account
     * Requires authentication (accountId from JWT)
     */
    public void disable2FA(Integer accountId, String code) {
        Account account = accountRepository.findById(accountId)
                .orElseThrow(() -> new AuthenticationException("Tài khoản không tồn tại"));

        if (!Boolean.TRUE.equals(account.getIs2faEnabled())) {
            throw new AuthenticationException("2FA chưa được bật");
        }

        if (!verifyCode(account.getTwofaSecret(), code)) {
            throw new AuthenticationException("Mã xác thực không hợp lệ");
        }

        account.setIs2faEnabled(false);
        account.setTwofaSecret(null);
        accountRepository.save(account);

        log.info("2FA disabled for account: {}", accountId);
    }

    /**
     * Verify TOTP code during login flow
     * Returns LoginResponse with real tokens if code is valid
     */
    public LoginResponse verifyLogin2FA(String pendingToken, String code) {
        if (pendingToken == null || pendingToken.isEmpty()) {
            throw new AuthenticationException("Pending token không hợp lệ");
        }

        PendingTwoFactorData data = getPendingData(pendingToken);
        if (data == null) {
            throw new AuthenticationException("Phiên xác thực đã hết hạn. Vui lòng đăng nhập lại");
        }

        Account account = accountRepository.findById(data.getAccountId())
                .orElseThrow(() -> new AuthenticationException("Tài khoản không tồn tại"));

        if (!verifyCode(account.getTwofaSecret(), code)) {
            throw new AuthenticationException("Mã xác thực không hợp lệ");
        }

        deletePendingData(pendingToken);

        resetFailedLogin(account);

        String accessToken = jwtTokenProvider.generateAccessToken(
                account.getAccountId(),
                account.getEmail(),
                account.getRole()
        );
        String refreshToken = jwtTokenProvider.generateRefreshToken(
                account.getAccountId(),
                account.getEmail()
        );

        LocalDateTime expiresAt = LocalDateTime.now().plusDays(7);
        userSessionService.createSession(account, refreshToken, expiresAt);

        LoginResponse response = new LoginResponse();
        response.setAccountId(account.getAccountId());
        response.setEmail(account.getEmail());
        response.setRole(account.getRole());
        response.setAccessToken(accessToken);
        response.setRefreshToken(refreshToken);
        response.setRequire2FA(false);
        response.setMessage("Đăng nhập thành công");

        log.info("2FA verification successful for account: {}", account.getAccountId());
        return response;
    }

    /**
     * Store pending 2FA data during login when 2FA is enabled
     * Returns a temporary token to identify this pending session
     */
    public String createPending2FAData(Integer accountId) {
        String pendingToken = java.util.UUID.randomUUID().toString();

        PendingTwoFactorData data = new PendingTwoFactorData();
        data.setAccountId(accountId);
        data.setCreatedAt(LocalDateTime.now().toString());

        try {
            String json = objectMapper.writeValueAsString(data);
            redisTemplate.opsForValue().set(
                    PENDING_TOKEN_PREFIX + pendingToken,
                    json,
                    5,
                    TimeUnit.MINUTES
            );
        } catch (Exception e) {
            log.error("Failed to store pending 2FA data", e);
            throw new RuntimeException("Lỗi khi lưu trữ dữ liệu xác thực");
        }

        return pendingToken;
    }

    /**
     * Get pending 2FA data from token
     */
    private PendingTwoFactorData getPendingData(String pendingToken) {
        try {
            String json = redisTemplate.opsForValue().get(PENDING_TOKEN_PREFIX + pendingToken);
            if (json == null) {
                return null;
            }
            return objectMapper.readValue(json, PendingTwoFactorData.class);
        } catch (Exception e) {
            log.error("Failed to read pending 2FA data", e);
            return null;
        }
    }

    /**
     * Delete pending 2FA data
     */
    private void deletePendingData(String pendingToken) {
        redisTemplate.delete(PENDING_TOKEN_PREFIX + pendingToken);
    }

    /**
     * Verify TOTP code against secret
     */
    private boolean verifyCode(String secret, String code) {
        DefaultCodeVerifier verifier = new DefaultCodeVerifier(codeGenerator, timeProvider);
        verifier.setAllowedTimePeriodDiscrepancy(1);
        return verifier.isValidCode(secret, code);
    }

    private void resetFailedLogin(Account account) {
        account.setFailedLoginAttempts(0);
        account.setLastFailedLogin(null);
        accountRepository.save(account);
    }

    @lombok.Data
    @lombok.NoArgsConstructor
    @lombok.AllArgsConstructor
    private static class PendingTwoFactorData {
        private Integer accountId;
        private String createdAt;
    }
}
