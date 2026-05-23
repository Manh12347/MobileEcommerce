package com.example.ecommerce.util;

import com.example.ecommerce.security.JwtAuthenticationFilter;
import jakarta.servlet.http.HttpServletRequest;
import org.springframework.web.context.request.RequestContextHolder;
import org.springframework.web.context.request.ServletRequestAttributes;

public class SecurityUtil {

    public static Integer getCurrentAccountId() {
        ServletRequestAttributes attributes = (ServletRequestAttributes) RequestContextHolder.getRequestAttributes();
        if (attributes == null) {
            return null;
        }
        HttpServletRequest request = attributes.getRequest();
        Object accountIdObj = request.getAttribute(JwtAuthenticationFilter.ACCOUNT_ID_ATTRIBUTE);
        if (accountIdObj instanceof Integer) {
            return (Integer) accountIdObj;
        }
        return null;
    }

    public static boolean isAuthenticated() {
        return getCurrentAccountId() != null;
    }

    public static String getCurrentRole() {
        ServletRequestAttributes attributes = (ServletRequestAttributes) RequestContextHolder.getRequestAttributes();
        if (attributes == null) {
            return null;
        }
        HttpServletRequest request = attributes.getRequest();
        Object roleObj = request.getAttribute(JwtAuthenticationFilter.ROLE_ATTRIBUTE);
        if (roleObj instanceof String) {
            return (String) roleObj;
        }
        return null;
    }

    public static boolean isStaff() {
        String role = getCurrentRole();
        return "staff".equals(role) || "admin".equals(role);
    }
}
