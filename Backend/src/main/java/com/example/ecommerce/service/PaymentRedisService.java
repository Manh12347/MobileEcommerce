package com.example.ecommerce.service;

import com.example.ecommerce.dto.PaymentCacheInfo;
import com.fasterxml.jackson.core.JsonProcessingException;
import com.fasterxml.jackson.databind.ObjectMapper;
import com.fasterxml.jackson.datatype.jsr310.JavaTimeModule;
import lombok.extern.slf4j.Slf4j;
import org.springframework.data.redis.core.RedisTemplate;
import org.springframework.stereotype.Service;

import java.time.Duration;
import java.time.Instant;
import java.util.ArrayList;
import java.util.List;
import java.util.Map;
import java.util.Optional;
import java.util.concurrent.ConcurrentHashMap;
import java.util.concurrent.TimeUnit;

@Service
@Slf4j
public class PaymentRedisService {

    private static final String KEY_PREFIX_ORDER = "sepay:order:";
    private static final String KEY_PREFIX_GENCODE = "sepay:gencode:";
    private static final int DEFAULT_TTL_MINUTES = 30;

    private final RedisTemplate<String, Object> redisTemplate;
    private final ObjectMapper objectMapper;
    private final Map<String, LocalValue> localPaymentStore = new ConcurrentHashMap<>();

    private record LocalValue(String value, Instant expiresAt) {}

    public PaymentRedisService(RedisTemplate<String, Object> redisTemplate) {
        this.redisTemplate = redisTemplate;
        this.objectMapper = new ObjectMapper();
        this.objectMapper.registerModule(new JavaTimeModule());
    }

    public java.util.Set<String> getLocalKeys(String pattern) {
        java.util.Set<String> keys = new java.util.HashSet<>();
        for (String key : localPaymentStore.keySet()) {
            if (key.startsWith("sepay:order:")) {
                keys.add(key);
            }
        }
        return keys;
    }

    public void cacheOrderPaymentInfo(PaymentCacheInfo info) {
        cacheOrderPaymentInfo(info, DEFAULT_TTL_MINUTES);
    }

    public void cacheOrderPaymentInfo(PaymentCacheInfo info, int ttlMinutes) {
        String orderKey = KEY_PREFIX_ORDER + info.getGencode();
        String gencodeKey = KEY_PREFIX_GENCODE + info.getOrderId();
        
        try {
            String json = objectMapper.writeValueAsString(info);
            redisTemplate.opsForValue().set(orderKey, json, Duration.ofMinutes(ttlMinutes));
            redisTemplate.opsForValue().set(gencodeKey, info.getGencode(), Duration.ofMinutes(ttlMinutes));
            log.info("[PaymentRedis] Cached order payment: gencode={}, orderId={}, ttl={}min",
                    info.getGencode(), info.getOrderId(), ttlMinutes);
        } catch (JsonProcessingException e) {
            log.error("[PaymentRedis] Failed to serialize PaymentCacheInfo", e);
        } catch (Exception e) {
            log.warn("[PaymentRedis] Redis unavailable for caching. Using local store fallback.", e);
            try {
                String json = objectMapper.writeValueAsString(info);
                Instant expiry = Instant.now().plus(Duration.ofMinutes(ttlMinutes));
                localPaymentStore.put(orderKey, new LocalValue(json, expiry));
                localPaymentStore.put(gencodeKey, new LocalValue(info.getGencode(), expiry));
            } catch (Exception ex) {
                log.error("[PaymentRedis] Failed to save to local store fallback", ex);
            }
        }
    }

    public Optional<PaymentCacheInfo> getByGencode(String gencode) {
        try {
            for (String candidate : buildGencodeCandidates(gencode)) {
                String key = KEY_PREFIX_ORDER + candidate;
                Object raw = null;
                try {
                    raw = redisTemplate.opsForValue().get(key);
                } catch (Exception e) {
                    log.warn("[PaymentRedis] Redis unavailable for getByGencode. Falling back to local store.");
                    LocalValue lv = localPaymentStore.get(key);
                    if (lv != null) {
                        if (lv.expiresAt().isBefore(Instant.now())) {
                            localPaymentStore.remove(key);
                        } else {
                            raw = lv.value();
                        }
                    }
                }
                if (raw == null) {
                    continue;
                }

                String json = raw instanceof String ? (String) raw : objectMapper.writeValueAsString(raw);
                PaymentCacheInfo info = objectMapper.readValue(json, PaymentCacheInfo.class);
                log.debug("[PaymentRedis] Cache hit for gencode={}, candidate={}, orderId={}", gencode, candidate, info.getOrderId());
                return Optional.of(info);
            }

            log.debug("[PaymentRedis] Cache miss for gencode={}", gencode);
            return Optional.empty();
        } catch (Exception e) {
            log.error("[PaymentRedis] Failed to deserialize PaymentCacheInfo for gencode={}", gencode, e);
            return Optional.empty();
        }
    }

