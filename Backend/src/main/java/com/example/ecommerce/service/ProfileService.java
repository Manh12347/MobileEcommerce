package com.example.ecommerce.service;

import com.example.ecommerce.dto.ProfileDTO;
import com.example.ecommerce.dto.UpdateProfileRequest;
import com.example.ecommerce.dto.ChangePasswordRequest;
import com.example.ecommerce.entity.Account;
import com.example.ecommerce.entity.Profile;
import com.example.ecommerce.repository.AccountRepository;
import com.example.ecommerce.repository.ProfileRepository;
import lombok.RequiredArgsConstructor;
import org.mindrot.jbcrypt.BCrypt;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.time.format.DateTimeFormatter;

@Service
@RequiredArgsConstructor
@Transactional
public class ProfileService {

    private static final DateTimeFormatter DATE_FORMATTER = DateTimeFormatter.ofPattern("yyyy-MM-dd HH:mm:ss");

    private final AccountRepository accountRepository;
    private final ProfileRepository profileRepository;

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
        if (request.getProvinceId() != null) {
            profile.setProvinceId(request.getProvinceId());
        }
        if (request.getProvinceName() != null) {
            profile.setProvinceName(request.getProvinceName());
        }
        if (request.getDistrictId() != null) {
            profile.setDistrictId(request.getDistrictId());
        }
        if (request.getDistrictName() != null) {
            profile.setDistrictName(request.getDistrictName());
        }
        if (request.getWardCode() != null) {
            profile.setWardCode(request.getWardCode());
        }
        if (request.getWardName() != null) {
            profile.setWardName(request.getWardName());
        }

        profile = profileRepository.save(profile);
        return toDTO(profile);
    }

    public void changePassword(Integer accountId, ChangePasswordRequest request) {
        Account account = accountRepository.findById(accountId)
                .orElseThrow(() -> new RuntimeException("Không tìm thấy tài khoản"));

        if (!BCrypt.checkpw(request.getCurrentPassword(), account.getPasswordHash())) {
            throw new RuntimeException("Mật khẩu hiện tại không đúng");
        }

        if (request.getNewPassword() == null || request.getNewPassword().length() < 6) {
            throw new RuntimeException("Mật khẩu mới phải có ít nhất 6 ký tự");
        }

        account.setPasswordHash(BCrypt.hashpw(request.getNewPassword(), BCrypt.gensalt(12)));
        accountRepository.save(account);
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
        dto.setRole(account != null ? account.getRole() : null);
        dto.setFullName(profile.getFullName());
        dto.setPhone(profile.getPhone());
        dto.setAddress(profile.getAddress());
        dto.setAvatarUrl(profile.getAvatarUrl());
        dto.setProvinceId(profile.getProvinceId());
        dto.setProvinceName(profile.getProvinceName());
        dto.setDistrictId(profile.getDistrictId());
        dto.setDistrictName(profile.getDistrictName());
        dto.setWardCode(profile.getWardCode());
        dto.setWardName(profile.getWardName());
        dto.setCreatedOn(profile.getCreatedOn() != null ? profile.getCreatedOn().format(DATE_FORMATTER) : null);
        dto.setIs2faEnabled(account != null ? account.getIs2faEnabled() : false);
        return dto;
    }
}
