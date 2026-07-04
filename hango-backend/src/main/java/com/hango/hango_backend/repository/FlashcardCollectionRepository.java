package com.hango.hango_backend.repository;

import com.hango.hango_backend.entity.FlashcardCollection;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.stereotype.Repository;
import java.util.List;

@Repository
public interface FlashcardCollectionRepository extends JpaRepository<FlashcardCollection, Long> {
    List<FlashcardCollection> findByCreatedById(Long userId);
    List<FlashcardCollection> findByCreatorNot(String creator);
}
