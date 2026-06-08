package com.example.ecommerce.repository;

import com.example.ecommerce.entity.OrderItem;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.Query;
import org.springframework.data.repository.query.Param;
import org.springframework.stereotype.Repository;

import java.util.List;

@Repository
public interface OrderItemRepository extends JpaRepository<OrderItem, Integer> {
    List<OrderItem> findByOrderOrderId(Integer orderId);

    @Query("""
            SELECT oi FROM OrderItem oi
            JOIN FETCH oi.order ord
            JOIN FETCH oi.productItem pi
            LEFT JOIN FETCH pi.product product
            WHERE ord.account.accountId = :accountId
              AND ord.status <> 'cancelled'
            ORDER BY ord.createdOn DESC
            """)
    List<OrderItem> findPurchasedItemsByAccountId(@Param("accountId") Integer accountId);
}
