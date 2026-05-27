package com.example.ecommerce.service;

import com.example.ecommerce.dto.*;
import com.example.ecommerce.entity.ProductItem;
import com.example.ecommerce.entity.ProductPromotion;
import com.example.ecommerce.entity.ProductPromotionId;
import com.example.ecommerce.entity.Promotion;
import com.example.ecommerce.repository.ProductItemRepository;
import com.example.ecommerce.repository.ProductPromotionRepository;
import com.example.ecommerce.repository.ProductRepository;
import com.example.ecommerce.repository.PromotionRepository;
import lombok.RequiredArgsConstructor;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.math.BigDecimal;
import java.math.RoundingMode;
import java.time.LocalDateTime;
import java.util.List;
import java.util.Optional;

import lombok.Data;

@Service
@RequiredArgsConstructor
@Transactional
public class PromotionService {

    private final PromotionRepository promotionRepository;
    private final ProductPromotionRepository productPromotionRepository;
    private final ProductItemRepository productItemRepository;
    private final ProductRepository productRepository;

    // ==================== CRUD ====================

    public Promotion createPromotion(CreatePromotionRequest request) {
        Promotion promotion = new Promotion();
        promotion.setPromotionName(request.getPromotionName());
        promotion.setDiscountPercent(request.getDiscountPercent());
        promotion.setDiscountCost(request.getDiscountCost());
        promotion.setStartDate(request.getStartDate());
        promotion.setEndDate(request.getEndDate());
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

    public Promotion updatePromotion(Integer promotionId, UpdatePromotionRequest request) {
        Promotion promotion = promotionRepository.findById(promotionId)
                .orElseThrow(() -> new RuntimeException("Không tìm thấy promotion: " + promotionId));

        if (request.getPromotionName() != null) promotion.setPromotionName(request.getPromotionName());
        if (request.getDiscountPercent() != null) promotion.setDiscountPercent(request.getDiscountPercent());
        if (request.getDiscountCost() != null) promotion.setDiscountCost(request.getDiscountCost());
        if (request.getStartDate() != null) promotion.setStartDate(request.getStartDate());
        if (request.getEndDate() != null) promotion.setEndDate(request.getEndDate());
        if (request.getIsActive() != null) promotion.setIsActive(request.getIsActive());

        Promotion saved = promotionRepository.save(promotion);

        // Nếu promotion đang active, apply lại cho tất cả product liên quan
        if (Boolean.TRUE.equals(saved.getIsActive())) {
            reapplyPromotionToLinkedProducts(promotionId);
        }

        return saved;
    }

    public void deletePromotion(Integer promotionId) {
        // Xóa hết product_promotion trước (on delete cascade đã setup)
        List<ProductPromotion> links = productPromotionRepository.findByPromotionPromotionId(promotionId);
        for (ProductPromotion link : links) {
            // Xóa sale_price của các product_item liên quan
            clearSalePriceForProduct(link.getProduct().getProductId());
        }
        productPromotionRepository.deleteAll(links);
        promotionRepository.deleteById(promotionId);
    }

    // ==================== APPLY / REMOVE ====================

    public void applyPromotionToProduct(Integer productId, Integer promotionId) {
        Promotion promotion = promotionRepository.findById(promotionId)
                .orElseThrow(() -> new RuntimeException("Không tìm thấy promotion: " + promotionId));

        if (!productRepository.existsById(productId)) {
            throw new RuntimeException("Không tìm thấy product: " + productId);
        }

        // Link promotion -> product
        ProductPromotionId ppId = new ProductPromotionId(productId, promotionId);
        if (!productPromotionRepository.existsById(ppId)) {
            ProductPromotion pp = new ProductPromotion();
            pp.setId(ppId);
            pp.setProduct(promotion.getIsActive() != null && promotion.getIsActive()
                    ? productRepository.findById(productId).orElseThrow()
                    : null);
            pp.setPromotion(promotion);
            // Lấy lại product đúng entity
            pp.setProduct(productRepository.findById(productId).orElseThrow());
            productPromotionRepository.save(pp);
        }

        // Tính và cập nhật sale_price cho tất cả product_items
        applySalePriceToProductItems(productId, promotion);
    }

    public void removePromotionFromProduct(Integer productId, Integer promotionId) {
        ProductPromotionId ppId = new ProductPromotionId(productId, promotionId);
        if (!productPromotionRepository.existsById(ppId)) {
            throw new RuntimeException("Product này không có promotion này");
        }

        productPromotionRepository.deleteById(ppId);
        clearSalePriceForProduct(productId);
    }

    // ==================== PRIVATE HELPERS ====================

    private void applySalePriceToProductItems(Integer productId, Promotion promotion) {
        List<ProductItem> items = productItemRepository.findByProductProductId(productId);
        for (ProductItem item : items) {
            if (item.getPrice() == null) continue;

            BigDecimal salePrice = calculateSalePrice(item.getPrice(), promotion);
            item.setSalePrice(salePrice);
            productItemRepository.save(item);
        }
    }

    private BigDecimal calculateSalePrice(BigDecimal price, Promotion promotion) {
        if (promotion.getDiscountCost() != null && promotion.getDiscountCost() > 0) {
            // Giảm số tiền cố định
            BigDecimal salePrice = price.subtract(promotion.getDiscountCost());
            return salePrice.compareTo(BigDecimal.ZERO) < 0 ? BigDecimal.ZERO : salePrice.setScale(2, RoundingMode.HALF_UP);
        }

        if (promotion.getDiscountPercent() != null && promotion.getDiscountPercent() > 0) {
            // Giảm %
            BigDecimal discount = price.multiply(BigDecimal.valueOf(promotion.getDiscountPercent()))
                    .divide(BigDecimal.valueOf(100), 2, RoundingMode.HALF_UP);
            return price.subtract(discount).setScale(2, RoundingMode.HALF_UP);
        }

        return null; // Không có discount nào
    }

    private void clearSalePriceForProduct(Integer productId) {
        List<ProductItem> items = productItemRepository.findByProductProductId(productId);
        for (ProductItem item : items) {
            item.setSalePrice(null);
            productItemRepository.save(item);
        }
    }

    private void reapplyPromotionToLinkedProducts(Integer promotionId) {
        List<ProductPromotion> links = productPromotionRepository.findByPromotionPromotionId(promotionId);
        Promotion promotion = promotionRepository.findById(promotionId).orElseThrow();
        for (ProductPromotion link : links) {
            applySalePriceToProductItems(link.getProduct().getProductId(), promotion);
        }
    }

    // ==================== DTO MAPPING ====================

    public PromotionResponse toResponse(Promotion promotion) {
        PromotionResponse dto = new PromotionResponse();
        dto.setPromotionId(promotion.getPromotionId());
        dto.setPromotionName(promotion.getPromotionName());
        dto.setDiscountPercent(promotion.getDiscountPercent());
        dto.setDiscountCost(promotion.getDiscountCost());
        dto.setStartDate(promotion.getStartDate());
        dto.setEndDate(promotion.getEndDate());
        dto.setIsActive(promotion.getIsActive());
        return dto;
    }

    public List<PromotionProductDto> getProductsByPromotionId(Integer promotionId) {
        return productPromotionRepository.findByPromotionPromotionId(promotionId).stream()
                .map(pp -> {
                    PromotionProductDto dto = new PromotionProductDto();
                    dto.setProductId(pp.getProduct().getProductId());
                    dto.setProductName(pp.getProduct().getName());
                    dto.setPromotionId(promotionId);
                    dto.setPromotionName(pp.getPromotion().getPromotionName());
                    dto.setDiscountPercent(pp.getPromotion().getDiscountPercent());
                    dto.setDiscountCost(pp.getPromotion().getDiscountCost());
                    return dto;
                })
                .toList();
    }

    @Data
    public static class PromotionProductDto {
        private Integer productId;
        private String productName;
        private Integer promotionId;
        private String promotionName;
        private Double discountPercent;
        private BigDecimal discountCost;
    }
}
