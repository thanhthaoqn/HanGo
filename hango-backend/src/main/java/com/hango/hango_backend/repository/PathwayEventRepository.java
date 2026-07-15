package com.hango.hango_backend.repository;

import com.hango.hango_backend.entity.PathwayEvent;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.stereotype.Repository;

import java.util.List;

@Repository
public interface PathwayEventRepository extends JpaRepository<PathwayEvent, Long> {
    List<PathwayEvent> findByPathwayIdOrderByCreatedAtDesc(Long pathwayId);
    List<PathwayEvent> findByPathwayIdAndEventTypeOrderByCreatedAtDesc(Long pathwayId, String eventType);
}
