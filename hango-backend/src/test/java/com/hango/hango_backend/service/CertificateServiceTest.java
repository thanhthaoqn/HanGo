package com.hango.hango_backend.service;

import com.hango.hango_backend.dto.CertificateDTO;
import com.hango.hango_backend.entity.Certificate;
import com.hango.hango_backend.entity.Course;
import com.hango.hango_backend.entity.User;
import com.hango.hango_backend.repository.CertificateRepository;
import com.hango.hango_backend.repository.CourseRepository;
import com.hango.hango_backend.repository.UserRepository;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.api.extension.ExtendWith;
import org.mockito.ArgumentCaptor;
import org.mockito.InjectMocks;
import org.mockito.Mock;
import org.mockito.junit.jupiter.MockitoExtension;

import java.time.LocalDateTime;
import java.util.Optional;

import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.junit.jupiter.api.Assertions.assertNotNull;
import static org.junit.jupiter.api.Assertions.assertThrows;
import static org.mockito.ArgumentMatchers.any;
import static org.mockito.Mockito.never;
import static org.mockito.Mockito.verify;
import static org.mockito.Mockito.when;

@ExtendWith(MockitoExtension.class)
class CertificateServiceTest {

    @Mock
    private CertificateRepository certificateRepository;
    @Mock
    private CourseRepository courseRepository;
    @Mock
    private UserRepository userRepository;

    @InjectMocks
    private CertificateService certificateService;

    // =================================================================
    // generateCertificateIfNotExists
    // =================================================================

    @Test
    void generateCertificateIfNotExistsShouldSkipWhenCertificateExists() {
        when(certificateRepository.existsByUserIdAndCourseId(1L, 10L)).thenReturn(true);

        certificateService.generateCertificateIfNotExists(1L, 10L);

        verify(certificateRepository, never()).save(any());
        verify(userRepository, never()).findById(any());
        verify(courseRepository, never()).findById(any());
    }

    @Test
    void generateCertificateIfNotExistsShouldCreateCertificate() {
        User learner = User.builder().id(1L).fullName("Learner One").email("learner@example.com").build();
        User trainer = User.builder().id(2L).fullName("Trainer One").email("trainer@example.com").build();
        Course course = Course.builder().id(10L).title("English Mastery").creator(trainer).build();

        when(certificateRepository.existsByUserIdAndCourseId(1L, 10L)).thenReturn(false);
        when(userRepository.findById(1L)).thenReturn(Optional.of(learner));
        when(courseRepository.findById(10L)).thenReturn(Optional.of(course));

        certificateService.generateCertificateIfNotExists(1L, 10L);

        ArgumentCaptor<Certificate> captor = ArgumentCaptor.forClass(Certificate.class);
        verify(certificateRepository).save(captor.capture());

        Certificate saved = captor.getValue();
        assertEquals(learner, saved.getUser());
        assertEquals(course, saved.getCourse());
        assertNotNull(saved.getIssuedAt());
        assertEquals(true, saved.getCredentialId().startsWith("HG-"));
    }

    @Test
    void generateCertificateIfNotExistsShouldThrowWhenUserNotFound() {
        when(certificateRepository.existsByUserIdAndCourseId(1L, 10L)).thenReturn(false);
        when(userRepository.findById(1L)).thenReturn(Optional.empty());

        assertThrows(RuntimeException.class, () -> certificateService.generateCertificateIfNotExists(1L, 10L));

        verify(certificateRepository, never()).save(any());
    }

    @Test
    void generateCertificateIfNotExistsShouldThrowWhenCourseNotFound() {
        User learner = User.builder().id(1L).fullName("Learner One").email("learner@example.com").build();
        when(certificateRepository.existsByUserIdAndCourseId(1L, 10L)).thenReturn(false);
        when(userRepository.findById(1L)).thenReturn(Optional.of(learner));
        when(courseRepository.findById(10L)).thenReturn(Optional.empty());

        assertThrows(RuntimeException.class, () -> certificateService.generateCertificateIfNotExists(1L, 10L));

        verify(certificateRepository, never()).save(any());
    }

