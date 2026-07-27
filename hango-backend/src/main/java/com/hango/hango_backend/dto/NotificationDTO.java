package com.hango.hango_backend.dto;

import lombok.Builder;
import lombok.Data;

import java.time.LocalDateTime;

@Data
@Builder
public class NotificationDTO {
    private Long id;
    private String type;
    private String title;
    private String message;
    private Long courseId;
    private String courseTitle;
    private boolean read;
    private LocalDateTime createdAt;
}
