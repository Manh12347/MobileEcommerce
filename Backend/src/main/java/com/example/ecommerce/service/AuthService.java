package com.example.ecommerce.service;

import com.example.ecommerce.dto.*;
import com.example.ecommerce.entity.Account;
import com.example.ecommerce.entity.Profile;
import com.example.ecommerce.exception.AuthenticationException;
import com.example.ecommerce.repository.AccountRepository;
import com.example.ecommerce.repository.ProfileRepository;
import com.example.ecommerce.security.JwtTokenProvider;
import com.example.ecommerce.util.ValidationUtil;
import org.mindrot.jbcrypt.BCrypt;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.time.LocalDateTime;
import java.util.Optional;
import java.util.UUID;

@Service
@Transactional
public class AuthService {

    @Autowired
    private AccountRepository accountRepository;

    @Autowired
    private ProfileRepository profileRepository;

    @Autowired
    private JwtTokenProvider jwtTokenProvider;

    @Autowired
    private UserSessionService userSessionService;

    @Autowired
    private OtpService otpService;

    @Autowired
    private TwoFactorService twoFactorService;

    public LoginResponse oauthLogin(OAuthLoginRequest request) {
        if (request.getProvider() == null || request.getProvider().isBlank()) {
            throw new AuthenticationException("Provider is required");
        }
        if (request.getProviderUserId() == null || request.getProviderUserId().isBlank()) {
            throw new AuthenticationException("Provider user ID is required");
        }
        if (request.getEmail() == null || request.getEmail().isBlank()) {
            throw new AuthenticationException("Email is required");
        }

        String email = request.getEmail().trim().toLowerCase();
        Account account = accountRepository.findByEmail(email).orElse(null);

        if (account == null) {
            account = new Account();
            account.setEmail(email);
            account.setPasswordHash(BCrypt.hashpw(UUID.randomUUID().toString(), BCrypt.gensalt(12)));
            account.setRole("customer");
            account.setStatus("active");
            account.setEmailConfirm(true);
            account.setIs2faEnabled(false);
            account.setFailedLoginAttempts(0);
            account = accountRepository.save(account);
        } else {
            if ("locked".equals(account.getStatus())) {
                throw new AuthenticationException("Account is locked");
            }
            if ("disabled".equals(account.getStatus())) {
                throw new AuthenticationException("Account is disabled");
            }
            if ("pending".equals(account.getStatus())) {
                account.setStatus("active");
            }
            account.setEmailConfirm(true);
            account.setFailedLoginAttempts(0);
            account.setLastFailedLogin(null);
            account = accountRepository.save(account);
        }

        upsertOAuthProfile(account, request);
        return createOAuthLoginResponse(account);
    }

    private LoginResponse createOAuthLoginResponse(Account account) {
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
        response.setMessage("OAuth login successful");
        return response;
    }

    private void upsertOAuthProfile(Account account, OAuthLoginRequest request) {
        Profile profile = profileRepository.findByAccountAccountId(account.getAccountId())
                .orElseGet(() -> {
                    Profile newProfile = new Profile();
                    newProfile.setAccount(account);
                    return newProfile;
                });

        if (request.getFullName() != null && !request.getFullName().isBlank()) {
            profile.setFullName(request.getFullName());
        }
        if (request.getAvatarUrl() != null && !request.getAvatarUrl().isBlank()) {
            profile.setAvatarUrl(request.getAvatarUrl());
        }

        profileRepository.save(profile);
    }

