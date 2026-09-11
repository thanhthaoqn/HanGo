package com.hango.hango_backend.repository;

import com.hango.hango_backend.entity.TrainerProfile;
import jakarta.persistence.LockModeType;
import org.springframework.data.jpa.repository.Lock;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.Query;
import org.springframework.data.repository.query.Param;
import org.springframework.stereotype.Repository;

import java.util.Optional;

@Repository
public interface TrainerProfileRepository extends JpaRepository<TrainerProfile, Long> {
    @org.springframework.data.jpa.repository.EntityGraph(attributePaths = {"user"})
    @org.springframework.data.jpa.repository.Query("SELECT t FROM TrainerProfile t")
    java.util.List<TrainerProfile> findAllWithUser();

    @Lock(LockModeType.PESSIMISTIC_WRITE)
    @Query("SELECT t FROM TrainerProfile t LEFT JOIN FETCH t.user WHERE t.userId = :userId")
    Optional<TrainerProfile> findByIdForUpdate(@Param("userId") Long userId);

    // ── Dashboard aggregate queries ──

    @org.springframework.data.jpa.repository.Query("SELECT t.status, COUNT(t) FROM TrainerProfile t GROUP BY t.status")
    java.util.List<Object[]> countGroupedByStatus();
}
