package com.example.ecommerce.config;

import org.springframework.boot.context.properties.ConfigurationProperties;
import org.springframework.context.annotation.Configuration;

@Configuration
@ConfigurationProperties(prefix = "ghn")
public class GhnConfig {
    private String baseUrl;
    private String token;
    private String shopId;
    private String fromName;
    private String fromPhone;
    private String fromAddress;
    private String fromWardName;
    private String fromDistrictName;
    private String fromProvinceName;
    private String returnPhone;
    private String returnAddress;
    private String defaultToWardCode;
    private int defaultWeight;   // gram
    private int defaultLength;   // cm
    private int defaultWidth;    // cm
    private int defaultHeight;   // cm
    private int serviceTypeId;   // 2: hang nhe, 5: hang nang

    // Getters & Setters
    public String getBaseUrl() { return baseUrl; }
    public void setBaseUrl(String baseUrl) { this.baseUrl = baseUrl; }

    public String getToken() { return token; }
    public void setToken(String token) { this.token = token; }

    public String getShopId() { return shopId; }
    public void setShopId(String shopId) { this.shopId = shopId; }

    public String getFromName() { return fromName; }
    public void setFromName(String fromName) { this.fromName = fromName; }

    public String getFromPhone() { return fromPhone; }
    public void setFromPhone(String fromPhone) { this.fromPhone = fromPhone; }

    public String getFromAddress() { return fromAddress; }
    public void setFromAddress(String fromAddress) { this.fromAddress = fromAddress; }

    public String getFromWardName() { return fromWardName; }
    public void setFromWardName(String fromWardName) { this.fromWardName = fromWardName; }

    public String getFromDistrictName() { return fromDistrictName; }
    public void setFromDistrictName(String fromDistrictName) { this.fromDistrictName = fromDistrictName; }

    public String getFromProvinceName() { return fromProvinceName; }
    public void setFromProvinceName(String fromProvinceName) { this.fromProvinceName = fromProvinceName; }

    public String getReturnPhone() { return returnPhone; }
    public void setReturnPhone(String returnPhone) { this.returnPhone = returnPhone; }

    public String getReturnAddress() { return returnAddress; }
    public void setReturnAddress(String returnAddress) { this.returnAddress = returnAddress; }

    public String getDefaultToWardCode() { return defaultToWardCode; }
    public void setDefaultToWardCode(String defaultToWardCode) { this.defaultToWardCode = defaultToWardCode; }

    public int getDefaultWeight() { return defaultWeight; }
    public void setDefaultWeight(int defaultWeight) { this.defaultWeight = defaultWeight; }

    public int getDefaultLength() { return defaultLength; }
    public void setDefaultLength(int defaultLength) { this.defaultLength = defaultLength; }

    public int getDefaultWidth() { return defaultWidth; }
    public void setDefaultWidth(int defaultWidth) { this.defaultWidth = defaultWidth; }

    public int getDefaultHeight() { return defaultHeight; }
    public void setDefaultHeight(int defaultHeight) { this.defaultHeight = defaultHeight; }

    public int getServiceTypeId() { return serviceTypeId; }
    public void setServiceTypeId(int serviceTypeId) { this.serviceTypeId = serviceTypeId; }
}
