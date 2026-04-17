package com.example.ecommerce.service;

import com.example.ecommerce.entity.Account;
import com.example.ecommerce.entity.UserSession;
import com.example.ecommerce.repository.UserSessionRepository;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.time.LocalDateTime;
import java.util.List;

@Service
@Transactional
public class UserSessionService {

    @Autowired
    private UserSessionRepository userSessionRepository;

    public UserSession createSession(Account account, String refreshToken, LocalDateTime expiresAt) {
        UserSession session = new UserSession();
        session.setAccount(account);
        session.setRefreshToken(refreshToken);
        session.setExpiresAt(expiresAt);
        session.setCreatedAt(LocalDateTime.now());
        return userSessionRepository.save(session);
    }

    public UserSession getSession(Integer sessionId) {
        return userSessionRepository.findById(sessionId).orElse(null);
    }

    public UserSession getSessionByRefreshToken(String refreshToken) {
        return userSessionRepository.findByRefreshToken(refreshToken).orElse(null);
    }

    public List<UserSession> getUserSessions(Integer accountId) {
        return userSessionRepository.findByAccountAccountId(accountId);
    }

    public void deleteSession(Integer sessionId) {
        userSessionRepository.deleteById(sessionId);
    }

    public void deleteExpiredSessions() {
        List<UserSession> allSessions = userSessionRepository.findAll();
        LocalDateTime now = LocalDateTime.now();
        for (UserSession session : allSessions) {
            if (session.getExpiresAt().isBefore(now)) {
                userSessionRepository.delete(session);
            }
        }
    }

    public void deleteAllUserSessions(Integer accountId) {
        List<UserSession> sessions = getUserSessions(accountId);
        userSessionRepository.deleteAll(sessions);
    }
}
