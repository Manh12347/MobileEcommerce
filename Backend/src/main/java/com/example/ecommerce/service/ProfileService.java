package com.example.ecommerce.service;

import com.example.ecommerce.dto.ProfileDTO;
import com.example.ecommerce.dto.UpdateProfileRequest;
import com.example.ecommerce.entity.Account;
import com.example.ecommerce.entity.Profile;
import com.example.ecommerce.repository.AccountRepository;
import com.example.ecommerce.repository.ProfileRepository;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.time.format.DateTimeFormatter;

@Service
@Transactional
public class ProfileService {

    private static final DateTimeFormatter DATE_FORMATTER = DateTimeFormatter.ofPattern("yyyy-MM-dd HH:mm:ss");

    @Autowired
    private AccountRepository accountRepository;

    @Autowired
    private ProfileRepository profileRepository;

    public ProfileDTO getMyProfile(Integer accountId) {
        Profile profile = getOrCreateProfile(accountId);
        return toDTO(profile);
    }

    public ProfileDTO updateMyProfile(Integer accountId, UpdateProfileRequest request) {
        Profile profile = getOrCreateProfile(accountId);

        if (request.getFullName() != null) {
            profile.setFullName(request.getFullName());
        }
        if (request.getPhone() != null) {
            profile.setPhone(request.getPhone());
        }
        if (request.getAddress() != null) {
            profile.setAddress(request.getAddress());
        }
        if (request.getAvatarUrl() != null) {
            profile.setAvatarUrl(request.getAvatarUrl());
        }

        profile = profileRepository.save(profile);
        return toDTO(profile);
    }

    private Profile getOrCreateProfile(Integer accountId) {
        Account account = accountRepository.findById(accountId)
                .orElseThrow(() -> new RuntimeException("Không tìm thấy tài khoản"));

        return profileRepository.findByAccountAccountId(accountId)
                .orElseGet(() -> {
                    Profile profile = new Profile();
                    profile.setAccount(account);
                    return profileRepository.save(profile);
                });
    }

    private ProfileDTO toDTO(Profile profile) {
        Account account = profile.getAccount();
        ProfileDTO dto = new ProfileDTO();
        dto.setAccountId(account != null ? account.getAccountId() : null);
        dto.setEmail(account != null ? account.getEmail() : null);
        dto.setFullName(profile.getFullName());
        dto.setPhone(profile.getPhone());
        dto.setAddress(profile.getAddress());
        dto.setAvatarUrl(profile.getAvatarUrl());
        dto.setCreatedOn(profile.getCreatedOn() != null ? profile.getCreatedOn().format(DATE_FORMATTER) : null);
        return dto;
    }
}