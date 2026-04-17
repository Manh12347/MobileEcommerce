package com.example.ecommerce.service;

import com.example.ecommerce.entity.Account;
import com.example.ecommerce.repository.AccountRepository;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.time.LocalDateTime;
import java.util.Optional;

@Service
@Transactional
public class AccountService {

    @Autowired
    private AccountRepository accountRepository;

    public Account createAccount(String email, String passwordHash, String role) {
        Account account = new Account();
        account.setEmail(email);
        account.setPasswordHash(passwordHash);
        account.setRole(role != null ? role : "customer");
        account.setStatus("active");
        account.setEmailConfirm(false);
        account.setIs2faEnabled(false);
        account.setFailedLoginAttempts(0);
        return accountRepository.save(account);
    }

    public Account getAccount(Integer accountId) {
        return accountRepository.findById(accountId).orElse(null);
    }

    public Account getAccountByEmail(String email) {
        return accountRepository.findByEmail(email).orElse(null);
    }

    public Account updateAccount(Integer accountId, String email, String role, String status) {
        Optional<Account> accountOpt = accountRepository.findById(accountId);
        if (!accountOpt.isPresent()) return null;

        Account account = accountOpt.get();
        if (email != null) account.setEmail(email);
        if (role != null) account.setRole(role);
        if (status != null) account.setStatus(status);

        return accountRepository.save(account);
    }

    public Account enable2FA(Integer accountId, String secret) {
        Optional<Account> accountOpt = accountRepository.findById(accountId);
        if (!accountOpt.isPresent()) return null;

        Account account = accountOpt.get();
        account.setIs2faEnabled(true);
        account.setTwofaSecret(secret);
        return accountRepository.save(account);
    }

    public Account disable2FA(Integer accountId) {
        Optional<Account> accountOpt = accountRepository.findById(accountId);
        if (!accountOpt.isPresent()) return null;

        Account account = accountOpt.get();
        account.setIs2faEnabled(false);
        account.setTwofaSecret(null);
        account.setTwofaRecoveryCodes(null);
        return accountRepository.save(account);
    }

    public Account recordFailedLogin(Integer accountId) {
        Optional<Account> accountOpt = accountRepository.findById(accountId);
        if (!accountOpt.isPresent()) return null;

        Account account = accountOpt.get();
        Integer attempts = account.getFailedLoginAttempts() != null ?
                account.getFailedLoginAttempts() + 1 : 1;
        account.setFailedLoginAttempts(attempts);
        account.setLastFailedLogin(LocalDateTime.now());

        // Lock account after 5 failed attempts
        if (attempts >= 5) {
            account.setStatus("locked");
        }

        return accountRepository.save(account);
    }

    public Account resetFailedLogin(Integer accountId) {
        Optional<Account> accountOpt = accountRepository.findById(accountId);
        if (!accountOpt.isPresent()) return null;

        Account account = accountOpt.get();
        account.setFailedLoginAttempts(0);
        account.setLastFailedLogin(null);
        return accountRepository.save(account);
    }

    public Account confirmEmail(Integer accountId) {
        Optional<Account> accountOpt = accountRepository.findById(accountId);
        if (!accountOpt.isPresent()) return null;

        Account account = accountOpt.get();
        account.setEmailConfirm(true);
        return accountRepository.save(account);
    }
}
