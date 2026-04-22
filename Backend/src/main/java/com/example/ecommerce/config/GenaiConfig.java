package com.example.ecommerce.config;

import org.springframework.boot.context.properties.ConfigurationProperties;
import org.springframework.context.annotation.Configuration;

@Configuration
@ConfigurationProperties(prefix = "genai")
public class GenaiConfig {
    private String apiEmbed;
    private String apiDecision;
    private String apiChat;

    public String getApiEmbed() {
        return apiEmbed;
    }

    public void setApiEmbed(String apiEmbed) {
        this.apiEmbed = apiEmbed;
    }

    public String getApiDecision() {
        return apiDecision;
    }

    public void setApiDecision(String apiDecision) {
        this.apiDecision = apiDecision;
    }

    public String getApiChat() {
        return apiChat;
    }

    public void setApiChat(String apiChat) {
        this.apiChat = apiChat;
    }
}
