package com.example.ecommerce.repository;

import com.example.ecommerce.entity.ProductPromotion;
import com.example.ecommerce.entity.ProductPromotionId;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.stereotype.Repository;

@Repository
public interface ProductPromotionRepository extends JpaRepository<ProductPromotion, ProductPromotionId> {
}
