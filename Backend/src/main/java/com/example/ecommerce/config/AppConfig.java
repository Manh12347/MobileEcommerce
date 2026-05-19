package com.example.ecommerce.config;

import org.springframework.boot.context.properties.ConfigurationProperties;
import org.springframework.context.annotation.Configuration;

@Configuration
@ConfigurationProperties(prefix = "app")
public class AppConfig {
    private String domain;
    private String pythonApiUrl;

    public String getDomain() {
        return domain;
    }

    public void setDomain(String domain) {
        this.domain = domain;
    }

    public String getPythonApiUrl() {
        return pythonApiUrl;
    }

    public void setPythonApiUrl(String pythonApiUrl) {
        this.pythonApiUrl = pythonApiUrl;
    }
}
