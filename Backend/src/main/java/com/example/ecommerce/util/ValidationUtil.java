package com.example.ecommerce.util;

import java.util.regex.Pattern;

public class ValidationUtil {

    private static final Pattern EMAIL_PATTERN = Pattern.compile(
        "^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\\.[a-zA-Z]{2,}$"
    );
    private static final Pattern UPPERCASE_PATTERN = Pattern.compile("[A-Z]");
    private static final Pattern LOWERCASE_PATTERN = Pattern.compile("[a-z]");
    private static final Pattern DIGIT_PATTERN = Pattern.compile("[0-9]");
    private static final Pattern SPECIAL_CHAR_PATTERN = Pattern.compile("[!@#$%^&*()_+\\-=\\[\\]{};':\"\\\\|,.<>/?]");

    // ========================
    // Password Validation
    // ========================

    /**
     * Validate password theo rules:
     * - Ít nhất 8 ký tự
     * - Ít nhất 1 chữ hoa (A-Z)
     * - Ít nhất 1 chữ thường (a-z)
     * - Ít nhất 1 số (0-9)
     * - Ít nhất 1 ký tự đặc biệt
     */
    public static ValidationResult validatePassword(String password) {
        if (password == null || password.isEmpty()) {
            return new ValidationResult(false, "Mật khẩu không được để trống");
        }

        if (password.length() < 8) {
            return new ValidationResult(false, "Mật khẩu phải có ít nhất 8 ký tự");
        }

        if (!UPPERCASE_PATTERN.matcher(password).find()) {
            return new ValidationResult(false, "Mật khẩu phải chứa ít nhất 1 chữ hoa (A-Z)");
        }

        if (!LOWERCASE_PATTERN.matcher(password).find()) {
            return new ValidationResult(false, "Mật khẩu phải chứa ít nhất 1 chữ thường (a-z)");
        }

        if (!DIGIT_PATTERN.matcher(password).find()) {
            return new ValidationResult(false, "Mật khẩu phải chứa ít nhất 1 số (0-9)");
        }

        if (!SPECIAL_CHAR_PATTERN.matcher(password).find()) {
            return new ValidationResult(false, "Mật khẩu phải chứa ít nhất 1 ký tự đặc biệt (!@#$%^&*...)");
        }

        return new ValidationResult(true, "Mật khẩu hợp lệ");
    }

    // ========================
    // Email Validation
    // ========================

    /**
     * Validate email format
     */
    public static ValidationResult validateEmail(String email) {
        if (email == null || email.trim().isEmpty()) {
            return new ValidationResult(false, "Email không được để trống");
        }

        if (!EMAIL_PATTERN.matcher(email).matches()) {
            return new ValidationResult(false, "Email không hợp lệ");
        }

        return new ValidationResult(true, "Email hợp lệ");
    }

    // ========================
    // Validation Result Class
    // ========================

    public static class ValidationResult {
        private final boolean valid;
        private final String message;

        public ValidationResult(boolean valid, String message) {
            this.valid = valid;
            this.message = message;
        }

        public boolean isValid() {
            return valid;
        }

        public String getMessage() {
            return message;
        }
    }
}
