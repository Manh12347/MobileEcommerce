package com.example.ecommerce.service;

import com.example.ecommerce.dto.*;
import com.example.ecommerce.entity.Account;
import com.example.ecommerce.exception.AuthenticationException;
import com.example.ecommerce.repository.AccountRepository;
import com.example.ecommerce.security.JwtTokenProvider;
import org.mindrot.jbcrypt.BCrypt;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.time.LocalDateTime;
import java.util.Optional;

@Service
@Transactional
public class AuthService {

    @Autowired
    private AccountRepository accountRepository;

    @Autowired
    private JwtTokenProvider jwtTokenProvider;

    @Autowired
    private UserSessionService userSessionService;

    @Autowired
    private OtpService otpService;

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
            response.setRequire2FA(true);
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

    /**
     * Resend OTP to email
     * Rate limited: 1-5 attempts without CAPTCHA, 6-10 require CAPTCHA
     */
    public OtpSendResponse resendOtp(String email) {
        if (email == null || email.isEmpty()) {
            throw new AuthenticationException("Email không được để trống");
        }
        try {
            return otpService.resendOtp(email);
        } catch (IllegalArgumentException e) {
            throw new AuthenticationException(e.getMessage());
        }
    }

    /**
     * Resend OTP with CAPTCHA verification
     * Used when rate limit requires CAPTCHA
     */
    public OtpSendResponse resendOtpWithCaptcha(String email, String recaptchaToken) {
        if (email == null || email.isEmpty()) {
            throw new AuthenticationException("Email không được để trống");
        }
        if (recaptchaToken == null || recaptchaToken.isEmpty()) {
            throw new AuthenticationException("reCAPTCHA token không được để trống");
        }
        try {
            return otpService.resendOtpWithCaptcha(email, recaptchaToken);
        } catch (IllegalArgumentException e) {
            throw new AuthenticationException(e.getMessage());
        }
    }
}
