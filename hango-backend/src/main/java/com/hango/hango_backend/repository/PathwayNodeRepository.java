package com.hango.hango_backend.repository;

import com.hango.hango_backend.entity.PathwayNode;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.stereotype.Repository;

@Repository
public interface PathwayNodeRepository extends JpaRepository<PathwayNode, Long> {
}
