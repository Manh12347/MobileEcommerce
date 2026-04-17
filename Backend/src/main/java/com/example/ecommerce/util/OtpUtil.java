package com.example.ecommerce.util;

import java.util.Random;

public class OtpUtil {

    private static final Random RANDOM = new Random();

    /**
     * Tạo OTP 6 số ngẫu nhiên
     */
    public static String generateOtp() {
        int otp = 100000 + RANDOM.nextInt(900000);
        return String.valueOf(otp);
    }

    /**
     * Validate OTP (kiểm tra format)
     */
    public static boolean isValidOtp(String otp) {
        return otp != null && otp.matches("\\d{6}");
    }
}