    public LoginResponse login(LoginRequest loginRequest) {
        String email = loginRequest.getEmail();
        String password = loginRequest.getPassword();

        if (email == null || email.isEmpty() || password == null || password.isEmpty()) {
            throw new AuthenticationException("Email và password không được để trống");
        }

        // 1. Find account by email
        Optional<Account> accountOpt = accountRepository.findByEmail(email);
        if (!accountOpt.isPresent()) {
            throw new AuthenticationException("Email không tồn tại");
        }

        Account account = accountOpt.get();

        // 2. Check account status
        if ("locked".equals(account.getStatus())) {
            throw new AuthenticationException("Tài khoản bị khóa do đăng nhập sai quá nhiều lần");
        }
        if ("disabled".equals(account.getStatus())) {
            throw new AuthenticationException("Tài khoản đã bị vô hiệu hóa");
        }
        if ("pending".equals(account.getStatus())) {
            throw new AuthenticationException("Tài khoản đang chờ xác nhận");
        }

        // 3. Check email confirmed
        if (!account.getEmailConfirm()) {
            throw new AuthenticationException("Email chưa được xác nhận. Vui lòng kiểm tra email để xác nhận tài khoản");
        }

        // 4. Verify password
        if (!BCrypt.checkpw(password, account.getPasswordHash())) {
            // Record failed login
            recordFailedLogin(account);
            throw new AuthenticationException("Mật khẩu sai");
        }

        // 5. Reset failed login attempts on successful login
        resetFailedLogin(account);

        // 6. Generate tokens
        String accessToken = jwtTokenProvider.generateAccessToken(
                account.getAccountId(),
                account.getEmail(),
                account.getRole()
        );
        String refreshToken = jwtTokenProvider.generateRefreshToken(
                account.getAccountId(),
                account.getEmail()
        );

        // 7. Save session
        LocalDateTime expiresAt = LocalDateTime.now().plusDays(7);
        userSessionService.createSession(account, refreshToken, expiresAt);

        // 8. Build response
        LoginResponse response = new LoginResponse();
        response.setAccountId(account.getAccountId());
        response.setEmail(account.getEmail());
        response.setRole(account.getRole());
        response.setAccessToken(accessToken);
        response.setRefreshToken(refreshToken);

        // 9. Check if 2FA is enabled
        if (account.getIs2faEnabled()) {
            String pendingToken = twoFactorService.createPending2FAData(account.getAccountId());
            response.setRequire2FA(true);
            response.setPendingToken(pendingToken);
            response.setMessage("2FA được kích hoạt. Vui lòng verify OTP");
        } else {
            response.setRequire2FA(false);
            response.setMessage("Đăng nhập thành công");
        }

        return response;
    }

    /**
     * Register new account with email and password
     * Store pending registration in Redis (not in DB)
     * Send OTP to email for verification
     * Account will be created in DB only after OTP verification succeeds
     */
    public RegisterResponse register(RegisterRequest registerRequest) {
        String email = registerRequest.getEmail();
        String password = registerRequest.getPassword();

        // Validate inputs
        if (email == null || email.isEmpty()) {
            throw new AuthenticationException("Email không được để trống");
        }
        if (password == null || password.isEmpty()) {
            throw new AuthenticationException("Mật khẩu không được để trống");
        }

        // Check email already exists
        Optional<Account> existingAccount = accountRepository.findByEmail(email);
        if (existingAccount.isPresent()) {
            throw new AuthenticationException("Email đã được sử dụng");
        }

        // Hash password with BCrypt (cost = 12)
        String hashedPassword = BCrypt.hashpw(password, BCrypt.gensalt(12));

        // Save pending registration to Redis (not DB yet)
        otpService.savePendingRegistration(email, hashedPassword);

        // Generate and send OTP
        OtpSendResponse otpResponse = otpService.generateAndSendOtp(email);

        RegisterResponse response = new RegisterResponse();
        response.setAccountId(null);  // No account ID yet since not saved to DB
        response.setEmail(email);
        response.setRequiresCaptcha(otpResponse.isRequiresCaptcha());
        response.setMessage(otpResponse.getMessage());

        return response;
    }

