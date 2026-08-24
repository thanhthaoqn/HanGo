package com.hango.hango_backend.service;

import com.hango.hango_backend.exception.ApiException;
import org.junit.jupiter.api.Test;
import org.springframework.http.HttpStatus;
import org.springframework.mock.web.MockMultipartFile;

import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.junit.jupiter.api.Assertions.assertThrows;

class CloudinaryServiceTest {

    private final CloudinaryService service = new CloudinaryService();

    @Test
    void uploadTrainerAvatarShouldRejectPdf() {
        MockMultipartFile file = new MockMultipartFile(
                "file",
                "avatar.pdf",
                "application/pdf",
                "%PDF-1.7".getBytes());

        ApiException exception = assertThrows(ApiException.class,
                () -> service.uploadTrainerAvatar(file));

        assertEquals(HttpStatus.BAD_REQUEST, exception.getStatus());
    }

    @Test
    void uploadTrainerDocumentShouldRejectSpoofedImageExtension() {
        MockMultipartFile file = new MockMultipartFile(
                "file",
                "credential.png",
                "image/png",
                "not-a-real-png".getBytes());

        ApiException exception = assertThrows(ApiException.class,
                () -> service.uploadTrainerDocument(file));

        assertEquals(HttpStatus.BAD_REQUEST, exception.getStatus());
    }
}
