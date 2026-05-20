package com.example.ecommerce.util;

import jakarta.persistence.AttributeConverter;
import jakarta.persistence.Converter;

/**
 * Converts String to/from JSONB for PostgreSQL.
 * Wraps plain strings in JSON if needed.
 */
@Converter
public class JsonbConverter implements AttributeConverter<String, String> {

    @Override
    public String convertToDatabaseColumn(String attribute) {
        if (attribute == null) {
            return null;
        }
        
        String trimmed = attribute.trim();
        if (trimmed.isEmpty()) {
            return null;
        }
        
        // Already valid JSON (object or array)
        if (trimmed.startsWith("{") || trimmed.startsWith("[")) {
            return trimmed;
        }
        
        // Already a JSON string with quotes
        if (trimmed.startsWith("\"") && trimmed.endsWith("\"") && trimmed.length() > 1) {
            return trimmed;
        }
        
        // Boolean or null literals
        if (trimmed.equals("true") || trimmed.equals("false") || trimmed.equals("null")) {
            return trimmed;
        }
        
        // Numbers
        if (isNumeric(trimmed)) {
            return trimmed;
        }
        
        // Plain string - wrap as JSON string with proper escaping
        String escaped = trimmed
                .replace("\\", "\\\\")      // Escape backslash first
                .replace("\"", "\\\"")      // Escape quotes
                .replace("\n", "\\n")       // Escape newlines
                .replace("\r", "\\r")       // Escape carriage returns
                .replace("\t", "\\t");      // Escape tabs
        
        return "\"" + escaped + "\"";
    }

    @Override
    public String convertToEntityAttribute(String dbData) {
        if (dbData == null) {
            return null;
        }
        
        String trimmed = dbData.trim();
        if (trimmed.isEmpty()) {
            return null;
        }
        
        // If it's a JSON string (starts and ends with quotes), unwrap it
        if (trimmed.startsWith("\"") && trimmed.endsWith("\"") && trimmed.length() > 1 && !trimmed.startsWith("{")) {
            try {
                String unescaped = trimmed.substring(1, trimmed.length() - 1)
                        .replace("\\t", "\t")       // Unescape tabs
                        .replace("\\r", "\r")       // Unescape carriage returns
                        .replace("\\n", "\n")       // Unescape newlines
                        .replace("\\\"", "\"")      // Unescape quotes
                        .replace("\\\\", "\\");     // Unescape backslash last
                return unescaped;
            } catch (Exception e) {
                return trimmed;
            }
        }
        
        return trimmed;
    }
    
    private boolean isNumeric(String str) {
        try {
            Double.parseDouble(str);
            return true;
        } catch (NumberFormatException e) {
            return false;
        }
    }
}
