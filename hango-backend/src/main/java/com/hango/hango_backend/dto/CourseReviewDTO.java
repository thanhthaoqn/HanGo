package com.hango.hango_backend.dto;

import lombok.Builder;
import lombok.Data;

import java.time.LocalDateTime;

@Data
@Builder
public class CourseReviewDTO {
    private Long id;
    private Long userId;
    private String userName; // e.g. nguyenth*********@gmail.com
    private String userInitial; // e.g. N
    private String userAvatar;
    private Short rating;
    private String content;
    private LocalDateTime createdAt;
}
