package com.hango.hango_backend.service;

import com.cloudinary.Cloudinary;
import com.cloudinary.utils.ObjectUtils;
import com.hango.hango_backend.exception.ApiException;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.http.HttpStatus;
import org.springframework.stereotype.Service;
import org.springframework.web.multipart.MultipartFile;

import jakarta.annotation.PostConstruct;
import java.io.IOException;
import java.util.Locale;
import java.util.Map;
import java.util.Set;

@Service
public class CloudinaryService {

    private static final long MAX_TRAINER_DOCUMENT_BYTES = 5L * 1024 * 1024;
    private static final long MAX_TRAINER_AVATAR_BYTES = 2L * 1024 * 1024;
    private static final Set<String> TRAINER_DOCUMENT_EXTENSIONS = Set.of("pdf", "png", "jpg", "jpeg", "webp");
    private static final Set<String> TRAINER_AVATAR_EXTENSIONS = Set.of("png", "jpg", "jpeg", "webp");

    @Value("${cloudinary.cloud-name}")
    private String cloudName;

    @Value("${cloudinary.api-key}")
    private String apiKey;

    @Value("${cloudinary.api-secret}")
    private String apiSecret;

    private Cloudinary cloudinary;

    @PostConstruct
    public void init() {
        cloudinary = new Cloudinary(ObjectUtils.asMap(
                "cloud_name", cloudName,
                "api_key", apiKey,
                "api_secret", apiSecret,
                "secure", true
        ));
    }

    @SuppressWarnings("rawtypes")
    public String uploadImage(MultipartFile file) throws IOException {
        Map uploadResult = cloudinary.uploader().upload(file.getBytes(), ObjectUtils.emptyMap());
        return uploadResult.get("secure_url").toString();
    }

    @SuppressWarnings("rawtypes")
    public String uploadVideo(MultipartFile file) throws IOException {
        Map uploadResult = cloudinary.uploader().upload(file.getBytes(), ObjectUtils.asMap("resource_type", "video"));
        return uploadResult.get("secure_url").toString();
    }

    @SuppressWarnings("rawtypes")
    public String uploadTrainerDocument(MultipartFile file) throws IOException {
        validateTrainerFile(file, MAX_TRAINER_DOCUMENT_BYTES, TRAINER_DOCUMENT_EXTENSIONS);
        Map uploadResult = cloudinary.uploader().upload(
                file.getBytes(),
                ObjectUtils.asMap(
                        "resource_type", "auto",
                        "folder", "hango/trainer-documents",
                        "use_filename", false,
                        "unique_filename", true));
        Object secureUrl = uploadResult.get("secure_url");
        if (secureUrl == null) {
            throw new IOException("Cloudinary did not return a secure URL.");
        }
        return secureUrl.toString();
    }

    @SuppressWarnings("rawtypes")
    public String uploadTrainerAvatar(MultipartFile file) throws IOException {
        validateTrainerFile(file, MAX_TRAINER_AVATAR_BYTES, TRAINER_AVATAR_EXTENSIONS);
        Map uploadResult = cloudinary.uploader().upload(
                file.getBytes(),
                ObjectUtils.asMap(
                        "resource_type", "image",
                        "folder", "hango/trainer-avatars",
                        "use_filename", false,
                        "unique_filename", true));
        Object secureUrl = uploadResult.get("secure_url");
        if (secureUrl == null) {
            throw new IOException("Cloudinary did not return a secure URL.");
        }
        return secureUrl.toString();
    }

    private void validateTrainerFile(MultipartFile file, long maxBytes, Set<String> allowedExtensions)
            throws IOException {
        if (file == null || file.isEmpty()) {
            throw new ApiException("A non-empty trainer file is required.", HttpStatus.BAD_REQUEST);
        }
        if (file.getSize() > maxBytes) {
            throw new ApiException("The trainer file exceeds the allowed size.", HttpStatus.BAD_REQUEST);
        }

        String fileName = file.getOriginalFilename() == null ? "" : file.getOriginalFilename().trim();
        int dotIndex = fileName.lastIndexOf('.');
        String extension = dotIndex >= 0 ? fileName.substring(dotIndex + 1).toLowerCase(Locale.ROOT) : "";
        if (!allowedExtensions.contains(extension)) {
            throw new ApiException("The trainer file type is not allowed.", HttpStatus.BAD_REQUEST);
        }

        byte[] bytes = file.getBytes();
        boolean pdf = startsWith(bytes, new int[] {0x25, 0x50, 0x44, 0x46, 0x2D});
        boolean png = startsWith(bytes, new int[] {0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A});
        boolean jpeg = startsWith(bytes, new int[] {0xFF, 0xD8, 0xFF});
        boolean webp = bytes.length >= 12
                && startsWith(bytes, new int[] {0x52, 0x49, 0x46, 0x46})
                && bytes[8] == 0x57 && bytes[9] == 0x45 && bytes[10] == 0x42 && bytes[11] == 0x50;

        boolean signatureMatches = switch (extension) {
            case "pdf" -> pdf;
            case "png" -> png;
            case "jpg", "jpeg" -> jpeg;
            case "webp" -> webp;
            default -> false;
        };
        if (!signatureMatches) {
            throw new ApiException("The uploaded file content does not match its extension.", HttpStatus.BAD_REQUEST);
        }
    }

    private boolean startsWith(byte[] bytes, int[] signature) {
        if (bytes.length < signature.length) {
            return false;
        }
        for (int index = 0; index < signature.length; index++) {
            if ((bytes[index] & 0xFF) != signature[index]) {
                return false;
            }
        }
        return true;
    }

    public void deleteFile(String fileUrl) {
        if (fileUrl == null || !fileUrl.contains("res.cloudinary.com")) {
            return;
        }
        try {
            // Extract public_id from URL
            // Format: http://res.cloudinary.com/cloud_name/resource_type/upload/v1234567890/public_id.ext
            int uploadIndex = fileUrl.indexOf("/upload/");
            if (uploadIndex == -1) return;
            String afterUpload = fileUrl.substring(uploadIndex + 8);
            
            // Remove version if present (e.g. v1234567890/)
            if (afterUpload.matches("^v\\d+/.*")) {
                afterUpload = afterUpload.substring(afterUpload.indexOf("/") + 1);
            }
            
            // Remove extension
            int lastDotIndex = afterUpload.lastIndexOf(".");
            String publicId = (lastDotIndex != -1) ? afterUpload.substring(0, lastDotIndex) : afterUpload;
            
            String resourceType = fileUrl.contains("/video/") ? "video" : "image";
            
            cloudinary.uploader().destroy(publicId, ObjectUtils.asMap("resource_type", resourceType));
            System.out.println("Deleted Cloudinary file: " + publicId);
        } catch (Exception e) {
            System.err.println("Failed to delete Cloudinary file: " + fileUrl + " - " + e.getMessage());
        }
    }
}
