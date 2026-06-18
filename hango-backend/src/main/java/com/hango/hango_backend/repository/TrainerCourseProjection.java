package com.hango.hango_backend.repository;

public interface TrainerCourseProjection {
    Long getId();
    String getTitle();
    String getThumbnailUrl();
    String getStatus();
    Long getLearnersCount();
    Long getLessonsCount();
}
