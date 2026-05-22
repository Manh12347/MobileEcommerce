package com.example.ecommerce.config;

import org.springframework.boot.context.properties.ConfigurationProperties;
import org.springframework.context.annotation.Configuration;
import java.math.BigDecimal;

@Configuration
@ConfigurationProperties(prefix = "hooks")
public class HookConfig {
    private String apiKey;
    private String gateway = "Sepay";
    private BigDecimal amountTolerance = new BigDecimal("1000"); // VND tolerance

    public String getApiKey() {
        return apiKey;
    }

    public void setApiKey(String apiKey) {
        this.apiKey = apiKey;
    }

    public String getGateway() {
        return gateway;
    }

    public void setGateway(String gateway) {
        this.gateway = gateway;
    }

    public BigDecimal getAmountTolerance() {
        return amountTolerance;
    }

    public void setAmountTolerance(BigDecimal amountTolerance) {
        this.amountTolerance = amountTolerance;
    }
}
