package com.hango.hango_backend.repository;

import com.hango.hango_backend.entity.QuestionGroup;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.stereotype.Repository;

@Repository
public interface QuestionGroupRepository extends JpaRepository<QuestionGroup, Long> {
}
