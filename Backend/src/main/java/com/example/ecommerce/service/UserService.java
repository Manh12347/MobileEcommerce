package com.example.ecommerce.service;

import com.example.ecommerce.dto.*;
import com.example.ecommerce.entity.Account;
import com.example.ecommerce.entity.Profile;
import com.example.ecommerce.repository.AccountRepository;
import com.example.ecommerce.repository.ProfileRepository;
import com.example.ecommerce.util.ValidationUtil;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.data.domain.Page;
import org.springframework.data.domain.PageRequest;
import org.springframework.data.domain.Pageable;
import org.springframework.security.crypto.bcrypt.BCryptPasswordEncoder;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.time.format.DateTimeFormatter;
import java.util.List;
import java.util.Optional;
import java.util.stream.Collectors;

@Service
@Transactional
public class UserService {

    @Autowired
    private AccountRepository accountRepository;

    @Autowired
    private ProfileRepository profileRepository;

    private static final DateTimeFormatter DATE_FORMATTER = DateTimeFormatter.ofPattern("yyyy-MM-dd HH:mm:ss");

    public UserListResponse getAllUsers(int page, int size) {
        Pageable pageable = PageRequest.of(page, size);
        Page<Account> accountPage = accountRepository.findAll(pageable);

        List<UserDTO> users = accountPage.getContent().stream()
                .map(this::convertToDTO)
                .collect(Collectors.toList());

        UserListResponse response = new UserListResponse();
        response.setUsers(users);
        response.setTotal((int) accountPage.getTotalElements());
        response.setPage(page);
        response.setSize(size);
        return response;
    }

    public UserDTO getUserById(Integer accountId) {
        Account account = accountRepository.findById(accountId).orElse(null);
        if (account == null) return null;
        return convertToDTO(account);
    }

    public UserDTO createUser(CreateUserRequest request) {
        ValidationUtil.ValidationResult validation = ValidationUtil.validatePassword(request.getPassword());
        if (!validation.isValid()) {
            throw new RuntimeException(validation.getMessage());
        }

        if (accountRepository.findByEmail(request.getEmail()).isPresent()) {
            throw new RuntimeException("Email đã tồn tại");
        }

        Account account = new Account();
        account.setEmail(request.getEmail());
        account.setPasswordHash(hashPassword(request.getPassword()));
        account.setRole(request.getRole() != null ? request.getRole() : "customer");
        account.setStatus("active");
        account.setEmailConfirm(true);
        account.setIs2faEnabled(false);
        account.setFailedLoginAttempts(0);

        Account savedAccount = accountRepository.save(account);

        Profile profile = new Profile();
        profile.setAccount(savedAccount);
        profile.setFullName(request.getFullName());
        profile.setPhone(request.getPhone());
        profile.setAddress(request.getAddress());
        profileRepository.save(profile);

        return convertToDTO(savedAccount);
    }

    public UserDTO updateUser(Integer accountId, UpdateUserRequest request) {
        Optional<Account> accountOpt = accountRepository.findById(accountId);
        if (!accountOpt.isPresent()) {
            throw new RuntimeException("Không tìm thấy người dùng");
        }

        Account account = accountOpt.get();

        if (request.getEmail() != null) {
            Optional<Account> existingEmail = accountRepository.findByEmail(request.getEmail());
            if (existingEmail.isPresent() && !existingEmail.get().getAccountId().equals(accountId)) {
                throw new RuntimeException("Email đã được sử dụng");
            }
            account.setEmail(request.getEmail());
        }

        if (request.getRole() != null) {
            account.setRole(request.getRole());
        }
        if (request.getStatus() != null) {
            account.setStatus(request.getStatus());
        }

        accountRepository.save(account);

        Profile profile = account.getProfile();
        if (profile == null) {
            profile = new Profile();
            profile.setAccount(account);
        }
        if (request.getFullName() != null) profile.setFullName(request.getFullName());
        if (request.getPhone() != null) profile.setPhone(request.getPhone());
        if (request.getAddress() != null) profile.setAddress(request.getAddress());
        if (request.getAvatarUrl() != null) profile.setAvatarUrl(request.getAvatarUrl());
        profileRepository.save(profile);

        return convertToDTO(account);
    }

    public boolean deleteUser(Integer accountId) {
        if (!accountRepository.existsById(accountId)) {
            throw new RuntimeException("Không tìm thấy người dùng");
        }
        accountRepository.deleteById(accountId);
        return true;
    }

    public List<UserDTO> searchUsers(String keyword) {
        List<Account> accounts = accountRepository.findAll().stream()
                .filter(a -> a.getEmail().toLowerCase().contains(keyword.toLowerCase()) ||
                        (a.getProfile() != null &&
                         (a.getProfile().getFullName() != null &&
                          a.getProfile().getFullName().toLowerCase().contains(keyword.toLowerCase()) ||
                          a.getProfile().getPhone() != null &&
                          a.getProfile().getPhone().contains(keyword))))
                .collect(Collectors.toList());

        return accounts.stream()
                .map(this::convertToDTO)
                .collect(Collectors.toList());
    }

    private UserDTO convertToDTO(Account account) {
        UserDTO dto = new UserDTO();
        dto.setAccountId(account.getAccountId());
        dto.setEmail(account.getEmail());
        dto.setEmailConfirm(account.getEmailConfirm());
        dto.setRole(account.getRole());
        dto.setStatus(account.getStatus());
        dto.setIs2faEnabled(account.getIs2faEnabled());

        Profile profile = account.getProfile();
        if (profile != null) {
            dto.setFullName(profile.getFullName());
            dto.setPhone(profile.getPhone());
            dto.setAddress(profile.getAddress());
            dto.setAvatarUrl(profile.getAvatarUrl());
        }

        if (account.getCreatedOn() != null) {
            dto.setCreatedOn(account.getCreatedOn().format(DATE_FORMATTER));
        }
        if (account.getModifiedOn() != null) {
            dto.setModifiedOn(account.getModifiedOn().format(DATE_FORMATTER));
        }

        return dto;
    }

    private String hashPassword(String password) {
        BCryptPasswordEncoder encoder = new BCryptPasswordEncoder();
        return encoder.encode(password);
    }
}
