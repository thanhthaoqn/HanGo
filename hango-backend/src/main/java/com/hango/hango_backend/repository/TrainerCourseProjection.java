package com.hango.hango_backend.repository;

public interface TrainerCourseProjection {
    Long getId();
    String getTitle();
    Long getLearnersCount();
    Long getLessonsCount();
    String getThumbnailUrl();
}
