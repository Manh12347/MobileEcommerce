package com.example.ecommerce.repository;

import com.example.ecommerce.entity.SoldSerial;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.Query;
import org.springframework.data.repository.query.Param;
import org.springframework.stereotype.Repository;

import java.util.List;

@Repository
public interface SoldSerialRepository extends JpaRepository<SoldSerial, Integer> {

    List<SoldSerial> findByOrderItemOrderItemId(Integer orderItemId);

    @Query("SELECT ss FROM SoldSerial ss JOIN FETCH ss.serialNumber sn WHERE ss.orderItem.order.orderId = :orderId")
    List<SoldSerial> findByOrderIdWithSerial(@Param("orderId") Integer orderId);
}
