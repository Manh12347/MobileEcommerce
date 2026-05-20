package com.example.ecommerce.repository;

import com.example.ecommerce.entity.SerialNumber;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.Query;
import org.springframework.data.repository.query.Param;
import org.springframework.stereotype.Repository;

import java.util.List;
import java.util.Optional;

@Repository
public interface SerialNumberRepository extends JpaRepository<SerialNumber, Long> {
    Optional<SerialNumber> findBySerialCode(String serialCode);
    
    @Query("SELECT s FROM SerialNumber s LEFT JOIN FETCH s.productItem WHERE s.productItem.productItemId = :productItemId")
    List<SerialNumber> findByProductItemProductItemId(@Param("productItemId") Integer productItemId);
    
    List<SerialNumber> findByStatus(String status);
}
