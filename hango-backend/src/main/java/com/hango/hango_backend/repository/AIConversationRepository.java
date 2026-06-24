package com.hango.hango_backend.repository;

import com.hango.hango_backend.entity.AIConversation;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.Query;
import org.springframework.data.repository.query.Param;
import java.util.Optional;

public interface AIConversationRepository extends JpaRepository<AIConversation, Long> {
    
    // FETCH sạch danh sách messages đi kèm ngay từ câu SQL đầu tiên
    @Query("SELECT DISTINCT c FROM AIConversation c " +
           "LEFT JOIN FETCH c.messages " + 
           "WHERE c.id = :id AND c.learner.id = :learnerId")
    Optional<AIConversation> findByIdAndLearnerIdWithMessages(@Param("id") Long id, @Param("learnerId") Long learnerId);

    // Thêm hàm này nếu bạn chưa khai báo hàm tìm kiếm cũ
    Optional<AIConversation> findByIdAndLearnerId(Long id, Long learnerId);
    
    java.util.List<AIConversation> findByLearnerIdOrderByStartedAtDesc(Long learnerId);
}