package com.hango.hango_backend.repository;

import com.hango.hango_backend.entity.UserCardProgress;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.stereotype.Repository;
import java.util.List;
import java.util.Optional;

@Repository
public interface UserCardProgressRepository extends JpaRepository<UserCardProgress, Long> {
    Optional<UserCardProgress> findByUserIdAndCardId(Long userId, Long cardId);
    List<UserCardProgress> findByUserId(Long userId);
    List<UserCardProgress> findByUserIdAndCardCollectionId(Long userId, Long collectionId);
}
