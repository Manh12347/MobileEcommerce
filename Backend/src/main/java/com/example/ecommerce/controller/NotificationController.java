package com.example.ecommerce.controller;

import com.example.ecommerce.dto.ApiResponse;
import com.example.ecommerce.entity.Notification;
import com.example.ecommerce.service.NotificationService;
import com.example.ecommerce.util.SecurityUtil;
import lombok.extern.slf4j.Slf4j;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.http.HttpStatus;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.*;

import java.util.List;

@RestController
@RequestMapping("/v1/api/notifications")
@CrossOrigin(origins = "*")
@Slf4j
public class NotificationController {

    @Autowired
    private NotificationService notificationService;

    @GetMapping
    public ResponseEntity<ApiResponse<List<Notification>>> getNotifications() {
        try {
            Integer accountId = SecurityUtil.getCurrentAccountId();
            if (accountId == null) {
                return ResponseEntity.status(HttpStatus.UNAUTHORIZED)
                        .body(new ApiResponse<>(false, "Bạn cần đăng nhập", null));
            }
            List<Notification> notifications = notificationService.getUserNotifications(accountId);
            return ResponseEntity.ok(new ApiResponse<>(true, "Lấy thông báo thành công", notifications));
        } catch (Exception e) {
            log.error("Error getting notifications:", e);
            return ResponseEntity.status(HttpStatus.INTERNAL_SERVER_ERROR)
                    .body(new ApiResponse<>(false, "Lỗi máy chủ: " + e.getMessage(), null));
        }
    }

    @GetMapping("/unread-count")
    public ResponseEntity<ApiResponse<Long>> getUnreadCount() {
        try {
            Integer accountId = SecurityUtil.getCurrentAccountId();
            if (accountId == null) {
                return ResponseEntity.status(HttpStatus.UNAUTHORIZED)
                        .body(new ApiResponse<>(false, "Bạn cần đăng nhập", null));
            }
            List<Notification> unread = notificationService.getUnreadNotifications(accountId);
            return ResponseEntity.ok(new ApiResponse<>(true, "Lấy số thông báo chưa đọc", (long) unread.size()));
        } catch (Exception e) {
            log.error("Error getting unread count:", e);
            return ResponseEntity.status(HttpStatus.INTERNAL_SERVER_ERROR)
                    .body(new ApiResponse<>(false, "Lỗi máy chủ: " + e.getMessage(), null));
        }
    }

    @PutMapping("/{id}/read")
    public ResponseEntity<ApiResponse<Notification>> markAsRead(@PathVariable Integer id) {
        try {
            Integer accountId = SecurityUtil.getCurrentAccountId();
            if (accountId == null) {
                return ResponseEntity.status(HttpStatus.UNAUTHORIZED)
                        .body(new ApiResponse<>(false, "Bạn cần đăng nhập", null));
            }
            Notification notification = notificationService.markAsRead(id);
            if (notification == null) {
                return ResponseEntity.status(HttpStatus.NOT_FOUND)
                        .body(new ApiResponse<>(false, "Không tìm thấy thông báo", null));
            }
            return ResponseEntity.ok(new ApiResponse<>(true, "Đã đánh dấu đã đọc", notification));
        } catch (Exception e) {
            log.error("Error marking notification as read:", e);
            return ResponseEntity.status(HttpStatus.INTERNAL_SERVER_ERROR)
                    .body(new ApiResponse<>(false, "Lỗi máy chủ: " + e.getMessage(), null));
        }
    }

    @PutMapping("/read-all")
    public ResponseEntity<ApiResponse<Void>> markAllAsRead() {
        try {
            Integer accountId = SecurityUtil.getCurrentAccountId();
            if (accountId == null) {
                return ResponseEntity.status(HttpStatus.UNAUTHORIZED)
                        .body(new ApiResponse<>(false, "Bạn cần đăng nhập", null));
            }
            notificationService.markAllAsRead(accountId);
            return ResponseEntity.ok(new ApiResponse<>(true, "Đã đánh dấu tất cả đã đọc", null));
        } catch (Exception e) {
            log.error("Error marking all notifications as read:", e);
            return ResponseEntity.status(HttpStatus.INTERNAL_SERVER_ERROR)
                    .body(new ApiResponse<>(false, "Lỗi máy chủ: " + e.getMessage(), null));
        }
    }

    @DeleteMapping("/{id}")
    public ResponseEntity<ApiResponse<Void>> deleteNotification(@PathVariable Integer id) {
        try {
            Integer accountId = SecurityUtil.getCurrentAccountId();
            if (accountId == null) {
                return ResponseEntity.status(HttpStatus.UNAUTHORIZED)
                        .body(new ApiResponse<>(false, "Bạn cần đăng nhập", null));
            }
            notificationService.deleteNotification(id);
            return ResponseEntity.ok(new ApiResponse<>(true, "Xóa thông báo thành công", null));
        } catch (Exception e) {
            log.error("Error deleting notification:", e);
            return ResponseEntity.status(HttpStatus.INTERNAL_SERVER_ERROR)
                    .body(new ApiResponse<>(false, "Lỗi máy chủ: " + e.getMessage(), null));
        }
    }
}
