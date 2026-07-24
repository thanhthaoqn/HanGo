package com.hango.hango_backend.service;

import com.hango.hango_backend.dto.CourseManagerDashboardSummaryDTO;
import com.hango.hango_backend.repository.CourseRepository;
import com.hango.hango_backend.repository.ExamRepository;
import com.hango.hango_backend.repository.UserRepository;
import com.hango.hango_backend.service.impl.CourseManagerDashboardServiceImpl;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.api.extension.ExtendWith;
import org.mockito.InjectMocks;
import org.mockito.Mock;
import org.mockito.junit.jupiter.MockitoExtension;

import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.mockito.Mockito.when;

@ExtendWith(MockitoExtension.class)
class CourseManagerDashboardServiceTest {

    @Mock
    private UserRepository userRepository;
    @Mock
    private CourseRepository courseRepository;
    @Mock
    private ExamRepository examRepository;

    @InjectMocks
    private CourseManagerDashboardServiceImpl service;

    // =================================================================
    // getDashboardSummary
    // =================================================================

    @Test
    void getDashboardSummaryShouldMapRegisteredUsersAndCourseStatusCounts() {
        when(userRepository.countByRoleName("LEARNER")).thenReturn(150L);
        when(courseRepository.countByStatus("PUBLISHED")).thenReturn(20L);
        when(courseRepository.countByStatus("DRAFT")).thenReturn(5L);
        when(courseRepository.countByStatus("ARCHIVED")).thenReturn(3L);
        when(examRepository.count()).thenReturn(40L);

        CourseManagerDashboardSummaryDTO result = service.getDashboardSummary();

        assertEquals(150L, result.getRegisteredUsersCount());
        assertEquals(20L, result.getActiveCoursesCount());
        assertEquals(8L, result.getInactiveCoursesCount());
        assertEquals(40L, result.getExamsCount());
    }
}
