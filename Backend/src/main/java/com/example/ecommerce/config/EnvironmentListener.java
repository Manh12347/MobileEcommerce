package com.example.ecommerce.config;

import io.github.cdimascio.dotenv.Dotenv;
import org.springframework.boot.context.event.ApplicationEnvironmentPreparedEvent;
import org.springframework.context.ApplicationListener;
import org.springframework.core.env.ConfigurableEnvironment;
import org.springframework.core.env.MapPropertySource;
import org.springframework.stereotype.Component;

import java.util.HashMap;
import java.util.Map;

/**
 * Load .env file early in the application lifecycle
 * This listener is called before autoconfiguration, ensuring
 * environment variables are available for Spring Boot's auto-config
 */
@Component
public class EnvironmentListener implements ApplicationListener<ApplicationEnvironmentPreparedEvent> {

    @Override
    public void onApplicationEvent(ApplicationEnvironmentPreparedEvent event) {
        ConfigurableEnvironment environment = event.getEnvironment();
        
        // Load .env file
        Dotenv dotenv = Dotenv.configure()
                .ignoreIfMissing()
                .load();
        
        // Convert to Map and add to Spring environment
        Map<String, Object> dotenvMap = new HashMap<>();
        dotenv.entries().forEach(entry -> {
            dotenvMap.put(entry.getKey(), entry.getValue());
            // Also set as system property as backup
            System.setProperty(entry.getKey(), entry.getValue());
        });
        
        // Add to property sources with high priority
        MapPropertySource propertySource = new MapPropertySource("dotenv", dotenvMap);
        environment.getPropertySources().addFirst(propertySource);
    }
}