    public Optional<String> getGencodeByOrderId(Integer orderId) {
        try {
            String key = KEY_PREFIX_GENCODE + orderId;
            Object raw = null;
            try {
                raw = redisTemplate.opsForValue().get(key);
            } catch (Exception e) {
                log.warn("[PaymentRedis] Redis unavailable for getGencodeByOrderId. Falling back to local store.");
                LocalValue lv = localPaymentStore.get(key);
                if (lv != null) {
                    if (lv.expiresAt().isBefore(Instant.now())) {
                        localPaymentStore.remove(key);
                    } else {
                        raw = lv.value();
                    }
                }
            }
            if (raw == null) {
                log.debug("[PaymentRedis] Cache miss for orderId={}", orderId);
                return Optional.empty();
            }
            return Optional.of(raw.toString());
        } catch (Exception e) {
            log.error("[PaymentRedis] Failed to get gencode for orderId={}", orderId, e);
            return Optional.empty();
        }
    }

    public void deleteByGencode(String gencode, Integer orderId) {
        List<String> orderKeys = new ArrayList<>();
        for (String candidate : buildGencodeCandidates(gencode)) {
            orderKeys.add(KEY_PREFIX_ORDER + candidate);
        }
        String gencodeKey = KEY_PREFIX_GENCODE + orderId;

        try {
            redisTemplate.delete(orderKeys);
            if (orderId != null) {
                redisTemplate.delete(gencodeKey);
            }
        } catch (Exception e) {
            log.warn("[PaymentRedis] Redis unavailable for delete. Removing from local store.");
        }

        for (String key : orderKeys) {
            localPaymentStore.remove(key);
        }
        if (gencodeKey != null) {
            localPaymentStore.remove(gencodeKey);
        }

        log.info("[PaymentRedis] Deleted cache: gencode={}, orderId={}", gencode, orderId);
    }

    public boolean exists(String gencode) {
        for (String candidate : buildGencodeCandidates(gencode)) {
            String key = KEY_PREFIX_ORDER + candidate;
            try {
                if (Boolean.TRUE.equals(redisTemplate.hasKey(key))) {
                    return true;
                }
            } catch (Exception e) {
                log.warn("[PaymentRedis] Redis unavailable for exists lookup. Checking local store.");
                LocalValue lv = localPaymentStore.get(key);
                if (lv != null && !lv.expiresAt().isBefore(Instant.now())) {
                    return true;
                }
            }
        }
        return false;
    }

    public void extendTtl(String gencode, Integer orderId, int additionalMinutes) {
        List<String> orderKeys = new ArrayList<>();
        for (String candidate : buildGencodeCandidates(gencode)) {
            orderKeys.add(KEY_PREFIX_ORDER + candidate);
        }
        String gencodeKey = KEY_PREFIX_GENCODE + orderId;

        try {
            for (String orderKey : orderKeys) {
                redisTemplate.expire(orderKey, additionalMinutes, TimeUnit.MINUTES);
            }
            if (orderId != null) {
                redisTemplate.expire(gencodeKey, additionalMinutes, TimeUnit.MINUTES);
            }
        } catch (Exception e) {
            log.warn("[PaymentRedis] Redis unavailable for extendTtl. Updating local store TTL.");
        }

        Instant newExpiry = Instant.now().plus(Duration.ofMinutes(additionalMinutes));
        for (String orderKey : orderKeys) {
            LocalValue lv = localPaymentStore.get(orderKey);
            if (lv != null) {
                localPaymentStore.put(orderKey, new LocalValue(lv.value(), newExpiry));
            }
        }
        LocalValue lvGen = localPaymentStore.get(gencodeKey);
        if (lvGen != null) {
            localPaymentStore.put(gencodeKey, new LocalValue(lvGen.value(), newExpiry));
        }

        log.info("[PaymentRedis] Extended TTL for gencode={} by {}min", gencode, additionalMinutes);
    }

    private List<String> buildGencodeCandidates(String gencode) {
        List<String> candidates = new ArrayList<>();
        if (gencode == null || gencode.isBlank()) {
            return candidates;
        }

        candidates.add(gencode);

        if (gencode.startsWith("ORDER_") && gencode.length() > "ORDER_".length()) {
            candidates.add("ORDER" + gencode.substring("ORDER_".length()));
        } else if (gencode.startsWith("ORDER") && !gencode.startsWith("ORDER_")) {
            String suffix = gencode.substring("ORDER".length());
            if (!suffix.isBlank()) {
                candidates.add("ORDER_" + suffix);
            }
        }

        return candidates.stream().distinct().toList();
    }
}
