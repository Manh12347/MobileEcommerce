package com.example.ecommerce.service;

import com.example.ecommerce.entity.Account;
import com.example.ecommerce.entity.Notification;
import com.example.ecommerce.repository.NotificationRepository;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.time.LocalDateTime;
import java.util.List;

@Service
@Transactional
public class NotificationService {

    @Autowired
    private NotificationRepository notificationRepository;

    public Notification createNotification(Account account, String title, String message, String type) {
        Notification notification = new Notification();
        notification.setAccount(account);
        notification.setTitle(title);
        notification.setMessage(message);
        notification.setType(type);
        notification.setIsRead(false);
        notification.setCreatedOn(LocalDateTime.now());
        return notificationRepository.save(notification);
    }

    public List<Notification> getUserNotifications(Integer accountId) {
        return notificationRepository.findByAccountAccountIdOrderByCreatedOnDesc(accountId);
    }

    public List<Notification> getUnreadNotifications(Integer accountId) {
        return notificationRepository.findByAccountAccountIdAndIsReadFalse(accountId);
    }

    public Notification markAsRead(Integer notificationId) {
        Notification notification = notificationRepository.findById(notificationId).orElse(null);
        if (notification != null) {
            notification.setIsRead(true);
            return notificationRepository.save(notification);
        }
        return null;
    }

    public void deleteNotification(Integer notificationId) {
        notificationRepository.deleteById(notificationId);
    }

    public void markAllAsRead(Integer accountId) {
        List<Notification> unread = getUnreadNotifications(accountId);
        unread.forEach(n -> n.setIsRead(true));
        notificationRepository.saveAll(unread);
    }
}
