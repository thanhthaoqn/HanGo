package com.hango.hango_backend.repository;

import com.hango.hango_backend.entity.SystemParameter;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.stereotype.Repository;
import java.util.Optional;

@Repository
public interface SystemParameterRepository extends JpaRepository<SystemParameter, Long> {
    Optional<SystemParameter> findByParamTypeAndParamKey(String paramType, String paramKey);
}
