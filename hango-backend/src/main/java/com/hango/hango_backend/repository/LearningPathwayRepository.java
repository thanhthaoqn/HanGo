package com.hango.hango_backend.repository;

import com.hango.hango_backend.entity.LearningPathway;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.stereotype.Repository;

import java.util.Optional;

@Repository
public interface LearningPathwayRepository extends JpaRepository<LearningPathway, Long> {
    Optional<LearningPathway> findByStudentIdAndStatus(Long studentId, String status);
}
