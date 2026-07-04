package com.hango.hango_backend.repository;

import com.hango.hango_backend.entity.UserFlashcardProgress;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.stereotype.Repository;
import java.util.List;
import java.util.Optional;

@Repository
public interface UserFlashcardProgressRepository extends JpaRepository<UserFlashcardProgress, Long> {
    Optional<UserFlashcardProgress> findByUserIdAndCollectionId(Long userId, Long collectionId);
    List<UserFlashcardProgress> findByUserId(Long userId);
    List<UserFlashcardProgress> findByUserIdAndIsRecentTrue(Long userId);
    List<UserFlashcardProgress> findByUserIdAndIsLearnedTrue(Long userId);
}
