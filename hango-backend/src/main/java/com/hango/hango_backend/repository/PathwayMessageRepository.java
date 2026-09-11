package com.hango.hango_backend.repository;

import com.hango.hango_backend.entity.PathwayMessage;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.stereotype.Repository;

@Repository
public interface PathwayMessageRepository extends JpaRepository<PathwayMessage, Long> {
}
