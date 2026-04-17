package com.example.ecommerce.repository;

import com.example.ecommerce.entity.UserSession;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.stereotype.Repository;

import java.util.List;
import java.util.Optional;

@Repository
public interface UserSessionRepository extends JpaRepository<UserSession, Integer> {
    List<UserSession> findByAccountAccountId(Integer accountId);
    Optional<UserSession> findByRefreshToken(String refreshToken);
}
