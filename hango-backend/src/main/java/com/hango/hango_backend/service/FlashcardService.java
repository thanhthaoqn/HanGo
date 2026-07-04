package com.hango.hango_backend.service;

import com.hango.hango_backend.dto.*;
import com.hango.hango_backend.entity.*;
import com.hango.hango_backend.repository.*;
import lombok.RequiredArgsConstructor;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.time.LocalDateTime;
import java.time.format.DateTimeFormatter;
import java.util.ArrayList;
import java.util.List;
import java.util.Optional;
import java.util.stream.Collectors;

@Service
@RequiredArgsConstructor
public class FlashcardService {

    private final FlashcardCollectionRepository collectionRepository;
    private final FlashcardRepository cardRepository;
    private final UserFlashcardProgressRepository userProgressRepository;
    private final UserCardProgressRepository cardProgressRepository;
    private final UserRepository userRepository;

    @Transactional(readOnly = true)
    public List<FlashcardCollectionResponseDTO> getCollections(Long userId, String status) {
        List<FlashcardCollection> allCollections = collectionRepository.findAll();
        List<FlashcardCollectionResponseDTO> dtos = new ArrayList<>();

        for (FlashcardCollection col : allCollections) {
            Optional<UserFlashcardProgress> progOpt = userProgressRepository.findByUserIdAndCollectionId(userId, col.getId());
            boolean isRecent = progOpt.map(UserFlashcardProgress::getIsRecent).orElse(false);
            boolean isLearned = progOpt.map(UserFlashcardProgress::getIsLearned).orElse(false);
            LocalDateTime lastStudiedAt = progOpt.map(UserFlashcardProgress::getLastStudiedAt).orElse(null);

            // Fetch card learned statuses
            List<FlashcardResponseDTO> cardDTOs = new ArrayList<>();
            for (Flashcard card : col.getFlashcards()) {
                Optional<UserCardProgress> cardProgOpt = cardProgressRepository.findByUserIdAndCardId(userId, card.getId());
                boolean cardLearned = cardProgOpt.map(UserCardProgress::getIsLearned).orElse(false);

                FlashcardResponseDTO cardDTO = new FlashcardResponseDTO();
                cardDTO.setId(card.getId().toString());
                cardDTO.setFrontText(card.getFrontText());
                cardDTO.setBackText(card.getBackText());
                cardDTO.setIsLearned(cardLearned);
                cardDTOs.add(cardDTO);
            }

            FlashcardCollectionResponseDTO colDTO = new FlashcardCollectionResponseDTO();
            colDTO.setId(col.getId().toString());
            colDTO.setTitle(col.getTitle());
            colDTO.setDescription(col.getDescription());
            colDTO.setCreator(col.getCreator());
            colDTO.setSentenceCount(col.getSentenceCount());
            colDTO.setDurationMinutes(col.getDurationMinutes());
            colDTO.setRating(col.getRating());
            colDTO.setLearnerCount(col.getLearnerCount());
            colDTO.setImageUrl(col.getImageUrl());
            colDTO.setFlashcards(cardDTOs);
            colDTO.setIsRecent(isRecent);
            colDTO.setIsLearned(isLearned);
            if (lastStudiedAt != null) {
                colDTO.setLastStudiedAt(DateTimeFormatter.ISO_LOCAL_DATE_TIME.format(lastStudiedAt));
            }

            dtos.add(colDTO);
        }

        // Apply filters based on status
        if ("Recents".equalsIgnoreCase(status)) {
            return dtos.stream()
                    .filter(c -> c.getIsRecent() || c.getLastStudiedAt() != null)
                    .sorted((a, b) -> {
                        if (a.getLastStudiedAt() == null && b.getLastStudiedAt() == null) return 0;
                        if (a.getLastStudiedAt() == null) return 1;
                        if (b.getLastStudiedAt() == null) return -1;
                        return b.getLastStudiedAt().compareTo(a.getLastStudiedAt());
                    })
                    .collect(Collectors.toList());
        } else if ("Learned".equalsIgnoreCase(status)) {
            return dtos.stream()
                    .filter(FlashcardCollectionResponseDTO::getIsLearned)
                    .collect(Collectors.toList());
        } else if ("Created".equalsIgnoreCase(status)) {
            // Filter collections created by the current user
            return dtos.stream()
                    .filter(c -> {
                        Optional<FlashcardCollection> original = collectionRepository.findById(Long.parseLong(c.getId()));
                        return original.isPresent() && original.get().getCreatedBy() != null && original.get().getCreatedBy().getId().equals(userId);
                    })
                    .collect(Collectors.toList());
        }

        return dtos;
    }

