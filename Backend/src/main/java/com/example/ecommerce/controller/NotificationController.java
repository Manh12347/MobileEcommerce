package com.example.ecommerce.controller;

import com.example.ecommerce.dto.ApiResponse;
import com.example.ecommerce.dto.NotificationDTO;
import com.example.ecommerce.entity.Notification;
import com.example.ecommerce.service.NotificationService;
import com.example.ecommerce.util.SecurityUtil;
import lombok.extern.slf4j.Slf4j;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.http.HttpStatus;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.CrossOrigin;
import org.springframework.web.bind.annotation.DeleteMapping;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.PathVariable;
import org.springframework.web.bind.annotation.PutMapping;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RestController;

import java.util.List;

@RestController
@RequestMapping("/v1/api/notifications")
@CrossOrigin(origins = "*")
@Slf4j
public class NotificationController {

    @Autowired
    private NotificationService notificationService;

    @GetMapping
    public ResponseEntity<ApiResponse<List<NotificationDTO>>> getNotifications() {
        try {
            Integer accountId = SecurityUtil.getCurrentAccountId();
            if (accountId == null) {
                return ResponseEntity.status(HttpStatus.UNAUTHORIZED)
                        .body(new ApiResponse<>(false, "Login required", null));
            }

            List<NotificationDTO> notifications = notificationService.getUserNotifications(accountId)
                    .stream()
                    .map(notification -> NotificationDTO.fromEntity(notification, accountId))
                    .toList();
            return ResponseEntity.ok(new ApiResponse<>(true, "Notifications loaded", notifications));
        } catch (Exception e) {
            log.error("Error getting notifications:", e);
            return ResponseEntity.status(HttpStatus.INTERNAL_SERVER_ERROR)
                    .body(new ApiResponse<>(false, "Server error: " + e.getMessage(), null));
        }
    }

    @GetMapping("/unread-count")
    public ResponseEntity<ApiResponse<Long>> getUnreadCount() {
        try {
            Integer accountId = SecurityUtil.getCurrentAccountId();
            if (accountId == null) {
                return ResponseEntity.status(HttpStatus.UNAUTHORIZED)
                        .body(new ApiResponse<>(false, "Login required", null));
            }

            long unread = notificationService.countUnreadNotifications(accountId);
            return ResponseEntity.ok(new ApiResponse<>(true, "Unread count loaded", unread));
        } catch (Exception e) {
            log.error("Error getting unread count:", e);
            return ResponseEntity.status(HttpStatus.INTERNAL_SERVER_ERROR)
                    .body(new ApiResponse<>(false, "Server error: " + e.getMessage(), null));
        }
    }

    @PutMapping("/{id}/read")
    public ResponseEntity<ApiResponse<NotificationDTO>> markAsRead(@PathVariable Integer id) {
        try {
            Integer accountId = SecurityUtil.getCurrentAccountId();
            if (accountId == null) {
                return ResponseEntity.status(HttpStatus.UNAUTHORIZED)
                        .body(new ApiResponse<>(false, "Login required", null));
            }

            Notification notification = notificationService.markAsRead(id, accountId);
            if (notification == null) {
                return ResponseEntity.status(HttpStatus.NOT_FOUND)
                        .body(new ApiResponse<>(false, "Notification not found", null));
            }

            return ResponseEntity.ok(new ApiResponse<>(
                    true,
                    "Notification marked as read",
                    NotificationDTO.fromEntity(notification)
            ));
        } catch (Exception e) {
            log.error("Error marking notification as read:", e);
            return ResponseEntity.status(HttpStatus.INTERNAL_SERVER_ERROR)
                    .body(new ApiResponse<>(false, "Server error: " + e.getMessage(), null));
        }
    }

    @PutMapping("/read-all")
    public ResponseEntity<ApiResponse<Void>> markAllAsRead() {
        try {
            Integer accountId = SecurityUtil.getCurrentAccountId();
            if (accountId == null) {
                return ResponseEntity.status(HttpStatus.UNAUTHORIZED)
                        .body(new ApiResponse<>(false, "Login required", null));
            }

            notificationService.markAllAsRead(accountId);
            return ResponseEntity.ok(new ApiResponse<>(true, "All notifications marked as read", null));
        } catch (Exception e) {
            log.error("Error marking all notifications as read:", e);
            return ResponseEntity.status(HttpStatus.INTERNAL_SERVER_ERROR)
                    .body(new ApiResponse<>(false, "Server error: " + e.getMessage(), null));
        }
    }

    @DeleteMapping("/{id}")
    public ResponseEntity<ApiResponse<Void>> deleteNotification(@PathVariable Integer id) {
        try {
            Integer accountId = SecurityUtil.getCurrentAccountId();
            if (accountId == null) {
                return ResponseEntity.status(HttpStatus.UNAUTHORIZED)
                        .body(new ApiResponse<>(false, "Login required", null));
            }

            boolean deleted = notificationService.deleteNotification(id, accountId);
            if (!deleted) {
                return ResponseEntity.status(HttpStatus.NOT_FOUND)
                        .body(new ApiResponse<>(false, "Notification not found", null));
            }

            return ResponseEntity.ok(new ApiResponse<>(true, "Notification deleted", null));
        } catch (Exception e) {
            log.error("Error deleting notification:", e);
            return ResponseEntity.status(HttpStatus.INTERNAL_SERVER_ERROR)
                    .body(new ApiResponse<>(false, "Server error: " + e.getMessage(), null));
        }
    }
}
