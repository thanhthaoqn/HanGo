package com.hango.hango_backend.repository;

import com.hango.hango_backend.entity.CreatorTask;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.stereotype.Repository;

import java.util.List;
import java.util.Optional;

@Repository
public interface CreatorTaskRepository extends JpaRepository<CreatorTask, Long> {
    List<CreatorTask> findByTaskId(Long taskId);
    Optional<CreatorTask> findByTaskIdAndCreatorId(Long taskId, Long creatorId);
}
