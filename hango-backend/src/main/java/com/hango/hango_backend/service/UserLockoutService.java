package com.hango.hango_backend.service;

import java.time.LocalDateTime;

import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Propagation;
import org.springframework.transaction.annotation.Transactional;

import com.hango.hango_backend.entity.User;
import com.hango.hango_backend.repository.UserRepository;

@Service
public class UserLockoutService {

    private static final int MAX_FAILED_LOGIN_ATTEMPTS = 5;
    private static final long LOCKOUT_DURATION_MINUTES = 15;

    @Autowired
    private UserRepository userRepository;

    /**
     * Records a failed login attempt in an independent transaction so that it commits
     * to DB even if the calling method throws a RuntimeException (e.g. ApiException).
     *
     * @return true if the account is now locked after this attempt, false otherwise.
     */
    @Transactional(propagation = Propagation.REQUIRES_NEW)
    public boolean recordFailedAttempt(Long userId) {
        if (userId == null) {
            return false;
        }
        User user = userRepository.findById(userId).orElse(null);
        if (user == null) {
            return false;
        }

        int attempts = (user.getFailedLoginAttempts() == null ? 0 : user.getFailedLoginAttempts()) + 1;
        user.setFailedLoginAttempts(attempts);

        boolean isLocked = false;
        if (attempts >= MAX_FAILED_LOGIN_ATTEMPTS) {
            user.setLockedUntil(LocalDateTime.now().plusMinutes(LOCKOUT_DURATION_MINUTES));
            isLocked = true;
        }

        userRepository.save(user);
        return isLocked;
    }

    /**
     * Resets failed login attempts and lockout state in an independent transaction.
     */
    @Transactional(propagation = Propagation.REQUIRES_NEW)
    public void resetLockout(Long userId) {
        if (userId == null) {
            return;
        }
        User user = userRepository.findById(userId).orElse(null);
        if (user != null && ((user.getFailedLoginAttempts() != null && user.getFailedLoginAttempts() > 0) || user.getLockedUntil() != null)) {
            user.setFailedLoginAttempts(0);
            user.setLockedUntil(null);
            userRepository.save(user);
        }
    }
}
