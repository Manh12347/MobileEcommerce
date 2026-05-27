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
        if (request.getDiscountCost() != null) {
            promotion.setDiscountCost(request.getDiscountCost().doubleValue());
        }
        if (request.getStartDate() != null && !request.getStartDate().isBlank()) {
            promotion.setStartDate(LocalDateTime.parse(request.getStartDate()));
        }
        if (request.getEndDate() != null && !request.getEndDate().isBlank()) {
            promotion.setEndDate(LocalDateTime.parse(request.getEndDate()));
        }
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
        if (request.getDiscountCost() != null) promotion.setDiscountCost(request.getDiscountCost().doubleValue());
        if (request.getStartDate() != null && !request.getStartDate().isBlank()) {
            promotion.setStartDate(LocalDateTime.parse(request.getStartDate()));
        }
        if (request.getEndDate() != null && !request.getEndDate().isBlank()) {
            promotion.setEndDate(LocalDateTime.parse(request.getEndDate()));
        }
        if (request.getIsActive() != null) promotion.setIsActive(request.getIsActive());

        Promotion saved = promotionRepository.save(promotion);

        // Nếu promotion bị tắt, xóa sale_price của tất cả biến thể đang áp dụng
        if (Boolean.FALSE.equals(saved.getIsActive())) {
            clearSalePricesForPromotion(promotionId);
        }
        // Nếu promotion được kích hoạt lại, apply lại
        else if (Boolean.TRUE.equals(saved.getIsActive())) {
            reapplyPromotionToLinkedProducts(promotionId);
        }

        return saved;
    }

    private void clearSalePricesForPromotion(Integer promotionId) {
        List<ProductPromotion> links = productPromotionRepository.findByPromotionPromotionId(promotionId);
        for (ProductPromotion link : links) {
            clearSalePriceForProduct(link.getProduct().getProductId());
        }
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
        ProductPromotionId ppId = new ProductPromotionId();
        ppId.setProductId(productId);
        ppId.setPromotionId(promotionId);
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
        ProductPromotionId ppId = new ProductPromotionId();
        ppId.setProductId(productId);
        ppId.setPromotionId(promotionId);
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
            BigDecimal salePrice = price.subtract(BigDecimal.valueOf(promotion.getDiscountCost()));
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
        if (promotion.getDiscountCost() != null) {
            dto.setDiscountCost(BigDecimal.valueOf(promotion.getDiscountCost()));
        }
        if (promotion.getStartDate() != null) {
            dto.setStartDate(promotion.getStartDate().toString());
        }
        if (promotion.getEndDate() != null) {
            dto.setEndDate(promotion.getEndDate().toString());
        }
        dto.setIsActive(promotion.getIsActive());
        return dto;
    }

    public List<PromotionProductItemDto> getProductItemsByPromotionId(Integer promotionId) {
        List<ProductPromotion> links = productPromotionRepository.findByPromotionPromotionId(promotionId);
        List<PromotionProductItemDto> result = new java.util.ArrayList<>();
        for (ProductPromotion pp : links) {
            List<ProductItem> items = productItemRepository.findByProductIdWithProduct(pp.getProduct().getProductId());
            for (ProductItem pi : items) {
                if (pi.getSalePrice() == null) continue;
                PromotionProductItemDto dto = new PromotionProductItemDto();
                dto.setProductItemId(pi.getProductItemId());
                dto.setSku(pi.getSku());
                dto.setProductName(pi.getProduct() != null ? pi.getProduct().getName() : "");
                dto.setProductId(pp.getProduct().getProductId());
                dto.setPromotionId(promotionId);
                dto.setSalePrice(pi.getSalePrice());
                dto.setOriginalPrice(pi.getPrice());
                result.add(dto);
            }
        }
        return result;
    }

    @Transactional
    public void applyPromotionToItems(List<Integer> productItemIds, Integer promotionId) {
        Promotion promotion = promotionRepository.findById(promotionId)
                .orElseThrow(() -> new RuntimeException("Không tìm thấy promotion: " + promotionId));

        // Gom theo productId để tạo link ProductPromotion đúng
        java.util.Map<Integer, java.util.List<Integer>> byProduct = new java.util.LinkedHashMap<>();
        for (Integer itemId : productItemIds) {
            ProductItem item = productItemRepository.findById(itemId).orElse(null);
            if (item == null || item.getPrice() == null) continue;
            int pid = item.getProduct().getProductId();
            byProduct.computeIfAbsent(pid, k -> new java.util.ArrayList<>()).add(itemId);
        }

        for (java.util.Map.Entry<Integer, java.util.List<Integer>> entry : byProduct.entrySet()) {
            Integer productId = entry.getKey();
            // Tạo / lấy link ProductPromotion
            ProductPromotionId ppId = new ProductPromotionId();
            ppId.setProductId(productId);
            ppId.setPromotionId(promotionId);
            if (!productPromotionRepository.existsById(ppId)) {
                ProductPromotion pp = new ProductPromotion();
                pp.setId(ppId);
                pp.setProduct(productRepository.findById(productId).orElseThrow());
                pp.setPromotion(promotion);
                productPromotionRepository.save(pp);
            }

            // Tính sale price
            for (Integer itemId : entry.getValue()) {
                ProductItem item = productItemRepository.findById(itemId).orElse(null);
                if (item == null || item.getPrice() == null) continue;
                BigDecimal salePrice = calculateSalePrice(item.getPrice(), promotion);
                item.setSalePrice(salePrice);
                productItemRepository.save(item);
            }
        }
    }

    @Transactional
    public void removePromotionFromItems(List<Integer> productItemIds) {
        for (Integer itemId : productItemIds) {
            ProductItem item = productItemRepository.findById(itemId).orElse(null);
            if (item == null) continue;
            item.setSalePrice(null);
            productItemRepository.save(item);
        }
    }
}
