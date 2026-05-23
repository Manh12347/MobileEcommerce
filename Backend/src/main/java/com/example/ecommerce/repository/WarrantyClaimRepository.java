package com.example.ecommerce.repository;

import com.example.ecommerce.entity.WarrantyClaim;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.Query;
import org.springframework.data.repository.query.Param;
import org.springframework.stereotype.Repository;

import java.util.List;

@Repository
public interface WarrantyClaimRepository extends JpaRepository<WarrantyClaim, Integer> {
    List<WarrantyClaim> findBySerialNumberSerialId(Integer serialId);
    List<WarrantyClaim> findByAccountAccountId(Integer accountId);
    List<WarrantyClaim> findByStatus(String status);

    @Query("""
            SELECT wc FROM WarrantyClaim wc
            LEFT JOIN FETCH wc.serialNumber sn
            LEFT JOIN FETCH sn.productItem pi
            LEFT JOIN FETCH pi.product p
            LEFT JOIN FETCH wc.account a
            LEFT JOIN FETCH a.profile profile
            LEFT JOIN FETCH sn.warranty warranty
            ORDER BY p.name ASC, sn.serialCode ASC, wc.createdAt DESC
            """)
    List<WarrantyClaim> findAllWithProductAndSerial();

    @Query("""
            SELECT wc FROM WarrantyClaim wc
            LEFT JOIN FETCH wc.serialNumber sn
            LEFT JOIN FETCH sn.productItem pi
            LEFT JOIN FETCH pi.product p
            LEFT JOIN FETCH wc.account a
            LEFT JOIN FETCH a.profile profile
            LEFT JOIN FETCH sn.warranty warranty
            WHERE wc.status = :status
            ORDER BY p.name ASC, sn.serialCode ASC, wc.createdAt DESC
            """)
    List<WarrantyClaim> findByStatusWithProductAndSerial(@Param("status") String status);
}
