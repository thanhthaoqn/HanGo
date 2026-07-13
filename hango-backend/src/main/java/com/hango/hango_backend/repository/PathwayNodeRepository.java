package com.hango.hango_backend.repository;

import com.hango.hango_backend.entity.PathwayNode;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.stereotype.Repository;
import java.util.List;

@Repository
public interface PathwayNodeRepository extends JpaRepository<PathwayNode, Long> {
    List<PathwayNode> findByLearningPathwayIdOrderByStepOrderAsc(Long pathwayId);
}