    @Transactional
    public FlashcardCollectionResponseDTO createCollection(Long userId, FlashcardCollectionCreateDTO createDTO) {
        User user = userRepository.findById(userId)
                .orElseThrow(() -> new RuntimeException("User not found: " + userId));

        FlashcardCollection col = new FlashcardCollection();
        col.setTitle(createDTO.getTitle());
        col.setDescription(createDTO.getDescription());
        col.setCreator(createDTO.getCreator() != null ? createDTO.getCreator() : user.getFullName());
        col.setSentenceCount(createDTO.getFlashcards() != null ? createDTO.getFlashcards().size() : 0);
        col.setDurationMinutes(createDTO.getDurationMinutes());
        col.setRating(createDTO.getRating());
        col.setLearnerCount(createDTO.getLearnerCount());
        col.setImageUrl(createDTO.getImageUrl());
        col.setCreatedBy(user);

        List<Flashcard> cards = new ArrayList<>();
        if (createDTO.getFlashcards() != null) {
            for (FlashcardCreateDTO cDTO : createDTO.getFlashcards()) {
                Flashcard card = new Flashcard();
                card.setFrontText(cDTO.getFrontText());
                card.setBackText(cDTO.getBackText());
                card.setCollection(col);
                cards.add(card);
            }
        }
        col.setFlashcards(cards);

        FlashcardCollection savedCol = collectionRepository.save(col);

        // Track creation as recent progress
        UserFlashcardProgress progress = new UserFlashcardProgress();
        progress.setUser(user);
        progress.setCollection(savedCol);
        progress.setIsRecent(true);
        progress.setIsLearned(false);
        progress.setLastStudiedAt(LocalDateTime.now());
        userProgressRepository.save(progress);

        return getCollections(userId, "All").stream()
                .filter(c -> c.getId().equals(savedCol.getId().toString()))
                .findFirst()
                .orElse(null);
    }

    @Transactional
    public FlashcardCollectionResponseDTO updateCollection(Long userId, Long collectionId, FlashcardCollectionCreateDTO updateDTO) {
        FlashcardCollection col = collectionRepository.findById(collectionId)
                .orElseThrow(() -> new RuntimeException("Collection not found: " + collectionId));

        col.setTitle(updateDTO.getTitle());
        col.setDescription(updateDTO.getDescription());
        col.setDurationMinutes(updateDTO.getDurationMinutes());
        if (updateDTO.getImageUrl() != null) {
            col.setImageUrl(updateDTO.getImageUrl());
        }

        // Sync Flashcards: we can replace or perform smart sync. For simplicity, clean and reload.
        col.getFlashcards().clear();
        if (updateDTO.getFlashcards() != null) {
            for (FlashcardCreateDTO cDTO : updateDTO.getFlashcards()) {
                Flashcard card = new Flashcard();
                card.setFrontText(cDTO.getFrontText());
                card.setBackText(cDTO.getBackText());
                card.setCollection(col);
                col.getFlashcards().add(card);
            }
        }
        col.setSentenceCount(col.getFlashcards().size());

        FlashcardCollection savedCol = collectionRepository.save(col);
        
        // Return updated collection
        return getCollections(userId, "All").stream()
                .filter(c -> c.getId().equals(savedCol.getId().toString()))
                .findFirst()
                .orElse(null);
    }

    @Transactional
    public void deleteCollection(Long collectionId) {
        collectionRepository.deleteById(collectionId);
    }

    @Transactional
    public void markCardAsLearned(Long userId, Long collectionId, Long cardId, boolean isLearned) {
        User user = userRepository.findById(userId)
                .orElseThrow(() -> new RuntimeException("User not found: " + userId));
        Flashcard card = cardRepository.findById(cardId)
                .orElseThrow(() -> new RuntimeException("Flashcard not found: " + cardId));
        FlashcardCollection collection = collectionRepository.findById(collectionId)
                .orElseThrow(() -> new RuntimeException("Collection not found: " + collectionId));

        UserCardProgress cardProg = cardProgressRepository.findByUserIdAndCardId(userId, cardId)
                .orElseGet(() -> {
                    UserCardProgress cp = new UserCardProgress();
                    cp.setUser(user);
                    cp.setCard(card);
                    return cp;
                });
        cardProg.setIsLearned(isLearned);
        cardProgressRepository.save(cardProg);

        // Check if all cards in the collection are learned for the user
        List<Flashcard> collectionCards = collection.getFlashcards();
        boolean allLearned = true;
        for (Flashcard c : collectionCards) {
            boolean cardIsLearned = false;
            if (c.getId().equals(cardId)) {
                cardIsLearned = isLearned;
            } else {
                Optional<UserCardProgress> cpOpt = cardProgressRepository.findByUserIdAndCardId(userId, c.getId());
                cardIsLearned = cpOpt.map(UserCardProgress::getIsLearned).orElse(false);
            }
            if (!cardIsLearned) {
                allLearned = false;
                break;
            }
        }

        // Save collection progress
        UserFlashcardProgress progress = userProgressRepository.findByUserIdAndCollectionId(userId, collectionId)
                .orElseGet(() -> {
                    UserFlashcardProgress uf = new UserFlashcardProgress();
                    uf.setUser(user);
                    uf.setCollection(collection);
                    return uf;
                });
        progress.setIsLearned(allLearned);
        progress.setIsRecent(true);
        progress.setLastStudiedAt(LocalDateTime.now());
        userProgressRepository.save(progress);
    }

    @Transactional
    public void touchCollection(Long userId, Long collectionId) {
        User user = userRepository.findById(userId)
                .orElseThrow(() -> new RuntimeException("User not found: " + userId));
        FlashcardCollection collection = collectionRepository.findById(collectionId)
                .orElseThrow(() -> new RuntimeException("Collection not found: " + collectionId));

        UserFlashcardProgress progress = userProgressRepository.findByUserIdAndCollectionId(userId, collectionId)
                .orElseGet(() -> {
                    UserFlashcardProgress uf = new UserFlashcardProgress();
                    uf.setUser(user);
                    uf.setCollection(collection);
                    return uf;
                });
        progress.setIsRecent(true);
        progress.setLastStudiedAt(LocalDateTime.now());
        userProgressRepository.save(progress);
    }
}
