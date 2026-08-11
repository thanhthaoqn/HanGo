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
            subject = "HanGo - Trainer Profile Approved!";
            contentText = "Congratulations!\n\n" +
                    "Your Trainer application on HanGo has been APPROVED. " +
                    "You can now complete your payout setup to access your Trainer Dashboard, create courses, and publish exams.\n\n" +
                    (adminNotes != null && !adminNotes.trim().isEmpty() ? "Notes: " + adminNotes + "\n\n" : "") +
                    "Access your account now: https://hangog92.online/login\n\n" +
                    "Thank you for joining HanGo!\n\n" +
                    "Best regards,\n" +
                    "HanGo EdTech Team";
        } else if ("SUSPENDED".equalsIgnoreCase(status)) {
            subject = "HanGo - Trainer Profile Status Update (Suspended)";
            contentText = "Hello,\n\n" +
                    "Your Trainer account status on HanGo has been set to SUSPENDED.\n\n" +
                    (adminNotes != null && !adminNotes.trim().isEmpty() ? "Reason: " + adminNotes + "\n\n" : "") +
                    "If you believe this is an error, please contact support at https://hangog92.online\n\n" +
                    "Best regards,\n" +
                    "HanGo EdTech Team";
        } else {
            subject = "HanGo - Trainer Application Rejected";
            contentText = "Hello,\n\n" +
                    "Your Trainer application on HanGo has been REJECTED by the Administrator.\n\n" +
                    (adminNotes != null && !adminNotes.trim().isEmpty() ? "Rejection Reason & Required Edits: " + adminNotes + "\n\n" : "Please log into HanGo to view rejection details.\n\n") +
                    "Please log into your account, update your profile details and certificates as requested, and resubmit:\n" +
                    "https://hangog92.online/login\n\n" +
                    "Best regards,\n" +
                    "HanGo EdTech Team";
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
        message.setSubject("HanGo - Course Enrollment Confirmation");
        message.setText("Dear " + (learnerName != null && !learnerName.trim().isEmpty() ? learnerName : "Learner") + ",\n\n" +
                "Congratulations! You have successfully enrolled in a course on the HanGo platform.\n\n" +
                "ORDER DETAILS:\n" +
                "- Course Title: " + courseTitle + "\n" +
                "- Tuition Fee: " + priceText + "\n" +
                "- Access Status: FULLY UNLOCKED\n\n" +
                "You can access your course immediately to start learning:\n" +
                "https://hangog92.online\n\n" +
                "We wish you a wonderful learning experience with HanGo!\n\n" +
                "Best regards,\n" +
                "HanGo EdTech Team");

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

    public void sendSettlementPaidEmail(String toEmail, String trainerName, String periodMonth, String netPayoutText, String bankTxnRef, String receiptUrl) {
        SimpleMailMessage message = new SimpleMailMessage();
        message.setTo(toEmail);
        message.setSubject("HanGo - Monthly Revenue Settlement Confirmation");
        message.setText("Dear " + (trainerName != null && !trainerName.trim().isEmpty() ? trainerName : "Trainer") + ",\n\n" +
                "Your monthly revenue payout for period " + periodMonth + " has been successfully processed and transferred to your registered bank account.\n\n" +
                "PAYOUT DETAILS:\n" +
                "- Statement Period: " + periodMonth + "\n" +
                "- Net Payout Amount: " + netPayoutText + "\n" +
                (bankTxnRef != null && !bankTxnRef.trim().isEmpty() ? "- Bank Transaction Ref: " + bankTxnRef + "\n" : "") +
                (receiptUrl != null && !receiptUrl.trim().isEmpty() ? "- Payout Receipt URL: " + receiptUrl + "\n" : "") +
                "- Status: PAID & COMPLETED\n\n" +
                "You can log into your Trainer Dashboard to review full transaction items and statements:\n" +
                "https://hangog92.online/trainer/revenue\n\n" +
                "Thank you for creating high-quality learning content with HanGo!\n\n" +
                "Best regards,\n" +
                "HanGo EdTech Team");

        try {
            if (mailSender != null) {
                mailSender.send(message);
                System.out.println("[EMAIL SUCCESS] Sent revenue settlement confirmation email to: " + toEmail);
            } else {
                System.out.println("[EMAIL SUCCESS LOG] Revenue Settlement Email: " + toEmail + " -> Period: " + periodMonth + " (" + netPayoutText + ")");
            }
        } catch (Exception e) {
            System.err.println("[EMAIL WARNING] Could not send settlement email: " + e.getMessage());
        }
    }
}
