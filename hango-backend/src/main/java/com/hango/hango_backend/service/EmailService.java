package com.hango.hango_backend.service;

import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.mail.SimpleMailMessage;
import org.springframework.mail.javamail.JavaMailSender;
import org.springframework.stereotype.Service;
import lombok.extern.slf4j.Slf4j;

import java.net.URLEncoder;
import java.nio.charset.StandardCharsets;

@Service
@Slf4j
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
                log.info("Password reset OTP email sent");
            } else {
                log.warn("JavaMailSender is not initialized; OTP email was not sent");
            }
        } catch (Exception e) {
            log.warn("Could not send password reset OTP email: {}", e.getMessage());
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
                log.info("Account verification email sent");
            } else {
                log.warn("JavaMailSender is not initialized; verification email was not sent");
            }
        } catch (Exception e) {
            log.warn("Could not send account verification email: {}", e.getMessage());
        }
    }

    public void sendTrainerStatusNotificationEmail(String toEmail, String status, String adminNotes) {
        sendTrainerStatusNotificationEmail(toEmail, null, status, adminNotes);
    }

    public void sendTrainerStatusNotificationEmail(String toEmail, String trainerName, String status,
            String adminNotes) {
        final String safeEmail = (toEmail != null) ? escapeHtml(toEmail.trim()) : "";
        final String safeName = (trainerName != null && !trainerName.trim().isEmpty()) ? escapeHtml(trainerName.trim())
                : "Trainer";
        final String safeNotes = (adminNotes != null && !adminNotes.trim().isEmpty()) ? escapeHtml(adminNotes.trim())
                : "";
        final boolean isApproved = "VERIFIED".equalsIgnoreCase(status);
        final boolean isSuspended = "SUSPENDED".equalsIgnoreCase(status);

        String subject;
        String badgeColor;
        String badgeText;
        String title;
        String subtitle;
        String ctaText;
        String ctaUrl;
        String ctaColor;
        String detailsHtml;

        if (isApproved) {
            subject = "HanGo - Trainer Profile Approved!";
            badgeColor = "#059669";
            badgeText = "✓ Application Approved";
            title = "Congratulations! Your Trainer Profile is Approved 🎉";
            subtitle = "Hi <strong style=\"color: #0d9488 !important;\">" + safeName
                    + "</strong>, we are thrilled to welcome you to the HanGo teaching community! Your application has been reviewed and officially approved by administration.";
            ctaText = "Access Trainer Dashboard &rarr;";
            ctaUrl = "https://hangog92.online/login";
            ctaColor = "#28b79b";

            detailsHtml = "<table role=\"presentation\" width=\"100%\" cellspacing=\"0\" cellpadding=\"0\" style=\"background-color: #f8fafc; border-radius: 14px; border: 1px solid #e2e8f0; overflow: hidden; margin-bottom: 24px; padding: 20px 24px;\">"
                    + "  <tr>"
                    + "    <td>"
                    + "      <h3 style=\"margin: 0 0 12px 0; color: #0f172a !important; font-size: 15px; font-weight: 700;\">Application Details</h3>"
                    + "      <table role=\"presentation\" width=\"100%\" cellspacing=\"0\" cellpadding=\"0\">"
                    + "        <tr>"
                    + "          <td style=\"color: #64748b !important; font-size: 13.5px; padding: 5px 0;\">Applicant:</td>"
                    + "          <td align=\"right\" style=\"color: #0f172a !important; font-size: 13.5px; font-weight: 600;\">"
                    + safeName + "</td>"
                    + "        </tr>"
                    + "        <tr>"
                    + "          <td style=\"color: #64748b !important; font-size: 13.5px; padding: 5px 0;\">Email:</td>"
                    + "          <td align=\"right\" style=\"color: #0f172a !important; font-size: 13.5px; font-weight: 600;\">"
                    + safeEmail + "</td>"
                    + "        </tr>"
                    + "        <tr>"
                    + "          <td style=\"color: #64748b !important; font-size: 13.5px; padding: 5px 0;\">Application Status:</td>"
                    + "          <td align=\"right\" style=\"color: #059669 !important; font-size: 13.5px; font-weight: 700;\">Active & Verified ✓</td>"
                    + "        </tr>"
                    + "      </table>"
                    + (!safeNotes.isEmpty()
                            ? "<div style=\"margin-top: 14px; padding: 12px 16px; background-color: #ecfdf5; border-radius: 8px; border-left: 4px solid #059669; text-align: left;\">"
                                    + "<strong style=\"color: #065f46 !important; font-size: 13px; display: block; margin-bottom: 4px;\">Admin Notes:</strong>"
                                    + "<span style=\"color: #047857 !important; font-size: 13.5px; line-height: 1.5;\">"
                                    + safeNotes + "</span>"
                                    + "</div>"
                            : "")
                    + "    </td>"
                    + "  </tr>"
                    + "</table>"
                    + "<div style=\"background-color: #ffffff; border-radius: 12px; border: 1px solid #e2e8f0; padding: 18px 20px; margin-bottom: 24px; text-align: left;\">"
                    + "  <h4 style=\"margin: 0 0 10px 0; color: #0f172a !important; font-size: 14px; font-weight: 700;\">Next Steps for You:</h4>"
                    + "  <p style=\"margin: 0 0 6px 0; color: #475569 !important; font-size: 13px; line-height: 1.5;\">1. Complete your <strong>Payout Setup</strong> (Bank Account) in Settlement Settings to receive course earnings.</p>"
                    + "  <p style=\"margin: 0 0 6px 0; color: #475569 !important; font-size: 13px; line-height: 1.5;\">2. Create and publish high-quality courses, upload video lessons & structured chapters.</p>"
                    + "  <p style=\"margin: 0 0 6px 0; color: #475569 !important; font-size: 13px; line-height: 1.5;\">3. Publish practice exams and track student performance in real-time.</p>"
                    + "</div>";
        } else if (isSuspended) {
            subject = "HanGo - Trainer Account Status Notice (Suspended)";
            badgeColor = "#d97706";
            badgeText = "⚠ Account Suspended";
            title = "Trainer Account Status Notification";
            subtitle = "Hi <strong style=\"color: #b45309 !important;\">" + safeName
                    + "</strong>, your trainer account status on HanGo has been set to <strong>SUSPENDED</strong> by system administration.";
            ctaText = "Contact Support Team &rarr;";
            ctaUrl = "mailto:hangog92su26@gmail.com";
            ctaColor = "#475569";

            detailsHtml = "<table role=\"presentation\" width=\"100%\" cellspacing=\"0\" cellpadding=\"0\" style=\"background-color: #f8fafc; border-radius: 14px; border: 1px solid #e2e8f0; overflow: hidden; margin-bottom: 24px; padding: 20px 24px;\">"
                    + "  <tr>"
                    + "    <td>"
                    + "      <h3 style=\"margin: 0 0 12px 0; color: #0f172a !important; font-size: 15px; font-weight: 700;\">Account Status</h3>"
                    + "      <table role=\"presentation\" width=\"100%\" cellspacing=\"0\" cellpadding=\"0\">"
                    + "        <tr>"
                    + "          <td style=\"color: #64748b !important; font-size: 13.5px; padding: 5px 0;\">Email:</td>"
                    + "          <td align=\"right\" style=\"color: #0f172a !important; font-size: 13.5px; font-weight: 600;\">"
                    + safeEmail + "</td>"
                    + "        </tr>"
                    + "        <tr>"
                    + "          <td style=\"color: #64748b !important; font-size: 13.5px; padding: 5px 0;\">Current Status:</td>"
                    + "          <td align=\"right\" style=\"color: #d97706 !important; font-size: 13.5px; font-weight: 700;\">Suspended</td>"
                    + "        </tr>"
                    + "      </table>"
                    + (!safeNotes.isEmpty()
                            ? "<div style=\"margin-top: 14px; padding: 12px 16px; background-color: #fffbeb; border-radius: 8px; border-left: 4px solid #d97706; text-align: left;\">"
                                    + "<strong style=\"color: #92400e !important; font-size: 13px; display: block; margin-bottom: 4px;\">Reason:</strong>"
                                    + "<span style=\"color: #b45309 !important; font-size: 13.5px; line-height: 1.5;\">"
                                    + safeNotes + "</span>"
                                    + "</div>"
                            : "")
                    + "    </td>"
                    + "  </tr>"
                    + "</table>";
        } else {
            subject = "HanGo - Trainer Application Rejected.";
            badgeColor = "#dc2626";
            badgeText = "✕ Application Rejected";
            title = "Trainer Application Status Update";
            subtitle = "Hi <strong style=\"color: #e11d48 !important;\">" + safeName
                    + "</strong>, thank you for applying to become a Trainer on HanGo. After evaluating your profile and documents, your application was not approved at this time.";
            ctaText = "Update and Resubmit Application &rarr;";
            ctaUrl = "https://hangog92.online/login";
            ctaColor = "#0f172a";

            detailsHtml = "<div style=\"background-color: #fff1f2; border: 1px solid #fecdd3; border-left: 4px solid #e11d48; border-radius: 12px; padding: 18px 20px; margin-bottom: 24px; text-align: left;\">"
                    + "  <h3 style=\"margin: 0 0 8px 0; color: #9f1239 !important; font-size: 15px; font-weight: 700;\">Feedback & Rejection Reason:</h3>"
                    + "  <p style=\"margin: 0; color: #881337 !important; font-size: 14px; line-height: 1.6;\">"
                    + (!safeNotes.isEmpty() ? safeNotes
                            : "Credentials or pedagogical documents require updates. Please review and provide clear certificates.")
                    + "  </p>"
                    + "</div>"
                    + "<div style=\"background-color: #ffffff; border-radius: 12px; border: 1px solid #e2e8f0; padding: 18px 20px; margin-bottom: 24px; text-align: left;\">"
                    + "  <h4 style=\"margin: 0 0 10px 0; color: #0f172a !important; font-size: 14px; font-weight: 700;\">Next Steps for You:</h4>"
                    + "  <p style=\"margin: 0 0 6px 0; color: #475569 !important; font-size: 13px; line-height: 1.5;\">1. Sign in to your HanGo account and review the administrator's feedback.</p>"
                    + "  <p style=\"margin: 0 0 6px 0; color: #475569 !important; font-size: 13px; line-height: 1.5;\">2. Update your trainer profile and upload clear, complete supporting documents.</p>"
                    + "  <p style=\"margin: 0; color: #475569 !important; font-size: 13px; line-height: 1.5;\">3. Resubmit your application for another review.</p>"
                    + "</div>";
        }

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
                + "                    <span style=\"background-color: " + badgeColor
                + "; color: #ffffff !important; font-size: 12px; font-weight: 700; padding: 8px 20px; border-radius: 20px; text-transform: uppercase; letter-spacing: 0.5px; display: inline-block;\">"
                + "                      " + badgeText
                + "                    </span>"
                + "                  </td>"
                + "                </tr>"
                + "                <tr>"
                + "                  <td align=\"center\" style=\"padding-bottom: 12px;\">"
                + "                    <h1 style=\"margin: 0; color: #0f172a !important; font-size: 22px; font-weight: 800; text-align: center;\">"
                + title + "</h1>"
                + "                  </td>"
                + "                </tr>"
                + "                <tr>"
                + "                  <td align=\"center\" style=\"padding-bottom: 24px;\">"
                + "                    <p style=\"margin: 0; color: #334155 !important; font-size: 15px; line-height: 1.6; text-align: center;\">"
                + "                      " + subtitle
                + "                    </p>"
                + "                  </td>"
                + "                </tr>"
                + "              </table>"
                + detailsHtml
                + (ctaText != null && !ctaText.trim().isEmpty()
                        ? "<table role=\"presentation\" width=\"100%\" cellspacing=\"0\" cellpadding=\"0\" style=\"margin-bottom: 24px;\">"
                                + "  <tr>"
                                + "    <td align=\"center\">"
                                + "      <a href=\"" + ctaUrl + "\" target=\"_blank\" style=\"background-color: "
                                + ctaColor
                                + "; color: #ffffff !important; text-decoration: none; font-size: 16px; font-weight: 700; padding: 14px 36px; border-radius: 10px; display: inline-block; box-shadow: 0 4px 14px rgba(0,0,0,0.15);\">"
                                + "        " + ctaText
                                + "      </a>"
                                + "    </td>"
                                + "  </tr>"
                                + "</table>"
                        : "")
                + "              <p style=\"margin: 0; color: #64748b !important; font-size: 13px; text-align: center; line-height: 1.5;\">"
                + "                If you have any questions, please reach out to <a href=\"mailto:hangog92su26@gmail.com\" style=\"color: #28b79b !important; text-decoration: none; font-weight: 600;\">hangog92su26@gmail.com</a>."
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
                helper.setSubject(subject);
                helper.setText(htmlContent, true);
                mailSender.send(mimeMessage);
                log.info("Trainer status email sent for status {}", status);
            } else {
                log.warn("JavaMailSender is not initialized; trainer status email was not sent");
            }
        } catch (Exception e) {
            log.warn("Could not send trainer status email: {}", e.getMessage());
        }
    }

    private String escapeHtml(String input) {
        if (input == null)
            return "";
        return input.replace("&", "&amp;")
                .replace("<", "&lt;")
                .replace(">", "&gt;")
                .replace("\"", "&quot;")
                .replace("'", "&#39;")
                .replace("\n", "<br/>");
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
                log.info("Course enrollment email sent");
            } else {
                log.warn("JavaMailSender is not initialized; course enrollment email was not sent");
            }
        } catch (Exception e) {
            log.warn("Could not send course enrollment email: {}", e.getMessage());
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
                log.info("Revenue settlement email sent");
            } else {
                log.warn("JavaMailSender is not initialized; revenue settlement email was not sent");
            }
        } catch (Exception e) {
            log.warn("Could not send revenue settlement email: {}", e.getMessage());
        }
    }
}
