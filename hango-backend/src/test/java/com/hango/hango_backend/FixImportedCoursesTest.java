package com.hango.hango_backend;

import com.hango.hango_backend.entity.Lesson;
import com.hango.hango_backend.repository.LessonRepository;
import com.hango.hango_backend.service.YouTubeTranscriptService;
import org.junit.jupiter.api.Test;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.boot.test.context.SpringBootTest;
import org.springframework.test.context.ActiveProfiles;

import java.util.List;

@SpringBootTest(classes = HangoBackendApplication.class)
@ActiveProfiles("local")
public class FixImportedCoursesTest {

    @Autowired
    private LessonRepository lessonRepository;

    @Autowired
    private YouTubeTranscriptService youtubeTranscriptService;

    @Test
    void fixLessonsTypeAndTranscripts() {
        System.out.println("====== STARTING FIX FOR IMPORTED / CREATED LESSONS ======");
        List<Lesson> allLessons = lessonRepository.findAll();
        System.out.println("Total lessons checked: " + allLessons.size());

        int typeFixedCount = 0;
        int transcriptFetchedCount = 0;
        int transcriptFailedCount = 0;

        for (Lesson lesson : allLessons) {
            boolean modified = false;

            // Fix uppercase lesson_type (e.g. 'VIDEO' -> 'video')
            if (lesson.getLessonType() != null && !lesson.getLessonType().equals(lesson.getLessonType().toLowerCase())) {
                System.out.println("Fixing lessonType for Lesson ID " + lesson.getId() + ": '" + lesson.getLessonType() + "' -> '" + lesson.getLessonType().toLowerCase() + "'");
                lesson.setLessonType(lesson.getLessonType().toLowerCase());
                modified = true;
                typeFixedCount++;
            }

            // Fix video lessons without transcripts
            String content = lesson.getContent();
            if (content != null && content.toLowerCase().contains("youtu")) {
                if (!"video".equals(lesson.getLessonType())) {
                    lesson.setLessonType("video");
                    modified = true;
                    typeFixedCount++;
                }

                if (lesson.getVideoTranscript() == null || lesson.getVideoTranscript().trim().isEmpty()) {
                    System.out.println("Fetching transcript for video Lesson ID " + lesson.getId() + " - Title: " + lesson.getTitle() + " - URL: " + content);
                    try {
                        String transcript = youtubeTranscriptService.fetchTranscript(content);
                        if (transcript != null && !transcript.trim().isEmpty()) {
                            lesson.setVideoTranscript(transcript);
                            modified = true;
                            transcriptFetchedCount++;
                            System.out.println(" -> Successfully fetched transcript (" + transcript.length() + " chars)");
                        } else {
                            System.out.println(" -> Transcript returned empty.");
                        }
                    } catch (Exception e) {
                        System.out.println(" -> Failed to fetch transcript: " + e.getMessage());
                        transcriptFailedCount++;
                    }
                }
            }

            if (modified) {
                lessonRepository.save(lesson);
            }
        }

        System.out.println("====== FIX COMPLETED ======");
        System.out.println("Lesson types fixed (to lowercase): " + typeFixedCount);
        System.out.println("Transcripts successfully fetched & saved: " + transcriptFetchedCount);
        System.out.println("Transcripts failed: " + transcriptFailedCount);
        System.out.println("===========================================");
    }
}
