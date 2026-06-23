package com.hango.hango_backend.repository;

import java.time.LocalDateTime;

public interface TrainerCourseDetailProjection {
    Long getId();
    String getTitle();
    String getStatus();
    String getDescription();
    Long getLearnersCount();
    Long getLessonsCount();
    String getThumbnailUrl();
    LocalDateTime getCreatedAt();
}
