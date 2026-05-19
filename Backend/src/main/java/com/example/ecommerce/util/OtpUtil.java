package com.example.ecommerce.util;

import java.util.ArrayList;
import java.util.Collections;
import java.util.List;
import java.util.Random;

public class OtpUtil {

    private static final Random RANDOM = new Random();
    private static final String CHARACTERS = "abcdefghijklmnopqrstuvwxyz0123456789";

    /**
     * Tạo chuỗi ngẫu nhiên gồm chữ thường và số, không trùng lặp ký tự
     * @param length độ dài chuỗi (tối đa 36 ký tự)
     * @return chuỗi ngẫu nhiên
     */
    public static String generateRandomString(int length) {
        if (length > CHARACTERS.length()) {
            throw new IllegalArgumentException("Độ dài không được vượt quá " + CHARACTERS.length());
        }
        List<Character> chars = new ArrayList<>();
        for (char c : CHARACTERS.toCharArray()) {
            chars.add(c);
        }
        Collections.shuffle(chars, RANDOM);
        StringBuilder result = new StringBuilder();
        for (int i = 0; i < length; i++) {
            result.append(chars.get(i));
        }
        return result.toString();
    }

    /**
     * Tạo chuỗi ngẫu nhiên 20 ký tự gồm chữ thường và số, không trùng lặp
     */
    public static String generateRandomString() {
        return generateRandomString(20);
    }

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
