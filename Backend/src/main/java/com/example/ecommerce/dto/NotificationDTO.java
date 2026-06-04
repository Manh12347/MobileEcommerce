package com.example.ecommerce.dto;

import com.example.ecommerce.entity.Notification;
import lombok.AllArgsConstructor;
import lombok.Getter;
import lombok.NoArgsConstructor;
import lombok.Setter;

@Getter
@Setter
@NoArgsConstructor
@AllArgsConstructor
public class NotificationDTO {
    private Integer notificationId;
    private Integer accountId;
    private String title;
    private String message;
    private String type;
    private Boolean isRead;
    private String createdOn;

    public static NotificationDTO fromEntity(Notification notification) {
        Integer accountId = notification.getAccount() != null
                ? notification.getAccount().getAccountId()
                : null;
        return fromEntity(notification, accountId);
    }

    public static NotificationDTO fromEntity(Notification notification, Integer accountId) {
        return new NotificationDTO(
                notification.getNotificationId(),
                accountId,
                notification.getTitle(),
                notification.getMessage(),
                notification.getType(),
                notification.getIsRead(),
                notification.getCreatedOn() != null
                        ? notification.getCreatedOn().toString()
                        : null
        );
    }
}
