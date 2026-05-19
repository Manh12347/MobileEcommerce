package com.example.ecommerce.service;

import com.example.ecommerce.config.AppConfig;
import lombok.extern.slf4j.Slf4j;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.http.*;
import org.springframework.stereotype.Service;
import org.springframework.web.client.RestTemplate;

import java.util.HashMap;
import java.util.Map;

@Service
@Slf4j
public class EmbeddingService {

    @Autowired
    private AppConfig appConfig;

    private final RestTemplate restTemplate = new RestTemplate();

    public boolean createEmbedding(Integer productItemId) {
        try {
            String pythonUrl = appConfig.getPythonApiUrl() + "/update-vector-by-product-id";

            HttpHeaders headers = new HttpHeaders();
            headers.setContentType(MediaType.APPLICATION_JSON);

            Map<String, Object> body = new HashMap<>();
            body.put("product_item_id", productItemId);

            HttpEntity<Map<String, Object>> request = new HttpEntity<>(body, headers);

            ResponseEntity<Map> response = restTemplate.postForEntity(pythonUrl, request, Map.class);

            if (response.getStatusCode() == HttpStatus.OK && response.getBody() != null) {
                String status = (String) response.getBody().get("status");
                if ("success".equals(status)) {
                    log.info("Embedding created successfully for productItemId: {}", productItemId);
                    return true;
                }
            }
            log.warn("Embedding creation returned non-success for productItemId: {}", productItemId);
            return false;
        } catch (Exception e) {
            log.error("Error creating embedding for productItemId {}: {}", productItemId, e.getMessage());
            return false;
        }
    }
}
