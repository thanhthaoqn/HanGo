package com.hango.hango_backend.repository;

import com.hango.hango_backend.entity.PathwayConversation;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.Query;
import org.springframework.data.repository.query.Param;
import org.springframework.stereotype.Repository;

import java.util.List;
import java.util.Optional;

@Repository
public interface PathwayConversationRepository extends JpaRepository<PathwayConversation, Long> {

    /**
     * Find the most recent conversation for a learner on a specific pathway.
     */
    Optional<PathwayConversation> findFirstByLearnerIdAndPathwayIdOrderByStartedAtDesc(Long learnerId, Long pathwayId);

    /**
     * Find a conversation by ID ensuring it belongs to the given learner.
     */
    @Query("SELECT c FROM PathwayConversation c LEFT JOIN FETCH c.messages WHERE c.id = :id AND c.learner.id = :learnerId")
    Optional<PathwayConversation> findByIdAndLearnerIdWithMessages(@Param("id") Long id, @Param("learnerId") Long learnerId);

    /**
     * Get all conversations for a learner on a specific pathway (for history).
     */
    List<PathwayConversation> findByLearnerIdAndPathwayIdOrderByStartedAtDesc(Long learnerId, Long pathwayId);
}
