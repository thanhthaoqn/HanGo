package com.hango.hango_backend.config;

import com.hango.hango_backend.entity.Flashcard;
import com.hango.hango_backend.entity.FlashcardCollection;
import com.hango.hango_backend.repository.FlashcardCollectionRepository;
import lombok.RequiredArgsConstructor;
import org.springframework.boot.CommandLineRunner;
import org.springframework.stereotype.Component;

import java.util.ArrayList;
import java.util.List;

@Component
@RequiredArgsConstructor
public class FlashcardDataSeeder implements CommandLineRunner {

    private final FlashcardCollectionRepository collectionRepository;

    @Override
    public void run(String... args) throws Exception {
        if (collectionRepository.count() == 0) {
            seedDefaultFlashcards();
        }
    }

    private void seedDefaultFlashcards() {
        List<FlashcardCollection> collections = new ArrayList<>();

        // 1. Speed Grammar
        FlashcardCollection col1 = new FlashcardCollection();
        col1.setTitle("Speed Grammar to 8+- Vocab - 2/5/2026");
        col1.setDescription("Bí kíp cấp tốc nâng điểm Grammar và Từ vựng lên 8+ cho kỳ thi THPT Quốc Gia.");
        col1.setCreator("CourseDesignerName");
        col1.setSentenceCount(10);
        col1.setDurationMinutes(50);
        col1.setRating(5.0);
        col1.setLearnerCount("152k Learner");
        col1.setFlashcards(createDefaultCards(col1));
        collections.add(col1);

        // 2. Hà Tĩnh
        FlashcardCollection col2 = new FlashcardCollection();
        col2.setTitle("Đề thi thử tốt nghiệp THPT năm 2025 - Sở GD&ĐT Hà Tĩnh");
        col2.setDescription("Tổng hợp các cấu trúc và từ vựng quan trọng xuất hiện trong đề thi thử của Sở Hà Tĩnh.");
        col2.setCreator("CourseDesignerName");
        col2.setSentenceCount(10);
        col2.setDurationMinutes(50);
        col2.setRating(5.0);
        col2.setLearnerCount("152k Learner");
        col2.setFlashcards(createDefaultCards(col2));
        collections.add(col2);

        // 3. Hải Phòng
        FlashcardCollection col3 = new FlashcardCollection();
        col3.setTitle("Đề Thi Thử Tốt Nghiệp THPT - Chuyên Trần Phú, Hải Phòng");
        col3.setDescription("Các từ vựng nâng cao và ngữ pháp hay gặp trong đề thi Chuyên Trần Phú Hải Phòng.");
        col3.setCreator("CourseDesignerName");
        col3.setSentenceCount(10);
        col3.setDurationMinutes(50);
        col3.setRating(5.0);
        col3.setLearnerCount("152k Learner");
        col3.setFlashcards(createDefaultCards(col3));
        collections.add(col3);

        // 4. Bộ GD&ĐT
        FlashcardCollection col4 = new FlashcardCollection();
        col4.setTitle("Đề Thi Thử Tốt Nghiệp THPT - Bộ Giáo Dục Và Đào Tạo");
        col4.setDescription("Cực kỳ quan trọng! Bộ flashcard bám sát đề minh họa chính thức của Bộ GD&ĐT.");
        col4.setCreator("CourseDesignerName");
        col4.setSentenceCount(10);
        col4.setDurationMinutes(50);
        col4.setRating(5.0);
        col4.setLearnerCount("152k Learner");
        col4.setFlashcards(createDefaultCards(col4));
        collections.add(col4);

        // 5. Đồng Nai
        FlashcardCollection col5 = new FlashcardCollection();
        col5.setTitle("Đề Thi Thử Tốt Nghiệp THPT - Sở GD&ĐT Đồng Nai");
        col5.setDescription("Tài liệu ôn tập bám sát cấu trúc đề thi của Sở GD&ĐT Đồng Nai.");
        col5.setCreator("CourseDesignerName");
        col5.setSentenceCount(10);
        col5.setDurationMinutes(50);
        col5.setRating(5.0);
        col5.setLearnerCount("152k Learner");
        col5.setFlashcards(createDefaultCards(col5));
        collections.add(col5);

        collectionRepository.saveAll(collections);
    }

    private List<Flashcard> createDefaultCards(FlashcardCollection collection) {
        List<Flashcard> cards = new ArrayList<>();

        cards.add(createCard(collection, "Although / Even though / Though", "+ Clause (S + V) -> Expresses contrast (Mặc dù)"));
        cards.add(createCard(collection, "In spite of / Despite", "+ Noun / V-ing -> Expresses contrast (Mặc dù)"));
        cards.add(createCard(collection, "Because / As / Since", "+ Clause (S + V) -> Expresses reason (Bởi vì)"));
        cards.add(createCard(collection, "Because of / Due to / Owing to", "+ Noun / V-ing -> Expresses reason (Bởi vì)"));
        cards.add(createCard(collection, "So that / In order that", "+ Clause (S + can/could/will/would + V) -> Expresses purpose (Để mà)"));
        cards.add(createCard(collection, "To / In order to / So as to", "+ V-inf -> Expresses purpose (Để mà)"));
        cards.add(createCard(collection, "Conditional Type 1", "If + S + V(s/es), S + will/can/may + V-inf\nUsed for real situations in the present/future."));
        cards.add(createCard(collection, "Conditional Type 2", "If + S + V2/V-ed (to be = were), S + would/could + V-inf\nUsed for unreal situations in the present."));
        cards.add(createCard(collection, "Conditional Type 3", "If + S + had + V3/V-ed, S + would/could + have + V3/V-ed\nUsed for unreal situations in the past."));
        cards.add(createCard(collection, "Used to + V-inf", "Refers to a past habit or state that no longer exists (Đã từng làm gì)"));

        return cards;
    }

    private Flashcard createCard(FlashcardCollection collection, String front, String back) {
        Flashcard card = new Flashcard();
        card.setFrontText(front);
        card.setBackText(back);
        card.setCollection(collection);
        return card;
    }
}
