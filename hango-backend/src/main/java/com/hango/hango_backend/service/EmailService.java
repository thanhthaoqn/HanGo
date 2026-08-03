package com.hango.hango_backend.service;

import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.mail.SimpleMailMessage;
import org.springframework.mail.javamail.JavaMailSender;
import org.springframework.stereotype.Service;

import java.net.URLEncoder;
import java.nio.charset.StandardCharsets;

@Service
public class EmailService {

    @Autowired(required = false)
    private JavaMailSender mailSender;

    @Value("${app.base-url:https://api.hangog92.online}")
    private String appBaseUrl;

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

    public void sendVerificationEmail(String toEmail, String verificationToken) {
        String verifyUrl = appBaseUrl + "/api/auth/verify?token=" + URLEncoder.encode(verificationToken, StandardCharsets.UTF_8);
        SimpleMailMessage message = new SimpleMailMessage();
        message.setTo(toEmail);
        message.setSubject("HanGo - Verify Your Account");
        message.setText("Hello,\n\n" +
                "Thank you for registering on HanGo. Please click the link below to verify and activate your account:\n\n" +
                verifyUrl + "\n\n" +
                "Best regards,\n" +
                "HanGo Team");

        try {
            if (mailSender != null) {
                mailSender.send(message);
                System.out.println("[EMAIL SUCCESS] Sent verification link to: " + toEmail);
            } else {
                System.out.println("[EMAIL WARN] JavaMailSender is not initialized. Printing link to console instead.");
                System.out.println("[VERIFICATION LINK FOR DEVELOPMENT] " + verifyUrl);
            }
        } catch (Exception e) {
            System.err.println("[EMAIL WARNING] Could not send verification email: " + e.getMessage());
            System.out.println("[VERIFICATION LINK FOR DEVELOPMENT] " + verifyUrl);
        }
    }

    public void sendTrainerStatusNotificationEmail(String toEmail, String status, String adminNotes) {
        SimpleMailMessage message = new SimpleMailMessage();
        message.setTo(toEmail);

        String subject;
        String contentText;

        if ("VERIFIED".equalsIgnoreCase(status)) {
            subject = "HanGo - Educator Profile Approved!";
            contentText = "Congratulations!\n\n" +
                    "Your Educator application on HanGo has been APPROVED by our administration team. " +
                    "You can now access your Educator Dashboard, create high-quality courses, and publish exams.\n\n" +
                    (adminNotes != null && !adminNotes.trim().isEmpty() ? "Admin Notes: " + adminNotes + "\n\n" : "") +
                    "Access your Educator Dashboard now: https://hangog92.online/login\n\n" +
                    "Thank you for joining HanGo!\n\n" +
                    "Best regards,\n" +
                    "HanGo Admin Team";
        } else if ("SUSPENDED".equalsIgnoreCase(status)) {
            subject = "HanGo - Educator Profile Status Update (Suspended)";
            contentText = "Hello,\n\n" +
                    "Your Educator application/account status on HanGo has been set to SUSPENDED / BANNED.\n\n" +
                    (adminNotes != null && !adminNotes.trim().isEmpty() ? "Reason / Notes: " + adminNotes + "\n\n" : "") +
                    "If you believe this is an error, please contact support at https://hangog92.online\n\n" +
                    "Best regards,\n" +
                    "HanGo Admin Team";
        } else {
            subject = "HanGo - Educator Profile Requires Edits / Review Update";
            contentText = "Hello,\n\n" +
                    "Our administration team has reviewed your Educator application. Additional information or modifications are required:\n\n" +
                    (adminNotes != null && !adminNotes.trim().isEmpty() ? "Admin Notes / Requested Edits: " + adminNotes + "\n\n" : "Please log into HanGo to view requested edits.\n\n") +
                    "Please click the link below to log into your account, update your profile, and resubmit:\n" +
                    "https://hangog92.online/trainer/onboarding\n\n" +
                    "Best regards,\n" +
                    "HanGo Admin Team";
        }

        message.setSubject(subject);
        message.setText(contentText);

        try {
            if (mailSender != null) {
                mailSender.send(message);
                System.out.println("[EMAIL SUCCESS] Sent status update email to trainer: " + toEmail);
            } else {
                System.out.println("[EMAIL WARN] JavaMailSender not initialized. Trainer Status Email: " + toEmail + " -> " + status);
            }
        } catch (Exception e) {
            System.err.println("[EMAIL WARNING] Could not send trainer status email: " + e.getMessage());
        }
    }

    public void sendEnrollmentSuccessEmail(String toEmail, String learnerName, String courseTitle, String priceText) {
        SimpleMailMessage message = new SimpleMailMessage();
        message.setTo(toEmail);
        message.setSubject("HanGo - XÁC NHẬN ĐĂNG KÝ HỌC THÀNH CÔNG");
        message.setText("Xin chào " + (learnerName != null && !learnerName.trim().isEmpty() ? learnerName : "Học viên") + ",\n\n" +
                "Chúc mừng bạn đã đăng ký / thanh toán thành công khóa học trên nền tảng HanGo!\n\n" +
                "THÔNG TIN ĐƠN HÀNG:\n" +
                "- Tên khóa học: " + courseTitle + "\n" +
                "- Học phí: " + priceText + "\n" +
                "- Trạng thái: ĐÃ MỞ KHÓA HOÀN TOÀN\n\n" +
                "Bạn có thể truy cập ngay vào khóa học để bắt đầu hành trình học tập:\n" +
                "https://hangog92.online\n\n" +
                "Chúc bạn có trải nghiệm học tập tuyệt vời cùng HanGo!\n\n" +
                "Trân trọng,\n" +
                "Đội ngũ HanGo EdTech");

        try {
            if (mailSender != null) {
                mailSender.send(message);
                System.out.println("[EMAIL SUCCESS] Sent enrollment confirmation email to learner: " + toEmail);
            } else {
                System.out.println("[EMAIL SUCCESS LOG] Enrollment Confirmation Email: " + toEmail + " -> Course: " + courseTitle + " (" + priceText + ")");
            }
        } catch (Exception e) {
            System.err.println("[EMAIL WARNING] Could not send enrollment email: " + e.getMessage());
        }
    }
}
