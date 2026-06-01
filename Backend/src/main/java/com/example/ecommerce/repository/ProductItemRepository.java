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
           "pi.description, pi.specifications, pi.main_image_url, " +
           "p.brand_id, b.name as brand_name, b.country as brand_country, b.status as brand_status, " +
           "p.category_id, c.name as category_name, c.status as category_status " +
           "FROM product_items pi " +
           "LEFT JOIN products p ON pi.product_id = p.product_id " +
           "LEFT JOIN brands b ON p.brand_id = b.brand_id " +
           "LEFT JOIN categories c ON p.category_id = c.category_id " +
           "WHERE pi.sale_price IS NOT NULL " +
           "ORDER BY pi.product_item_id DESC",
           countQuery = "SELECT COUNT(*) FROM product_items WHERE sale_price IS NOT NULL",
           nativeQuery = true)
    Page<Object[]> findDiscountedItems(Pageable pageable);

    @Query(value = "SELECT pi.product_item_id, pi.sku, pi.stock_quantity, pi.status, pi.price, pi.sale_price, " +
           "pi.created_on, pi.product_id, p.name as product_name, " +
           "(SELECT COUNT(*) FROM serial_numbers sn WHERE sn.product_item_id = pi.product_item_id AND sn.status = 'sold') as sold_count, " +
           "pi.description, pi.specifications, pi.main_image_url, " +
           "p.brand_id, b.name as brand_name, b.country as brand_country, b.status as brand_status, " +
           "p.category_id, c.name as category_name, c.status as category_status " +
           "FROM product_items pi " +
           "LEFT JOIN products p ON pi.product_id = p.product_id " +
           "LEFT JOIN brands b ON p.brand_id = b.brand_id " +
           "LEFT JOIN categories c ON p.category_id = c.category_id " +
           "ORDER BY pi.product_item_id DESC",
           countQuery = "SELECT COUNT(*) FROM product_items",
           nativeQuery = true)
    Page<Object[]> findAllForListWithSoldCount(Pageable pageable);

    @Query(value = "SELECT pi.product_item_id, pi.sku, pi.stock_quantity, pi.status, pi.price, pi.sale_price, " +
           "pi.created_on, pi.product_id, p.name as product_name, " +
           "pi.description, pi.specifications, pi.main_image_url, " +
           "p.brand_id, b.name as brand_name, b.country as brand_country, b.status as brand_status, " +
           "p.category_id, c.name as category_name, c.status as category_status " +
           "FROM product_items pi " +
           "LEFT JOIN products p ON pi.product_id = p.product_id " +
           "LEFT JOIN brands b ON p.brand_id = b.brand_id " +
           "LEFT JOIN categories c ON p.category_id = c.category_id " +
           "WHERE (:brandId IS NULL OR p.brand_id = :brandId) " +
           "AND (:categoryId IS NULL OR p.category_id = :categoryId) " +
           "AND (:productId IS NULL OR pi.product_id = :productId) " +
           "AND (:productItemId IS NULL OR pi.product_item_id = :productItemId) " +
           "AND (:minPrice IS NULL OR COALESCE(pi.sale_price, pi.price) >= :minPrice) " +
           "AND (:maxPrice IS NULL OR COALESCE(pi.sale_price, pi.price) <= :maxPrice) " +
           "ORDER BY " +
           "CASE WHEN :sortBy = 'price' AND :sortDir = 'asc' THEN COALESCE(pi.sale_price, pi.price) END ASC, " +
           "CASE WHEN :sortBy = 'price' AND :sortDir = 'desc' THEN COALESCE(pi.sale_price, pi.price) END DESC, " +
           "CASE WHEN :sortBy = 'brand' AND :sortDir = 'asc' THEN LOWER(b.name) END ASC, " +
           "CASE WHEN :sortBy = 'brand' AND :sortDir = 'desc' THEN LOWER(b.name) END DESC, " +
           "CASE WHEN :sortBy = 'category' AND :sortDir = 'asc' THEN LOWER(c.name) END ASC, " +
           "CASE WHEN :sortBy = 'category' AND :sortDir = 'desc' THEN LOWER(c.name) END DESC, " +
           "CASE WHEN :sortBy = 'product' AND :sortDir = 'asc' THEN LOWER(p.name) END ASC, " +
           "CASE WHEN :sortBy = 'product' AND :sortDir = 'desc' THEN LOWER(p.name) END DESC, " +
           "CASE WHEN :sortBy = 'newest' AND :sortDir = 'asc' THEN pi.created_on END ASC, " +
           "CASE WHEN :sortBy = 'newest' AND :sortDir = 'desc' THEN pi.created_on END DESC, " +
           "pi.product_item_id DESC",
           countQuery = "SELECT COUNT(*) " +
                        "FROM product_items pi " +
                        "LEFT JOIN products p ON pi.product_id = p.product_id " +
                        "WHERE (:brandId IS NULL OR p.brand_id = :brandId) " +
                        "AND (:categoryId IS NULL OR p.category_id = :categoryId) " +
                        "AND (:productId IS NULL OR pi.product_id = :productId) " +
                                                        "AND (:productItemId IS NULL OR pi.product_item_id = :productItemId) " +
                        "AND (:minPrice IS NULL OR COALESCE(pi.sale_price, pi.price) >= :minPrice) " +
                        "AND (:maxPrice IS NULL OR COALESCE(pi.sale_price, pi.price) <= :maxPrice)",
           nativeQuery = true)
    Page<Object[]> findForListWithFilters(
            @Param("brandId") Integer brandId,
            @Param("categoryId") Integer categoryId,
            @Param("productId") Integer productId,
                            @Param("productItemId") Integer productItemId,
            @Param("minPrice") java.math.BigDecimal minPrice,
            @Param("maxPrice") java.math.BigDecimal maxPrice,
            @Param("sortBy") String sortBy,
            @Param("sortDir") String sortDir,
            Pageable pageable
    );

    @Query("SELECT pi FROM ProductItem pi JOIN FETCH pi.product WHERE pi.product.productId = :productId")
    List<ProductItem> findByProductIdWithProduct(@Param("productId") Integer productId);
}
