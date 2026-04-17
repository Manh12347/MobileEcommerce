package com.example.ecommerce.service;

import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.mail.SimpleMailMessage;
import org.springframework.mail.javamail.JavaMailSender;
import org.springframework.mail.javamail.MimeMessageHelper;
import org.springframework.stereotype.Service;

import jakarta.mail.MessagingException;
import jakarta.mail.internet.MimeMessage;

@Service
@RequiredArgsConstructor
@Slf4j
public class MailService {

    private final JavaMailSender javaMailSender;

    /**
     * Gửi email đơn giản (text)
     */
    public void sendSimpleEmail(String to, String subject, String text) {
        try {
            SimpleMailMessage message = new SimpleMailMessage();
            message.setFrom("lemanh151148@gmail.com");
            message.setTo(to);
            message.setSubject(subject);
            message.setText(text);
            
            javaMailSender.send(message);
            log.info("Email sent successfully to: {}", to);
        } catch (Exception e) {
            log.error("Failed to send email to: {}", to, e);
            throw new RuntimeException("Failed to send email", e);
        }
    }

    /**
     * Gửi email HTML
     */
    public void sendHtmlEmail(String to, String subject, String htmlContent) {
        try {
            MimeMessage message = javaMailSender.createMimeMessage();
            MimeMessageHelper helper = new MimeMessageHelper(message, true, "UTF-8");
            
            helper.setFrom("lemanh151148@gmail.com");
            helper.setTo(to);
            helper.setSubject(subject);
            helper.setText(htmlContent, true);
            
            javaMailSender.send(message);
            log.info("HTML email sent successfully to: {}", to);
        } catch (MessagingException e) {
            log.error("Failed to send HTML email to: {}", to, e);
            throw new RuntimeException("Failed to send email", e);
        }
    }

    /**
     * Gửi email verify account
     */
    public void sendVerificationEmail(String to, String verificationLink) {
        String subject = "Xác thực tài khoản";
        String htmlContent = "<html>" +
                "<body>" +
                "<h2>Xác thực tài khoản của bạn</h2>" +
                "<p>Vui lòng nhấp vào liên kết dưới đây để xác thực tài khoản:</p>" +
                "<p><a href=\"" + verificationLink + "\">Xác thực tài khoản</a></p>" +
                "<p>Nếu bạn không tạo tài khoản này, vui lòng bỏ qua email này.</p>" +
                "</body>" +
                "</html>";
        
        sendHtmlEmail(to, subject, htmlContent);
    }

    /**
     * Gửi email reset password
     */
    public void sendPasswordResetEmail(String to, String resetLink) {
        String subject = "Đặt lại mật khẩu";
        String htmlContent = "<html>" +
                "<body>" +
                "<h2>Yêu cầu đặt lại mật khẩu</h2>" +
                "<p>Vui lòng nhấp vào liên kết dưới đây để đặt lại mật khẩu:</p>" +
                "<p><a href=\"" + resetLink + "\">Đặt lại mật khẩu</a></p>" +
                "<p>Liên kết này sẽ hết hạn trong 24 giờ.</p>" +
                "<p>Nếu bạn không yêu cầu điều này, vui lòng bỏ qua email này.</p>" +
                "</body>" +
                "</html>";
        
        sendHtmlEmail(to, subject, htmlContent);
    }

    /**
     * Gửi email thông báo đơn hàng
     */
    public void sendOrderConfirmationEmail(String to, String orderNumber, String total) {
        String subject = "Xác nhận đơn hàng #" + orderNumber;
        String htmlContent = "<html>" +
                "<body>" +
                "<h2>Xác nhận đơn hàng</h2>" +
                "<p>Cảm ơn bạn đã đặt hàng!</p>" +
                "<p><strong>Số đơn hàng:</strong> " + orderNumber + "</p>" +
                "<p><strong>Tổng tiền:</strong> " + total + "</p>" +
                "<p>Chúng tôi sẽ xác nhận giao hàng trong vòng 24 giờ.</p>" +
                "</body>" +
                "</html>";
        
        sendHtmlEmail(to, subject, htmlContent);
    }

    /**
     * Gửi email OTP 6 số
     */
    public void sendOtpEmail(String to, String otp) {
        String subject = "Mã OTP xác thực tài khoản";
        String htmlContent = "<html>" +
                "<body>" +
                "<h2>Mã OTP của bạn</h2>" +
                "<p>Vui lòng sử dụng mã OTP dưới đây để xác thực tài khoản:</p>" +
                "<h1 style='color: #007bff; font-size: 32px; letter-spacing: 5px;'>" + otp + "</h1>" +
                "<p><strong>Lưu ý:</strong> Mã OTP này sẽ hết hạn trong 10 phút.</p>" +
                "<p>Nếu bạn không yêu cầu OTP này, vui lòng bỏ qua email này.</p>" +
                "</body>" +
                "</html>";
        
        sendHtmlEmail(to, subject, htmlContent);
    }
}
