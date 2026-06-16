package com.hango.hango_backend.service;

import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.mail.SimpleMailMessage;
import org.springframework.mail.javamail.JavaMailSender;
import org.springframework.stereotype.Service;

@Service
public class EmailService {

    @Autowired(required = false)
    private JavaMailSender mailSender;

    public void sendOtpEmail(String toEmail, String otpCode) {
        SimpleMailMessage message = new SimpleMailMessage();
        message.setTo(toEmail);
        message.setSubject("HanGo - Reset Your Password");
        message.setText("Hello,\n\n" +
                "You requested to reset your password. Please use the following 6-digit OTP code to proceed:\n\n" +
                otpCode + "\n\n" +
                "This OTP code is valid for 5 minutes. If you did not request this, you can safely ignore this email.\n\n" +
                "Best regards,\n" +
                "HanGo Team");

        try {
            if (mailSender != null) {
                mailSender.send(message);
                System.out.println("[EMAIL SUCCESS] Sent OTP to: " + toEmail);
            } else {
                System.out.println("[EMAIL WARN] JavaMailSender is not initialized. Printing OTP to console instead.");
                System.out.println("[OTP CODE FOR DEVELOPMENT] Email: " + toEmail + " -> OTP: " + otpCode);
            }
        } catch (Exception e) {
            System.err.println("[EMAIL WARNING] Could not send real email: " + e.getMessage());
            System.out.println("[OTP CODE FOR DEVELOPMENT] Email: " + toEmail + " -> OTP: " + otpCode);
        }
    }
}
