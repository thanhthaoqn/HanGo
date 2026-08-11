package com.hango.hango_backend.repository;

import com.hango.hango_backend.entity.Certificate;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.stereotype.Repository;

import java.util.Optional;

@Repository
public interface CertificateRepository extends JpaRepository<Certificate, Long> {
    Optional<Certificate> findByUserIdAndCourseId(Long userId, Long courseId);

    Optional<Certificate> findByCredentialId(String credentialId);

    boolean existsByUserIdAndCourseId(Long userId, Long courseId);
}
