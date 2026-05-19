package com.example.ecommerce.util;

public class SerialUtil {

    private static final int SERIAL_LENGTH = 20;
    private static final int SEGMENT_LENGTH = 5;

    public static String formatSerial(String serial) {
        StringBuilder formatted = new StringBuilder();
        for (int i = 0; i < serial.length(); i += SEGMENT_LENGTH) {
            if (i > 0) {
                formatted.append("-");
            }
            int end = Math.min(i + SEGMENT_LENGTH, serial.length());
            formatted.append(serial, i, end);
        }
        return formatted.toString();
    }

    public static String generateFormattedSerial() {
        String rawSerial = OtpUtil.generateRandomString(SERIAL_LENGTH);
        return formatSerial(rawSerial);
    }
}
