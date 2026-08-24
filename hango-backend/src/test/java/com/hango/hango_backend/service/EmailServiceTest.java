package com.hango.hango_backend.service;

import java.util.Properties;

import jakarta.mail.Multipart;
import jakarta.mail.Part;
import jakarta.mail.Session;
import jakarta.mail.internet.MimeMessage;

import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.junit.jupiter.api.Assertions.assertTrue;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.api.extension.ExtendWith;
import org.mockito.InjectMocks;
import org.mockito.Mock;
import static org.mockito.Mockito.verify;
import static org.mockito.Mockito.when;
import org.mockito.junit.jupiter.MockitoExtension;
import org.springframework.mail.javamail.JavaMailSender;

@ExtendWith(MockitoExtension.class)
class EmailServiceTest {

    @Mock
    private JavaMailSender mailSender;

    @InjectMocks
    private EmailService emailService;

    @Test
    void rejectedTrainerEmailShouldIncludeActionableNextSteps() throws Exception {
        MimeMessage message = new MimeMessage(Session.getInstance(new Properties()));
        when(mailSender.createMimeMessage()).thenReturn(message);

        emailService.sendTrainerStatusNotificationEmail(
                "trainer@example.com",
                "Trainer Name",
                "PENDING_VERIFICATION",
                "Please upload a clearer certificate.");

        verify(mailSender).send(message);
        assertEquals("HanGo - Trainer Application Rejected.", message.getSubject());

        String html = extractText(message);
        assertTrue(html.contains("Next Steps for You:"));
        assertTrue(html.contains("review the administrator's feedback"));
        assertTrue(html.contains("Update your trainer profile"));
        assertTrue(html.contains("Resubmit your application for another review"));
        assertTrue(html.contains("https://hangog92.online/login"));
    }

    private String extractText(Part part) throws Exception {
        Object content = part.getContent();
        if (content instanceof String text) {
            return text;
        }
        if (content instanceof Multipart multipart) {
            StringBuilder result = new StringBuilder();
            for (int index = 0; index < multipart.getCount(); index++) {
                result.append(extractText(multipart.getBodyPart(index)));
            }
            return result.toString();
        }
        return "";
    }
}
