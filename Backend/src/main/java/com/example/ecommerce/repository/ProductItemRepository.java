package com.example.ecommerce.repository;

import com.example.ecommerce.entity.ProductItem;
import org.springframework.data.domain.Page;
import org.springframework.data.domain.Pageable;
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

    @Query("SELECT pi FROM ProductItem pi " +
           "LEFT JOIN FETCH pi.serials " +
           "LEFT JOIN FETCH pi.product " +
           "WHERE LOWER(pi.sku) = LOWER(:sku)")
    Optional<ProductItem> findBySkuWithSerialsAndProduct(@Param("sku") String sku);

    @Query("SELECT DISTINCT pi FROM ProductItem pi " +
           "LEFT JOIN FETCH pi.serials " +
           "LEFT JOIN FETCH pi.product " +
           "WHERE pi.product.productId = :productId")
    List<ProductItem> findByProductProductIdWithSerialsAndProduct(@Param("productId") Integer productId);
    
    // Query cho list view - KHÔNG load serials để tăng performance
    @Query("SELECT pi FROM ProductItem pi " +
           "LEFT JOIN FETCH pi.product " +
           "WHERE pi.productItemId = :id")
    Optional<ProductItem> findByIdWithProductOnly(@Param("id") Integer id);

    // Lấy product items cho list view với sold count (1 query thay vì N+1)
    @Query(value = "SELECT pi.product_item_id, pi.sku, pi.stock_quantity, pi.status, pi.price, pi.sale_price, " +
           "pi.created_on, pi.product_id, p.name as product_name, " +
           "(SELECT COUNT(*) FROM serial_numbers sn WHERE sn.product_item_id = pi.product_item_id AND sn.status = 'sold') as sold_count, " +
           "pi.description, pi.specifications, pi.main_image_url " +
           "FROM product_items pi " +
           "LEFT JOIN products p ON pi.product_id = p.product_id " +
           "WHERE pi.sale_price IS NOT NULL " +
           "ORDER BY pi.product_item_id DESC",
           countQuery = "SELECT COUNT(*) FROM product_items WHERE sale_price IS NOT NULL",
           nativeQuery = true)
    Page<Object[]> findDiscountedItems(Pageable pageable);

    @Query(value = "SELECT pi.product_item_id, pi.sku, pi.stock_quantity, pi.status, pi.price, pi.sale_price, " +
           "pi.created_on, pi.product_id, p.name as product_name, " +
           "(SELECT COUNT(*) FROM serial_numbers sn WHERE sn.product_item_id = pi.product_item_id AND sn.status = 'sold') as sold_count, " +
           "pi.description, pi.specifications, pi.main_image_url " +
           "FROM product_items pi " +
           "LEFT JOIN products p ON pi.product_id = p.product_id " +
           "ORDER BY pi.product_item_id DESC",
           countQuery = "SELECT COUNT(*) FROM product_items",
           nativeQuery = true)
    Page<Object[]> findAllForListWithSoldCount(Pageable pageable);

    @Query("SELECT pi FROM ProductItem pi JOIN FETCH pi.product WHERE pi.product.productId = :productId")
    List<ProductItem> findByProductIdWithProduct(@Param("productId") Integer productId);
}
