package com.example.ecommerce.service;

import com.example.ecommerce.entity.Promotion;
import com.example.ecommerce.repository.PromotionRepository;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.time.LocalDateTime;
import java.util.List;
import java.util.Optional;

@Service
@Transactional
public class PromotionService {

    @Autowired
    private PromotionRepository promotionRepository;

    public Promotion createPromotion(String promotionName, Double discountPercent,
                                     LocalDateTime startDate, LocalDateTime endDate) {
        Promotion promotion = new Promotion();
        promotion.setPromotionName(promotionName);
        promotion.setDiscountPercent(discountPercent);
        promotion.setStartDate(startDate);
        promotion.setEndDate(endDate);
        promotion.setIsActive(true);

        return promotionRepository.save(promotion);
    }

    public Promotion getPromotion(Integer promotionId) {
        return promotionRepository.findById(promotionId).orElse(null);
    }

    public List<Promotion> getAllPromotions() {
        return promotionRepository.findAll();
    }

    public List<Promotion> getActivePromotions() {
        return promotionRepository.findByIsActiveTrue();
    }

    public Promotion updatePromotion(Integer promotionId, String promotionName,
                                     Double discountPercent, Boolean isActive) {
        Optional<Promotion> promotionOpt = promotionRepository.findById(promotionId);
        if (!promotionOpt.isPresent()) return null;

        Promotion promotion = promotionOpt.get();
        if (promotionName != null) promotion.setPromotionName(promotionName);
        if (discountPercent != null) promotion.setDiscountPercent(discountPercent);
        if (isActive != null) promotion.setIsActive(isActive);

        return promotionRepository.save(promotion);
    }

    public void deletePromotion(Integer promotionId) {
        promotionRepository.deleteById(promotionId);
    }
}
