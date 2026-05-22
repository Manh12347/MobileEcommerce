package com.example.ecommerce.config;

import lombok.extern.slf4j.Slf4j;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.boot.autoconfigure.condition.ConditionalOnProperty;
import org.springframework.context.annotation.Bean;
import org.springframework.context.annotation.Configuration;
import org.springframework.mail.MailSender;
import org.springframework.mail.SimpleMailMessage;
import org.springframework.mail.javamail.JavaMailSender;
import org.springframework.mail.javamail.JavaMailSenderImpl;
import org.springframework.mail.javamail.MimeMessageHelper;

import jakarta.mail.internet.MimeMessage;
import java.io.InputStream;
import java.util.Properties;
import java.util.Arrays;

@Configuration
@Slf4j
public class MailConfig {

    @Value("${spring.mail.host:}")
    private String host;

    @Value("${spring.mail.port:587}")
    private Integer port;

    @Value("${spring.mail.username:}")
    private String username;

    @Value("${spring.mail.password:}")
    private String password;

    @Bean
    public JavaMailSender javaMailSender() {
        System.out.println("CUSTOM MAIL CONFIG ACTIVE");
        
        // If mail configuration is not available, use no-op implementation
        if (host == null || host.isEmpty()) {
            log.warn("No mail configuration found. Using no-op email sender. Emails will not be sent.");
            return createNoOpMailSender();
        }

        log.info("Initializing JavaMailSender with SMTP: {}:{}", host, port);
        JavaMailSenderImpl mailSender = new JavaMailSenderImpl();
        mailSender.setHost(host);
        if (port != null) {
            mailSender.setPort(port);
        }
        mailSender.setUsername(username);
        mailSender.setPassword(password);

        Properties props = mailSender.getJavaMailProperties();
        props.put("mail.transport.protocol", "smtp");
        props.put("mail.smtp.auth", "true");
        props.put("mail.smtp.starttls.enable", "true");
        props.put("mail.smtp.starttls.required", "false");

        return mailSender;
    }

    private JavaMailSender createNoOpMailSender() {
        return new JavaMailSender() {
            @Override
            public void send(SimpleMailMessage simpleMailMessage) {
                log.debug("No-op email sender: discarding message to {}", Arrays.toString(simpleMailMessage.getTo()));
            }

            @Override
            public void send(SimpleMailMessage... simpleMailMessages) {
                log.debug("No-op email sender: discarding {} messages", simpleMailMessages.length);
            }

            @Override
            public MimeMessage createMimeMessage() {
                return new JavaMailSenderImpl().createMimeMessage();
            }

            @Override
            public MimeMessage createMimeMessage(InputStream inputStream) {
                try {
                    return new JavaMailSenderImpl().createMimeMessage(inputStream);
                } catch (Exception e) {
                    return new JavaMailSenderImpl().createMimeMessage();
                }
            }

            @Override
            public void send(MimeMessage mimeMessage) {
                log.debug("No-op email sender: discarding MIME message");
            }

            @Override
            public void send(MimeMessage... mimeMessages) {
                log.debug("No-op email sender: discarding {} MIME messages", mimeMessages.length);
            }
        };
    }
}

