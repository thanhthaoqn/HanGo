package com.hango.hango_backend.service;

import com.hango.hango_backend.dto.CertificateDTO;
import com.hango.hango_backend.entity.Certificate;
import com.hango.hango_backend.entity.Course;
import com.hango.hango_backend.entity.User;
import com.hango.hango_backend.repository.CertificateRepository;
import com.hango.hango_backend.repository.CourseRepository;
import com.hango.hango_backend.repository.UserRepository;
import lombok.RequiredArgsConstructor;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.time.LocalDateTime;
import java.util.UUID;

@Service
@RequiredArgsConstructor
public class CertificateService {

    private final CertificateRepository certificateRepository;
    private final CourseRepository courseRepository;
    private final UserRepository userRepository;

    @Transactional
    public void generateCertificateIfNotExists(Long userId, Long courseId) {
        if (certificateRepository.existsByUserIdAndCourseId(userId, courseId)) {
            return;
        }

        User user = userRepository.findById(userId)
                .orElseThrow(() -> new RuntimeException("User not found"));
        Course course = courseRepository.findById(courseId)
                .orElseThrow(() -> new RuntimeException("Course not found"));

        Certificate certificate = Certificate.builder()
                .user(user)
                .course(course)
                .credentialId(generateCredentialId())
                .issuedAt(LocalDateTime.now())
                .build();

        certificateRepository.save(certificate);
    }

    @Transactional(readOnly = true)
    public CertificateDTO getCertificate(Long userId, Long courseId) {
        Certificate certificate = certificateRepository.findByUserIdAndCourseId(userId, courseId)
                .orElseThrow(() -> new RuntimeException("Certificate not found for this user and course"));

        return mapToDTO(certificate);
    }

    @Transactional(readOnly = true)
    public CertificateDTO getCertificateByCredentialId(String credentialId) {
        Certificate certificate = certificateRepository.findByCredentialId(credentialId)
                .orElseThrow(() -> new RuntimeException("Certificate not found with ID: " + credentialId));

        return mapToDTO(certificate);
    }

    private String generateCredentialId() {
        return "HG-" + UUID.randomUUID().toString().substring(0, 8).toUpperCase();
    }

    private CertificateDTO mapToDTO(Certificate certificate) {
        User trainer = certificate.getCourse().getCreator();

        return CertificateDTO.builder()
                .credentialId(certificate.getCredentialId())
                .learnerName(certificate.getUser().getFullName())
                .courseTitle(certificate.getCourse().getTitle())
                .trainerName(trainer != null ? trainer.getFullName() : "HanGo Trainer")
                .trainerSignatureUrl(null)
                .issuedAt(certificate.getIssuedAt())
                .build();
    }
}
