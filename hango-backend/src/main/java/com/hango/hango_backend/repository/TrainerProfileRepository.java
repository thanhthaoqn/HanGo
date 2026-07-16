package com.hango.hango_backend.repository;

import com.hango.hango_backend.entity.TrainerProfile;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.stereotype.Repository;

@Repository
public interface TrainerProfileRepository extends JpaRepository<TrainerProfile, Long> {
}
