package com.hango.hango_backend.service;

import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Propagation;
import org.springframework.transaction.annotation.Transactional;

import com.hango.hango_backend.entity.AuditLog;
import com.hango.hango_backend.entity.User;
import com.hango.hango_backend.repository.AuditLogRepository;

@Service
public class AuditLogService {

    @Autowired
    private AuditLogRepository auditLogRepository;

    // REQUIRES_NEW: runs in its own transaction so a failure here (e.g. a flush
    // error) can never mark the caller's transaction rollback-only. Previously
    // this ran inside the caller's transaction and, even though the exception
    // was caught locally, Hibernate had already flagged the shared transaction
    // for rollback -- the caller would then hit
    // "UnexpectedRollbackException: Transaction silently rolled back because it
    // has been marked as rollback-only" on commit, even though its own logic
    // never threw anything.
    @Transactional(propagation = Propagation.REQUIRES_NEW)
    public void log(User actor, String actionType, Long targetUserId, String details) {
        try {
            AuditLog log = AuditLog.builder()
                    .actor(actor)
                    .actionType(actionType)
                    .action(actionType)
                    .targetUserId(targetUserId)
                    .entityType(targetUserId != null ? "USER" : null)
                    // 0L sentinel for "no specific entity" (e.g. a login attempt against an
                    // email that matches no account) -- matches AdminController's convention,
                    // never leave this null.
                    .entityId(targetUserId != null ? targetUserId : 0L)
                    .details(details)
                    .build();
            auditLogRepository.save(log);
        } catch (Exception e) {
            // Audit logging must never block the actual business flow.
            System.err.println("[AUDIT] Failed to write audit log: " + e.getMessage());
        }
    }
}
