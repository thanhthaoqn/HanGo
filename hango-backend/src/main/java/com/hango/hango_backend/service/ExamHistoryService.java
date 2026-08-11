package com.hango.hango_backend.service;

import com.hango.hango_backend.dto.ExamHistoryLogDTO;
import com.hango.hango_backend.entity.Exam;
import com.hango.hango_backend.entity.ExamHistoryLog;
import com.hango.hango_backend.entity.User;
import com.hango.hango_backend.repository.ExamHistoryLogRepository;
import com.hango.hango_backend.repository.ExamRepository;
import com.hango.hango_backend.repository.UserRepository;
import com.hango.hango_backend.security.SecurityUtil;
import lombok.RequiredArgsConstructor;
import org.springframework.security.access.AccessDeniedException;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.util.List;
import java.util.stream.Collectors;

/**
 * Append-only activity log for a single exam (created / edited / submitted / rejected /
 * published / hidden / unhidden). Unlike course versioning, an exam never gets a new row
 * or id for an edit - this just records what happened to the one exam over time.
 */
@Service
@RequiredArgsConstructor
public class ExamHistoryService {

    public static final String ACTION_CREATED = "CREATED";
    public static final String ACTION_EDITED = "EDITED";
    public static final String ACTION_SUBMITTED = "SUBMITTED";
    public static final String ACTION_REJECTED = "REJECTED";
    public static final String ACTION_PUBLISHED = "PUBLISHED";
    public static final String ACTION_HIDDEN = "HIDDEN";
    public static final String ACTION_UNHIDDEN = "UNHIDDEN";

    private final ExamHistoryLogRepository examHistoryLogRepository;
    private final ExamRepository examRepository;
    private final UserRepository userRepository;

    @Transactional
    public void log(Exam exam, String action, String oldStatus, String newStatus, String reason, String diff) {
        ExamHistoryLog log = new ExamHistoryLog();
        log.setExam(exam);
        log.setAction(action);
        log.setOldStatus(oldStatus);
        log.setNewStatus(newStatus);
        log.setReason(reason);
        log.setDiff(diff);

        Long actorId = SecurityUtil.getCurrentUserId();
        if (actorId != null) {
            userRepository.findById(actorId).ifPresent(log::setActor);
        }

        examHistoryLogRepository.save(log);
    }

    @Transactional(readOnly = true)
    public List<ExamHistoryLogDTO> getHistory(Long examId, String requesterEmail) {
        Exam exam = examRepository.findById(examId)
                .orElseThrow(() -> new RuntimeException("Exam not found with id: " + examId));

        User requester = userRepository.findByEmail(requesterEmail)
                .orElseThrow(() -> new RuntimeException("User not found with email: " + requesterEmail));

        boolean isManager = requester.getRoles().stream()
                .anyMatch(r -> r.getRoleName().equalsIgnoreCase("COURSE_MANAGER")
                        || r.getRoleName().equalsIgnoreCase("ADMINISTRATOR")
                        || r.getRoleName().equalsIgnoreCase("ADMIN"));
        boolean isOwner = exam.getCreatedBy() != null && exam.getCreatedBy().getId().equals(requester.getId());

        if (!isManager && !isOwner) {
            throw new AccessDeniedException("Not authorized to view this exam's history");
        }

        return examHistoryLogRepository.findByExamIdOrderByCreatedAtAsc(examId).stream()
                .map(log -> ExamHistoryLogDTO.builder()
                        .id(log.getId())
                        .action(log.getAction())
                        .oldStatus(log.getOldStatus())
                        .newStatus(log.getNewStatus())
                        .actorId(log.getActor() != null ? log.getActor().getId() : null)
                        .actorName(log.getActor() != null ? log.getActor().getFullName() : "System")
                        .reason(log.getReason())
                        .diff(log.getDiff())
                        .createdAt(log.getCreatedAt())
                        .build())
                .collect(Collectors.toList());
    }
}
