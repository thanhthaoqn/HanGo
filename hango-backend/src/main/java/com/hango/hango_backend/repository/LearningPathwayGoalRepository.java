package com.hango.hango_backend.repository;

import com.hango.hango_backend.entity.LearningPathwayGoal;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.stereotype.Repository;

import java.util.List;

@Repository
public interface LearningPathwayGoalRepository extends JpaRepository<LearningPathwayGoal, Long> {
    List<LearningPathwayGoal> findByLearningPathwayIdOrderByPriorityAsc(Long pathwayId);
    void deleteByLearningPathwayId(Long pathwayId);
}
