package com.hango.hango_backend.repository;

import com.hango.hango_backend.entity.TrainerProfile;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.stereotype.Repository;

@Repository
public interface TrainerProfileRepository extends JpaRepository<TrainerProfile, Long> {
    @org.springframework.data.jpa.repository.EntityGraph(attributePaths = {"user"})
    @org.springframework.data.jpa.repository.Query("SELECT t FROM TrainerProfile t")
    java.util.List<TrainerProfile> findAllWithUser();

    // ── Dashboard aggregate queries ──

    @org.springframework.data.jpa.repository.Query("SELECT t.status, COUNT(t) FROM TrainerProfile t GROUP BY t.status")
    java.util.List<Object[]> countGroupedByStatus();
}
