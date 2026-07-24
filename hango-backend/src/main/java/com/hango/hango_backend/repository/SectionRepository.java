package com.hango.hango_backend.repository;

import com.hango.hango_backend.entity.Section;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.stereotype.Repository;

import java.util.List;

@Repository
public interface SectionRepository extends JpaRepository<Section, Long> {
    List<Section> findByCourseIdOrderByDisplayOrderAsc(Long courseId);

    @org.springframework.data.jpa.repository.Query("SELECT COUNT(s) FROM Section s WHERE s.course.id = :courseId")
    long countByCourseId(@org.springframework.data.repository.query.Param("courseId") Long courseId);
}
