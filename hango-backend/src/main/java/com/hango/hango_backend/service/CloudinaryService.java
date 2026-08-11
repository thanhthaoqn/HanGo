package com.hango.hango_backend.service;

import com.cloudinary.Cloudinary;
import com.cloudinary.utils.ObjectUtils;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.stereotype.Service;
import org.springframework.web.multipart.MultipartFile;

import jakarta.annotation.PostConstruct;
import java.io.IOException;
import java.util.Map;

@Service
public class CloudinaryService {

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