    // =================================================================
    // getCertificate
    // =================================================================

    @Test
    void getCertificateShouldThrowWhenNotFound() {
        when(certificateRepository.findByUserIdAndCourseId(1L, 10L)).thenReturn(Optional.empty());

        assertThrows(RuntimeException.class, () -> certificateService.getCertificate(1L, 10L));
    }

    @Test
    void getCertificateShouldFallbackTrainerNameWhenCourseCreatorIsNull() {
        User learner = User.builder().id(1L).fullName("Learner One").email("learner@example.com").build();
        Course course = Course.builder().id(10L).title("English Mastery").creator(null).build();
        Certificate certificate = Certificate.builder()
                .user(learner)
                .course(course)
                .credentialId("HG-ABC12345")
                .issuedAt(LocalDateTime.now())
                .build();
        when(certificateRepository.findByUserIdAndCourseId(1L, 10L)).thenReturn(Optional.of(certificate));

        CertificateDTO dto = certificateService.getCertificate(1L, 10L);

        assertEquals("HanGo Trainer", dto.getTrainerName());
    }

    @Test
    void getCertificateShouldMapCertificateToDto() {
        User learner = User.builder().id(1L).fullName("Learner One").email("learner@example.com").build();
        User trainer = User.builder().id(2L).fullName("Trainer One").email("trainer@example.com").build();
        Course course = Course.builder().id(10L).title("English Mastery").creator(trainer).build();
        LocalDateTime issuedAt = LocalDateTime.of(2026, 8, 11, 10, 0);
        Certificate certificate = Certificate.builder()
                .user(learner)
                .course(course)
                .credentialId("HG-ABC12345")
                .issuedAt(issuedAt)
                .build();

        when(certificateRepository.findByUserIdAndCourseId(1L, 10L)).thenReturn(Optional.of(certificate));

        CertificateDTO dto = certificateService.getCertificate(1L, 10L);

        assertEquals("HG-ABC12345", dto.getCredentialId());
        assertEquals("Learner One", dto.getLearnerName());
        assertEquals("English Mastery", dto.getCourseTitle());
        assertEquals("Trainer One", dto.getTrainerName());
        assertEquals(issuedAt, dto.getIssuedAt());
    }

    // =================================================================
    // getCertificateByCredentialId
    // =================================================================

    @Test
    void getCertificateByCredentialIdShouldMapCertificateToDto() {
        User learner = User.builder().id(1L).fullName("Learner One").email("learner@example.com").build();
        User trainer = User.builder().id(2L).fullName("Trainer One").email("trainer@example.com").build();
        Course course = Course.builder().id(10L).title("English Mastery").creator(trainer).build();
        LocalDateTime issuedAt = LocalDateTime.of(2026, 8, 11, 10, 0);
        Certificate certificate = Certificate.builder()
                .user(learner)
                .course(course)
                .credentialId("HG-ABC12345")
                .issuedAt(issuedAt)
                .build();

        when(certificateRepository.findByCredentialId("HG-ABC12345")).thenReturn(Optional.of(certificate));

        CertificateDTO dto = certificateService.getCertificateByCredentialId("HG-ABC12345");

        assertEquals("HG-ABC12345", dto.getCredentialId());
        assertEquals("Learner One", dto.getLearnerName());
        assertEquals("English Mastery", dto.getCourseTitle());
        assertEquals("Trainer One", dto.getTrainerName());
        assertEquals(issuedAt, dto.getIssuedAt());
    }

    @Test
    void getCertificateByCredentialIdShouldThrowWhenNotFound() {
        when(certificateRepository.findByCredentialId("BAD-ID")).thenReturn(Optional.empty());

        assertThrows(RuntimeException.class, () -> certificateService.getCertificateByCredentialId("BAD-ID"));
    }
}