    /**
     * Verify OTP and finalize account
     * If pending registration exists, account will be created in DB
     * If account already exists, just mark email as confirmed
     */
    public ApiResponse<String> verifyOtp(VerifyOtpRequest verifyOtpRequest) {
        String email = verifyOtpRequest.getEmail();
        String otp = verifyOtpRequest.getOtp();

        // Validate inputs
        if (email == null || email.isEmpty()) {
            throw new AuthenticationException("Email không được để trống");
        }
        if (otp == null || otp.isEmpty()) {
            throw new AuthenticationException("OTP không được để trống");
        }

        // Verify OTP (this will also finalize pending registration if exists)
        try {
            otpService.verifyOtp(email, otp);
        } catch (IllegalArgumentException e) {
            throw new AuthenticationException(e.getMessage());
        }

        return new ApiResponse<>(true, "Xác minh OTP thành công. Tài khoản đã được kích hoạt", null);
    }

    public ApiResponse<String> forgotPassword(ForgotPasswordRequest request) {
        String email = request.getEmail();

        if (email == null || email.isBlank()) {
            throw new AuthenticationException("Email is required");
        }

        Account account = accountRepository.findByEmail(email.trim())
                .orElseThrow(() -> new AuthenticationException("Email does not exist"));

        if ("disabled".equals(account.getStatus())) {
            throw new AuthenticationException("Account is disabled");
        }
        if ("admin".equals(account.getRole())) {
            throw new AuthenticationException("Admin accounts cannot use password reset");
        }

        try {
            otpService.generateAndSendOtp(account.getEmail());
        } catch (IllegalArgumentException e) {
            throw new AuthenticationException(e.getMessage());
        }

        return new ApiResponse<>(true, "OTP has been sent to your email", null);
    }

    public ApiResponse<String> resetPassword(ResetPasswordRequest request) {
        String email = request.getEmail();
        String otp = request.getOtp();
        String newPassword = request.getNewPassword();

        if (email == null || email.isBlank()) {
            throw new AuthenticationException("Email is required");
        }
        if (otp == null || otp.isBlank()) {
            throw new AuthenticationException("OTP is required");
        }
        ValidationUtil.ValidationResult passwordValidation = ValidationUtil.validatePassword(newPassword);
        if (!passwordValidation.isValid()) {
            throw new AuthenticationException(passwordValidation.getMessage());
        }

        Account account = accountRepository.findByEmail(email.trim())
                .orElseThrow(() -> new AuthenticationException("Email does not exist"));

        if ("disabled".equals(account.getStatus())) {
            throw new AuthenticationException("Account is disabled");
        }
        if ("admin".equals(account.getRole())) {
            throw new AuthenticationException("Admin accounts cannot use password reset");
        }

        try {
            otpService.verifyOtp(account.getEmail(), otp);
        } catch (IllegalArgumentException e) {
            throw new AuthenticationException(e.getMessage());
        }

        account.setPasswordHash(BCrypt.hashpw(newPassword, BCrypt.gensalt(12)));
        account.setEmailConfirm(true);
        account.setFailedLoginAttempts(0);
        account.setLastFailedLogin(null);
        if ("locked".equals(account.getStatus()) || "pending".equals(account.getStatus())) {
            account.setStatus("active");
        }
        accountRepository.save(account);

        return new ApiResponse<>(true, "Password has been reset successfully", null);
    }

    private void recordFailedLogin(Account account) {
        Integer attempts = account.getFailedLoginAttempts() != null ?
                account.getFailedLoginAttempts() + 1 : 1;
        account.setFailedLoginAttempts(attempts);
        account.setLastFailedLogin(LocalDateTime.now());

        // Lock account after 5 failed attempts
        if (attempts >= 5) {
            account.setStatus("locked");
        }

        accountRepository.save(account);
    }

    private void resetFailedLogin(Account account) {
        account.setFailedLoginAttempts(0);
        account.setLastFailedLogin(null);
        accountRepository.save(account);
    }

    public void confirmEmail(Integer accountId) {
        Optional<Account> accountOpt = accountRepository.findById(accountId);
        if (accountOpt.isPresent()) {
            Account account = accountOpt.get();
            account.setEmailConfirm(true);
            account.setStatus("active");
            accountRepository.save(account);
        }
    }
}
