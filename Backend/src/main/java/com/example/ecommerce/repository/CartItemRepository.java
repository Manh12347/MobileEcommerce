package com.example.ecommerce.repository;

import com.example.ecommerce.entity.CartItem;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.Query;
import org.springframework.data.repository.query.Param;
import org.springframework.stereotype.Repository;

import java.util.List;
import java.util.Optional;

@Repository
public interface CartItemRepository extends JpaRepository<CartItem, Integer> {

    List<CartItem> findByCartCartId(Integer cartId);

    Optional<CartItem> findByCartCartIdAndProductItemProductItemId(Integer cartId, Integer productItemId);

    @Query("SELECT ci FROM CartItem ci " +
           "JOIN FETCH ci.productItem pi " +
           "JOIN FETCH pi.product " +
           "WHERE ci.cart.cartId = :cartId")
    List<CartItem> findByCartIdWithDetails(@Param("cartId") Integer cartId);
}
