package com.example.ecommerce.repository;

import com.example.ecommerce.entity.Profile;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.stereotype.Repository;
import org.springframework.data.jpa.repository.Query;

import java.util.Optional;

@Repository
public interface ProfileRepository extends JpaRepository<Profile, Integer> {
    @Query("SELECT p FROM Profile p JOIN FETCH p.account WHERE p.account.accountId = :accountId")
    Optional<Profile> findByAccountAccountId(Integer accountId);
}
