package com.example.ecommerce.repository;

import com.example.ecommerce.entity.ProductItem;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.stereotype.Repository;

import java.util.List;

@Repository
public interface ProductItemRepository extends JpaRepository<ProductItem, Integer> {
    List<ProductItem> findByProductProductId(Integer productId);
}
