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
                "This OTP code is valid for 5 minutes. If you did not request this, you can safely ignore this email.\n\n"
                +
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
        String verifyUrl = appBaseUrl + "/api/auth/verify?token="
                + URLEncoder.encode(verificationToken, StandardCharsets.UTF_8);
        SimpleMailMessage message = new SimpleMailMessage();
        message.setTo(toEmail);
        message.setSubject("HanGo - Verify Your Account");
        message.setText("Hello,\n\n" +
                "Thank you for registering on HanGo. Please click the link below to verify and activate your account:\n\n"
                +
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
                    "You can now complete your payout setup to access your Trainer Dashboard, create courses, and publish exams.\n\n"
                    +
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
                    (adminNotes != null && !adminNotes.trim().isEmpty()
                            ? "Rejection Reason & Required Edits: " + adminNotes + "\n\n"
                            : "Please log into HanGo to view rejection details.\n\n")
                    +
                    "Please log into your account, update your profile details and certificates as requested, and resubmit:\n"
                    +
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
                System.out.println("[EMAIL WARN] JavaMailSender not initialized. Trainer Status Email: " + toEmail
                        + " -> " + status);
            }
        } catch (Exception e) {
            System.err.println("[EMAIL WARNING] Could not send trainer status email: " + e.getMessage());
        }
    }

    public void sendEnrollmentSuccessEmail(String toEmail, String learnerName, String courseTitle, String priceText) {
        sendEnrollmentSuccessEmail(toEmail, learnerName, courseTitle, priceText, null);
    }

    public void sendEnrollmentSuccessEmail(String toEmail, String learnerName, String courseTitle, String priceText,
            String courseImageUrl) {
        final String safeName = (learnerName != null && !learnerName.trim().isEmpty()) ? learnerName.trim() : "Learner";
        final String safeTitle = (courseTitle != null && !courseTitle.trim().isEmpty()) ? courseTitle.trim()
                : "HanGo Online Course";
        final String safePrice = (priceText != null && !priceText.trim().isEmpty()) ? priceText.trim() : "Free";
        final String safeImageUrl = (courseImageUrl != null && !courseImageUrl.trim().isEmpty())
                ? courseImageUrl.trim()
                : "https://images.unsplash.com/photo-1516321318423-f06f85e504b3?w=800&auto=format&fit=crop&q=80";

        final String htmlContent = "<!DOCTYPE html>"
                + "<html>"
                + "<head><meta charset=\"UTF-8\"><meta name=\"viewport\" content=\"width=device-width, initial-scale=1.0\"></head>"
                + "<body style=\"margin: 0; padding: 0; background-color: #f1f5f9; font-family: 'Segoe UI', Roboto, Helvetica, Arial, sans-serif; color: #0f172a;\">"
                + "  <table role=\"presentation\" width=\"100%\" cellspacing=\"0\" cellpadding=\"0\" style=\"background-color: #f1f5f9; padding: 30px 10px;\">"
                + "    <tr>"
                + "      <td align=\"center\">"
                + "        <table role=\"presentation\" width=\"100%\" style=\"max-width: 600px; background-color: #ffffff; color: #0f172a; border-radius: 16px; overflow: hidden; box-shadow: 0 10px 25px -5px rgba(0,0,0,0.08); border: 1px solid #e2e8f0;\">"
                + "          <tr>"
                + "            <td align=\"center\" style=\"background: linear-gradient(135deg, #0f172a 0%, #1e293b 100%); padding: 26px 20px; border-bottom: 3px solid #28b79b;\">"
                + "              <img src=\"https://res.cloudinary.com/diqekap4o/image/upload/v1786677289/sbhuvt9wsa7kbsrkmvjm.png\" alt=\"HanGo Logo\" style=\"height: 56px; width: auto; display: block; margin: 0 auto;\">"
                + "            </td>"
                + "          </tr>"
                + "          <tr>"
                + "            <td style=\"padding: 32px 28px; background-color: #ffffff;\">"
                + "              <table role=\"presentation\" width=\"100%\" cellspacing=\"0\" cellpadding=\"0\">"
                + "                <tr>"
                + "                  <td align=\"center\" style=\"padding-bottom: 20px;\">"
                + "                    <span style=\"background-color: #059669; color: #ffffff !important; font-size: 12px; font-weight: 700; padding: 8px 20px; border-radius: 20px; text-transform: uppercase; letter-spacing: 0.5px; display: inline-block;\">"
                + "                      ✓ Enrollment Confirmed"
                + "                    </span>"
                + "                  </td>"
                + "                </tr>"
                + "                <tr>"
                + "                  <td align=\"center\" style=\"padding-bottom: 12px;\">"
                + "                    <h1 style=\"margin: 0; color: #0f172a !important; font-size: 22px; font-weight: 800; text-align: center;\">Congratulations on your enrollment!</h1>"
                + "                  </td>"
                + "                </tr>"
                + "                <tr>"
                + "                  <td align=\"center\" style=\"padding-bottom: 24px;\">"
                + "                    <p style=\"margin: 0; color: #334155 !important; font-size: 15px; line-height: 1.6; text-align: center;\">"
                + "                      Hi <strong style=\"color: #0d9488 !important;\">" + safeName
                + "</strong>, your course registration is confirmed. You now have full unlimited access to all course contents."
                + "                    </p>"
                + "                  </td>"
                + "                </tr>"
                + "              </table>"
                + "              <table role=\"presentation\" width=\"100%\" cellspacing=\"0\" cellpadding=\"0\" style=\"background-color: #f8fafc; border-radius: 14px; border: 1px solid #e2e8f0; overflow: hidden; margin-bottom: 24px;\">"
                + "                <tr>"
                + "                  <td style=\"padding: 0;\">"
                + "                    <img src=\"" + safeImageUrl + "\" alt=\"" + safeTitle
                + "\" style=\"width: 100%; max-height: 240px; object-fit: cover; display: block; border-bottom: 1px solid #e2e8f0;\">"
                + "                  </td>"
                + "                </tr>"
                + "                <tr>"
                + "                  <td style=\"padding: 20px 24px;\">"
                + "                    <h2 style=\"margin: 0 0 8px 0; color: #0f172a !important; font-size: 18px; font-weight: 700; line-height: 1.4;\">"
                + safeTitle + "</h2>"
                + "                    <table role=\"presentation\" width=\"100%\" cellspacing=\"0\" cellpadding=\"0\" style=\"margin-top: 14px; border-top: 1px dashed #cbd5e1; padding-top: 12px;\">"
                + "                      <tr>"
                + "                        <td style=\"color: #475569 !important; font-size: 14px; font-weight: 600;\">Tuition Fee:</td>"
                + "                        <td align=\"right\" style=\"color: #059669 !important; font-size: 16px; font-weight: 800;\">"
                + safePrice + "</td>"
                + "                      </tr>"
                + "                      <tr>"
                + "                        <td style=\"color: #475569 !important; font-size: 14px; font-weight: 600; padding-top: 6px;\">Access Status:</td>"
                + "                        <td align=\"right\" style=\"color: #059669 !important; font-size: 14px; font-weight: 700; padding-top: 6px;\">Lifetime Access 🔓</td>"
                + "                      </tr>"
                + "                    </table>"
                + "                  </td>"
                + "                </tr>"
                + "              </table>"
                + "              <table role=\"presentation\" width=\"100%\" cellspacing=\"0\" cellpadding=\"0\" style=\"margin-bottom: 24px;\">"
                + "                <tr>"
                + "                  <td align=\"center\">"
                + "                    <a href=\"https://hangog92.online\" target=\"_blank\" style=\"background-color: #28b79b; color: #ffffff !important; text-decoration: none; font-size: 16px; font-weight: 700; padding: 14px 36px; border-radius: 10px; display: inline-block; box-shadow: 0 4px 14px rgba(40, 183, 155, 0.35);\">"
                + "                      Start Learning Now &rarr;"
                + "                    </a>"
                + "                  </td>"
                + "                </tr>"
                + "              </table>"
                + "              <p style=\"margin: 0; color: #64748b !important; font-size: 13px; text-align: center; line-height: 1.5;\">"
                + "                If you have any questions, contact our support team at <a href=\"mailto:hangog92su26@gmail.com\" style=\"color: #28b79b !important; text-decoration: none; font-weight: 600;\">hangog92su26@gmail.com</a>."
                + "              </p>"
                + "            </td>"
                + "          </tr>"
                + "          <tr>"
                + "            <td align=\"center\" style=\"background-color: #f8fafc; padding: 20px; border-top: 1px solid #e2e8f0;\">"
                + "              <p style=\"margin: 0 0 4px 0; color: #475569 !important; font-size: 13px; font-weight: 600;\">HanGo EdTech Learning Platform</p>"
                + "              <p style=\"margin: 0; color: #64748b !important; font-size: 12px;\">© 2026 HanGo. All rights reserved.</p>"
                + "            </td>"
                + "          </tr>"
                + "        </table>"
                + "      </td>"
                + "    </tr>"
                + "  </table>"
                + "</body>"
                + "</html>";

        try {
            if (mailSender != null) {
                jakarta.mail.internet.MimeMessage mimeMessage = mailSender.createMimeMessage();
                org.springframework.mail.javamail.MimeMessageHelper helper = new org.springframework.mail.javamail.MimeMessageHelper(
                        mimeMessage, true, "UTF-8");
                helper.setTo(toEmail);
                helper.setSubject("HanGo - Course Enrollment Confirmation");
                helper.setText(htmlContent, true);
                mailSender.send(mimeMessage);
                System.out
                        .println("[EMAIL SUCCESS] Sent HTML enrollment email with logo & course image to: " + toEmail);
            } else {
                System.out.println("[EMAIL SUCCESS LOG] HTML Enrollment Email: " + toEmail + " -> Course: " + safeTitle
                        + " (" + safePrice + ")");
            }
        } catch (Exception e) {
            System.err.println("[EMAIL WARNING] Could not send enrollment HTML email: " + e.getMessage());
        }
    }

    public void sendSettlementPaidEmail(String toEmail, String trainerName, String periodMonth, String netPayoutText,
            String bankTxnRef, String receiptUrl) {
        SimpleMailMessage message = new SimpleMailMessage();
        message.setTo(toEmail);
        message.setSubject("HanGo - Monthly Revenue Settlement Confirmation");
        message.setText("Dear " + (trainerName != null && !trainerName.trim().isEmpty() ? trainerName : "Trainer")
                + ",\n\n" +
                "Your monthly revenue payout for period " + periodMonth
                + " has been successfully processed and transferred to your registered bank account.\n\n" +
                "PAYOUT DETAILS:\n" +
                "- Statement Period: " + periodMonth + "\n" +
                "- Net Payout Amount: " + netPayoutText + "\n" +
                (bankTxnRef != null && !bankTxnRef.trim().isEmpty() ? "- Bank Transaction Ref: " + bankTxnRef + "\n"
                        : "")
                +
                (receiptUrl != null && !receiptUrl.trim().isEmpty() ? "- Payout Receipt URL: " + receiptUrl + "\n" : "")
                +
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
                System.out.println("[EMAIL SUCCESS LOG] Revenue Settlement Email: " + toEmail + " -> Period: "
                        + periodMonth + " (" + netPayoutText + ")");
            }
        } catch (Exception e) {
            System.err.println("[EMAIL WARNING] Could not send settlement email: " + e.getMessage());
        }
    }
}
