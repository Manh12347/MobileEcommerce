package com.example.ecommerce.hub;

import com.example.ecommerce.dto.PaymentNotificationPayload;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.messaging.handler.annotation.DestinationVariable;
import org.springframework.messaging.handler.annotation.MessageMapping;
import org.springframework.messaging.handler.annotation.SendTo;
import org.springframework.messaging.simp.SimpMessagingTemplate;
import org.springframework.stereotype.Controller;

@Controller
@RequiredArgsConstructor
@Slf4j
public class PaymentHub {

    private final SimpMessagingTemplate messagingTemplate;

    /**
     * Client gửi lên: /app/payment.join
     * Body: { "gencode": "ORDER_123456789012345" }
     * Server phản hồi: "JOINED:{gencode}"
     */
    @MessageMapping("/payment.join")
    @SendTo("/topic/payment/joined")
    public String joinPaymentGroup(PaymentJoinRequest request) {
        String gencode = request.getGencode();
        if (gencode == null || gencode.isBlank()) {
            log.warn("[PaymentHub] Client attempted to join with empty gencode");
            return "REJECTED:empty";
        }
        log.info("[PaymentHub] Client joining payment group: gencode={}", gencode);
        return "JOINED:" + gencode;
    }

    /**
     * Client gửi lên: /app/payment.leave
     * Body: { "gencode": "ORDER_123456789012345" }
     */
    @MessageMapping("/payment.leave")
    public void leavePaymentGroup(PaymentJoinRequest request) {
        String gencode = request.getGencode();
        if (gencode != null && !gencode.isBlank()) {
            log.info("[PaymentHub] Client leaving payment group: gencode={}", gencode);
        }
    }

    /**
     * Server gửi notification tới client theo gencode
     * Được gọi từ HooksService/WebhookController sau khi xác nhận thanh toán
     */
    public void notifyPaymentSuccess(String gencode, Integer orderId, String orderCode,
                                     String paymentStatus, String message) {
        PaymentNotificationPayload payload = PaymentNotificationPayload.builder()
                .gencode(gencode)
                .orderId(orderId)
                .orderCode(orderCode)
                .paymentStatus(paymentStatus)
                .message(message)
                .timestamp(System.currentTimeMillis())
                .build();

        String destination = "/topic/payment/" + gencode;
        messagingTemplate.convertAndSend(destination, payload);

        log.info("[PaymentHub] Sent payment notification to {}: orderId={}, status={}",
                destination, orderId, paymentStatus);
    }
}
