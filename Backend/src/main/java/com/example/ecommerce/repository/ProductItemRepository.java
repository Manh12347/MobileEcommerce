package com.example.ecommerce.repository;

import com.example.ecommerce.entity.ProductItem;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.Query;
import org.springframework.data.repository.query.Param;
import org.springframework.stereotype.Repository;

import java.util.List;
import java.util.Optional;

@Repository
public interface ProductItemRepository extends JpaRepository<ProductItem, Integer> {
    
    @Query("SELECT pi FROM ProductItem pi WHERE pi.product.productId = :productId")
    List<ProductItem> findByProductProductId(@Param("productId") Integer productId);

    @Query("SELECT DISTINCT pi FROM ProductItem pi " +
           "LEFT JOIN FETCH pi.serials " +
           "LEFT JOIN FETCH pi.product")
    List<ProductItem> findAllWithSerialsAndProduct();

    @Query("SELECT pi FROM ProductItem pi " +
           "LEFT JOIN FETCH pi.serials " +
           "LEFT JOIN FETCH pi.product " +
           "WHERE pi.productItemId = :id")
    Optional<ProductItem> findByIdWithSerialsAndProduct(@Param("id") Integer id);

    @Query("SELECT DISTINCT pi FROM ProductItem pi " +
           "LEFT JOIN FETCH pi.serials " +
           "LEFT JOIN FETCH pi.product " +
           "WHERE pi.product.productId = :productId")
    List<ProductItem> findByProductProductIdWithSerialsAndProduct(@Param("productId") Integer productId);
}
