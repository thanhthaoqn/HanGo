package com.hango.hango_backend.repository;

import com.hango.hango_backend.entity.Section;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.stereotype.Repository;

import java.util.List;

@Repository
public interface SectionRepository extends JpaRepository<Section, Long> {
    List<Section> findByCourseIdOrderByDisplayOrderAsc(Long courseId);
}
