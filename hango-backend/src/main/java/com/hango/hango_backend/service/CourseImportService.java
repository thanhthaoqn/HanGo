package com.hango.hango_backend.service;

import com.hango.hango_backend.dto.CourseImportResultDTO;
import com.hango.hango_backend.entity.Course;
import com.hango.hango_backend.entity.Lesson;
import com.hango.hango_backend.entity.Question;
import com.hango.hango_backend.entity.QuestionCategory;
import com.hango.hango_backend.entity.QuestionOption;
import com.hango.hango_backend.entity.Section;
import com.hango.hango_backend.entity.SystemParameter;
import com.hango.hango_backend.entity.User;
import com.hango.hango_backend.repository.CourseRepository;
import com.hango.hango_backend.repository.LessonRepository;
import com.hango.hango_backend.repository.QuestionCategoryRepository;
import com.hango.hango_backend.repository.QuestionOptionRepository;
import com.hango.hango_backend.repository.QuestionRepository;
import com.hango.hango_backend.repository.SectionRepository;
import com.hango.hango_backend.repository.SystemParameterRepository;
import com.hango.hango_backend.repository.TrainerProfileRepository;
import com.hango.hango_backend.repository.UserRepository;
import com.hango.hango_backend.repository.QuestionGroupRepository;
import com.hango.hango_backend.entity.TrainerProfile;
import com.hango.hango_backend.exception.CourseImportValidationException;
import lombok.RequiredArgsConstructor;
import org.springframework.jdbc.core.JdbcTemplate;
import java.math.BigDecimal;
import org.springframework.core.io.ClassPathResource;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;
import org.springframework.web.multipart.MultipartFile;
import org.w3c.dom.Document;
import org.w3c.dom.Element;
import org.w3c.dom.NodeList;
import org.xml.sax.InputSource;

import javax.xml.XMLConstants;
import javax.xml.parsers.DocumentBuilderFactory;
import java.io.ByteArrayInputStream;
import java.io.ByteArrayOutputStream;
import java.io.IOException;
import java.nio.file.Files;
import java.nio.file.Path;
import java.nio.file.Paths;
import java.util.ArrayList;
import java.util.Comparator;
import java.util.HashMap;
import java.util.LinkedHashMap;
import java.util.List;
import java.util.Locale;
import java.util.Map;
import java.util.Objects;
import java.util.Set;
import java.util.zip.ZipEntry;
import java.util.zip.ZipInputStream;

@Service
@RequiredArgsConstructor
public class CourseImportService {

    private static final long MAX_IMPORT_BYTES = 10L * 1024L * 1024L;
    private static final long MAX_XML_ENTRY_BYTES = 5L * 1024L * 1024L;
    private static final String TEMPLATE_FILE_NAME = "Hango_Course_Import_Template.xlsx";

    private final UserRepository userRepository;
    private final QuestionGroupRepository questionGroupRepository;
    private final CourseRepository courseRepository;
    private final SectionRepository sectionRepository;
    private final LessonRepository lessonRepository;
    private final QuestionRepository questionRepository;
    private final QuestionOptionRepository questionOptionRepository;
    private final QuestionCategoryRepository questionCategoryRepository;
    private final SystemParameterRepository systemParameterRepository;
    private final TrainerProfileRepository trainerProfileRepository;
    private final JdbcTemplate jdbcTemplate;
    private final YouTubeTranscriptService youtubeTranscriptService;

    @Transactional
    public CourseImportResultDTO importWorkbook(String trainerEmail, MultipartFile file) throws Exception {
        validateWorkbookFile(file);

        User trainer = userRepository.findByEmail(trainerEmail)
                .orElseThrow(() -> new RuntimeException("User not found with email: " + trainerEmail));
        TrainerProfile trainerProfile = trainerProfileRepository.findById(trainer.getId()).orElse(null);

        WorkbookData workbook = readWorkbook(file);

        // §3 / §2: Accept both old and new sheet names (backward compatible)
        List<SheetRow> courseRowsRaw = workbook.rowsBySheet.getOrDefault("COURSE", List.of());
        List<SheetRow> syllabusRows = workbook.rowsBySheet.getOrDefault("SYLLABUS",
                workbook.rowsBySheet.getOrDefault("SYLLABUS", List.of()));
        List<SheetRow> questionRows = workbook.rowsBySheet.getOrDefault("QUESTIONS", List.of());

        List<Map<String, Object>> errors = new ArrayList<>();
        List<String> warnings = new ArrayList<>();

        // ════════════════════════════════════════════════════════════════════════
        // PHASE 1: VALIDATE (read-only, no DB writes)
        // All problems reported in one pass per §23 / §32.
        // ════════════════════════════════════════════════════════════════════════

        // ── §2: Required Sheets ──
        boolean hasCourseSheet = !courseRowsRaw.isEmpty();
        boolean hasSyllabusSheet = !syllabusRows.isEmpty();
        boolean hasQuestionsSheet = !questionRows.isEmpty();
        if (!hasCourseSheet) {
            addError(errors, "COURSE", null, null, "MISSING_SHEET", null,
                    "Required sheet COURSE is missing or empty.");
        }
        if (!hasSyllabusSheet) {
            addError(errors, "SYLLABUS", null, null, "MISSING_SHEET", null,
                    "Required sheet CURRICULUM (or SYLLABUS) is missing or empty.");
        }
        if (!hasQuestionsSheet) {
            addError(errors, "QUESTIONS", null, null, "MISSING_SHEET", null,
                    "Required sheet QUESTIONS is missing or empty.");
        }

        // ── §3-4: Parse & validate COURSE fields ──
        Map<String, String> courseData = new java.util.HashMap<>();
        if (hasCourseSheet) {
            for (SheetRow r : courseRowsRaw) {
                String field = valueOrDefault(r.data(), "Information Field", valueOrDefault(r.data(), "Field", "")).trim();
                String data = valueOrDefault(r.data(), "Fill Data", valueOrDefault(r.data(), "Value", "")).trim();
                if (!field.isEmpty()) {
                    courseData.put(field, data);
                }
            }
        }

        // §4: Course Name — normalize whitespace
        String rawCourseTitle = courseData.get("Title");
        if (rawCourseTitle == null || rawCourseTitle.isBlank()) {
            rawCourseTitle = courseData.get("Course Name");
        }
        String courseTitle = normalizeCourseName(rawCourseTitle);
        if (courseTitle == null || courseTitle.isBlank()) {
            addError(errors, "COURSE", null, "Title", "MISSING_FIELD", null,
                    "Course Name (Title) is required.");
        }

        // §6: Course Code — format validation
        String courseCodeRaw = courseData.get("Course Code");
        if (courseCodeRaw == null || courseCodeRaw.isBlank()) {
            addError(errors, "COURSE", null, "Course Code", "MISSING_FIELD", courseCodeRaw,
                    "Course Code is required.");
        } else {
            String codeUpper = courseCodeRaw.trim().toUpperCase(Locale.ROOT);
            if (!codeUpper.matches("^[A-Z0-9_]+$")) {
                addError(errors, "COURSE", null, "Course Code", "INVALID_FORMAT", courseCodeRaw,
                        "Course Code must contain only uppercase letters, digits, and underscores (e.g. ENGLISH_GRAMMAR_01). Got: '" + courseCodeRaw + "'");
            }
        }

        // §8: Category — required, must exist in DB
        String rawCategory = valueOrDefault(courseData, "Category", valueOrDefault(courseData, "Primary Category", "")).trim();
        SystemParameter category = null;
        if (rawCategory.isBlank()) {
            addError(errors, "COURSE", null, "Category", "MISSING_FIELD", rawCategory,
                    "Primary Category is required.");
        } else {
            try {
                category = resolveParameter("COURSE_CATEGORY", rawCategory, null, warnings);
            } catch (Exception e) {
                addError(errors, "COURSE", null, "Category", "INVALID_VALUE", rawCategory,
                        "Category '" + rawCategory + "' does not exist in the system.");
            }
        }

        // §9: Difficulty — required, must be BASIC/INTERMEDIATE/ADVANCED
        String rawDifficulty = valueOrDefault(courseData, "Difficulty", valueOrDefault(courseData, "Academic Level", "")).trim();
        SystemParameter difficulty = null;
        if (rawDifficulty.isBlank()) {
            addError(errors, "COURSE", null, "Difficulty", "MISSING_FIELD", rawDifficulty,
                    "Difficulty level is required (BASIC, INTERMEDIATE, or ADVANCED).");
        } else {
            try {
                difficulty = resolveParameter("ACADEMIC_LEVEL", rawDifficulty, null, warnings);
            } catch (Exception e) {
                addError(errors, "COURSE", null, "Difficulty", "INVALID_VALUE", rawDifficulty,
                        "Difficulty '" + rawDifficulty + "' is invalid. Must be BASIC, INTERMEDIATE, or ADVANCED.");
            }
        }

        // §5/§34: Composite uniqueness — Trainer + Name + Category + Difficulty
        if (courseTitle != null && !courseTitle.isBlank() && category != null && difficulty != null) {
            if (courseRepository.existsByCompositeIdentity(
                    trainer.getId(), courseTitle, category.getId(), difficulty.getId())) {
                addError(errors, "COURSE", null, "Title", "DUPLICATE_COURSE", courseTitle,
                        "Duplicate Course: You already have a course named '" + courseTitle
                                + "' with category '" + category.getParamValue()
                                + "' and difficulty '" + difficulty.getParamValue()
                                + "'. Change at least one of: Course Name, Category, or Difficulty.");
            }
        }

        // ════════════════════════════════════════════════════════════════════════
        // §10-17: CURRICULUM structure validation
        // ════════════════════════════════════════════════════════════════════════

        // First pass: parse curriculum into structured data for validation
        List<CurriculumSection> parsedSections = new ArrayList<>();
        CurriculumSection currentParsedSection = null;
        Set<String> knownSectionTitlesCheck = new java.util.HashSet<>();
        Set<String> knownLessonTitlesCheck = new java.util.HashSet<>();

        for (SheetRow sr : syllabusRows) {
            Map<String, String> row = sr.data();
            String type = valueOrDefault(row, "Type", "").trim().toLowerCase(Locale.ROOT);
            String title = valueOrDefault(row, "Title", "").trim();
            String contentUrl = valueOrDefault(row, "Content / Media URL", "").trim();
            if (type.isEmpty()) {
                continue;
            }

            if (type.equals("section")) {
                // §11: Section title required
                if (title.isEmpty()) {
                    addError(errors, "SYLLABUS", sr.rowNumber(), "Title", "MISSING_FIELD", title,
                            "Section title is required.");
                    continue;
                }
                // §11: Duplicate section title
                if (!knownSectionTitlesCheck.add(title.toLowerCase(Locale.ROOT))) {
                    addError(errors, "SYLLABUS", sr.rowNumber(), "Title", "DUPLICATE_VALUE", title,
                            "Duplicate Section title: '" + title + "'.");
                }
                // §21: SECTION must have empty content
                if (!contentUrl.isEmpty()) {
                    addError(errors, "SYLLABUS", sr.rowNumber(), "Content / Media URL", "INVALID_VALUE", contentUrl,
                            "SECTION rows must not have Content/Media URL.");
                }
                currentParsedSection = new CurriculumSection(title, sr.rowNumber());
                parsedSections.add(currentParsedSection);
            } else if (isLessonType(type)) {
                // §14: Lesson before first section
                if (currentParsedSection == null) {
                    addError(errors, "SYLLABUS", sr.rowNumber(), "Type", "INVALID_ORDER", type,
                            "Lesson/Quiz found before any Section: '" + title + "'. All lessons must belong to a Section.");
                    continue;
                }
                // Title required for all lesson types
                if (title.isEmpty()) {
                    addError(errors, "SYLLABUS", sr.rowNumber(), "Title", "MISSING_FIELD", title,
                            "Lesson/Quiz title is required.");
                    continue;
                }
                // Duplicate lesson title
                if (!knownLessonTitlesCheck.add(title.toLowerCase(Locale.ROOT))) {
                    addError(errors, "SYLLABUS", sr.rowNumber(), "Title", "DUPLICATE_VALUE", title,
                            "Duplicate Lesson/Quiz title: '" + title + "'.");
                }

                // §13/§21: Media/Content validation per type
                if (type.equals("pdf")) {
                    if (contentUrl.isEmpty()) {
                        addError(errors, "SYLLABUS", sr.rowNumber(), "Content / Media URL", "MISSING_FIELD", contentUrl,
                                "PDF lesson '" + title + "' requires a valid Media URL.");
                    }
                } else if (type.equals("text")) {
                    if (contentUrl.isEmpty()) {
                        addError(errors, "SYLLABUS", sr.rowNumber(), "Content / Media URL", "MISSING_FIELD", contentUrl,
                                "TEXT lesson '" + title + "' requires content.");
                    }
                } else if (type.equals("quiz")) {
                    if (!contentUrl.isEmpty()) {
                        addError(errors, "SYLLABUS", sr.rowNumber(), "Content / Media URL", "INVALID_VALUE", contentUrl,
                                "QUIZ '" + title + "' must not have Content/Media URL.");
                    }
                }
                // Video lessons are intentionally allowed to have empty URLs during import.
                // Trainers will upload/import the actual video files later through the platform UI.

                // Track in section
                if (type.equals("quiz")) {
                    currentParsedSection.quizTitles.add(title);
                    currentParsedSection.quizCount++;
                } else {
                    currentParsedSection.regularLessonCount++;
                }
                currentParsedSection.allItems.add(new CurriculumItem(type, title, sr.rowNumber()));
            } else {
                addError(errors, "SYLLABUS", sr.rowNumber(), "Type", "INVALID_VALUE", type,
                        "Unknown lesson type: '" + type + "'. Supported types: SECTION, VIDEO, TEXT, PDF, QUIZ.");
            }
        }

        // §10: Minimum 2 sections
        if (parsedSections.size() < 2) {
            addError(errors, "SYLLABUS", null, null, "INSUFFICIENT_SECTIONS", String.valueOf(parsedSections.size()),
                    "Course must contain at least 2 Sections. Found: " + parsedSections.size() + ".");
        }

        // §11-12: Per-section structure validation
        for (CurriculumSection section : parsedSections) {
            // §12: Minimum 2 regular lessons per section
            if (section.regularLessonCount < 2) {
                addError(errors, "SYLLABUS", section.rowNumber, null, "INSUFFICIENT_LESSONS",
                        String.valueOf(section.regularLessonCount),
                        "Section '" + section.title + "' must contain at least 2 regular Lessons (VIDEO/TEXT/PDF). Found: "
                                + section.regularLessonCount + ".");
            }
            // §10: Minimum 1 quiz per section
            if (section.quizCount < 1) {
                addError(errors, "SYLLABUS", section.rowNumber, null, "MISSING_QUIZ", "0",
                        "Section '" + section.title + "' must contain at least 1 Quiz. Found: 0.");
            }
            // §11: Section cannot be empty
            if (section.allItems.isEmpty()) {
                addError(errors, "SYLLABUS", section.rowNumber, null, "EMPTY_SECTION", null,
                        "Section '" + section.title + "' is empty — it must contain lessons and at least one quiz.");
            }
        }

        // §16-17: Final Quiz validation (Option B — last quiz of last section)
        String finalQuizTitle = null;
        if (!parsedSections.isEmpty()) {
            CurriculumSection lastSection = parsedSections.get(parsedSections.size() - 1);
            if (!lastSection.allItems.isEmpty()) {
                CurriculumItem lastItem = lastSection.allItems.get(lastSection.allItems.size() - 1);
                if (!"quiz".equals(lastItem.type)) {
                    addError(errors, "SYLLABUS", lastItem.rowNumber, "Type", "FINAL_QUIZ_NOT_LAST", lastItem.type,
                            "The Final Quiz must be the last item of the last Section. Last item is '" + lastItem.title
                                    + "' (type: " + lastItem.type.toUpperCase(Locale.ROOT) + ").");
                } else {
                    finalQuizTitle = lastItem.title;
                }
            }

            // Check exactly 1 final quiz (no other section's last item should be named as a "final quiz")
            // Per Option B, final quiz is auto-detected as last quiz of last section, so we just need
            // to verify the last item is indeed a quiz (handled above).
        } else if (hasSyllabusSheet) {
            addError(errors, "SYLLABUS", null, null, "NO_FINAL_QUIZ", null,
                    "Course must contain exactly one Final Quiz.");
        }

        // ════════════════════════════════════════════════════════════════════════
        // §15/§18-20: QUESTIONS sheet validation
        // ════════════════════════════════════════════════════════════════════════

        // Build a map of quiz title → question count for validation
        Map<String, List<SheetRow>> questionsByQuizTitle = new java.util.LinkedHashMap<>();
        Set<String> allQuizTitlesInCurriculum = new java.util.HashSet<>();
        for (CurriculumSection s : parsedSections) {
            for (String qt : s.quizTitles) {
                allQuizTitlesInCurriculum.add(qt.toLowerCase(Locale.ROOT));
            }
        }

        for (SheetRow qr : questionRows) {
            Map<String, String> row = qr.data();
            String questionText = valueOrDefault(row, "Question Text", "");
            if (questionText.isBlank()) {
                continue;
            }

            String questionTitle = valueOrDefault(row, "Question Title", "").trim();
            if (questionTitle.isBlank()) {
                addError(errors, "QUESTIONS", qr.rowNumber(), "Question Title", "MISSING_FIELD", questionTitle,
                        "Question Title (quiz mapping) is required for every question.");
                continue;
            }

            // §18: Skill Type required
            String skillType = valueOrDefault(row, "Skill Type", "");
            if (skillType.isBlank()) {
                addError(errors, "QUESTIONS", qr.rowNumber(), "Skill Type", "MISSING_FIELD", skillType,
                        "Question row is missing required value: Skill Type.");
            }

            // §18: Validate correct answer matches an option
            String correctAnswer = valueOrDefault(row, "Correct Answer", "").trim();
            String[] optionColumns = {"Option A", "Option B", "Option C", "Option D"};
            String[] optionKeys = {"A", "B", "C", "D"};
            List<String> presentOptions = new ArrayList<>();
            for (int i = 0; i < optionColumns.length; i++) {
                String optionText = valueOrDefault(row, optionColumns[i], "");
                if (!optionText.isBlank()) {
                    presentOptions.add(optionKeys[i]);
                }
            }

            if (presentOptions.size() < 2) {
                addError(errors, "QUESTIONS", qr.rowNumber(), "Options", "INSUFFICIENT_OPTIONS",
                        String.valueOf(presentOptions.size()),
                        "Question must have at least 2 answer options. Found: " + presentOptions.size() + ".");
            }

            if (!correctAnswer.isBlank() && !presentOptions.isEmpty()) {
                boolean matchesOption = false;
                for (String key : presentOptions) {
                    if (correctAnswer.equalsIgnoreCase(key)) {
                        matchesOption = true;
                        break;
                    }
                }
                if (!matchesOption) {
                    // Also check numeric format (1=A, 2=B, etc.)
                    try {
                        int idx = Integer.parseInt(correctAnswer);
                        if (idx >= 1 && idx <= presentOptions.size()) {
                            matchesOption = true;
                        }
                    } catch (NumberFormatException ignored) {
                    }
                }
                if (!matchesOption) {
                    addError(errors, "QUESTIONS", qr.rowNumber(), "Correct Answer", "INVALID_CORRECT_ANSWER",
                            correctAnswer,
                            "Correct Answer '" + correctAnswer + "' does not match any option ("
                                    + String.join(", ", presentOptions) + ").");
                }
            } else if (correctAnswer.isBlank() && !presentOptions.isEmpty()) {
                addError(errors, "QUESTIONS", qr.rowNumber(), "Correct Answer", "MISSING_FIELD", correctAnswer,
                        "Correct Answer is required.");
            }

            questionsByQuizTitle
                    .computeIfAbsent(questionTitle.toLowerCase(Locale.ROOT), k -> new ArrayList<>())
                    .add(qr);
        }

        // §15/§20: Every quiz in CURRICULUM must have matching questions in QUESTIONS
        for (CurriculumSection s : parsedSections) {
            for (String quizTitle : s.quizTitles) {
                String key = quizTitle.toLowerCase(Locale.ROOT);
                List<SheetRow> matchedQuestions = questionsByQuizTitle.get(key);
                if (matchedQuestions == null || matchedQuestions.isEmpty()) {
                    addError(errors, "QUESTIONS", null, "Question Title", "NO_QUESTION_MAPPING", quizTitle,
                            "Quiz '" + quizTitle + "' in CURRICULUM has no matching questions in QUESTIONS sheet.");
                }
            }
        }

        // §19: Final Quiz must have ≥30 questions
        if (finalQuizTitle != null) {
            String finalKey = finalQuizTitle.toLowerCase(Locale.ROOT);
            List<SheetRow> finalQuizQuestions = questionsByQuizTitle.getOrDefault(finalKey, List.of());
            if (finalQuizQuestions.size() < 30) {
                addError(errors, "QUESTIONS", null, "Question Count", "INSUFFICIENT_FINAL_QUIZ_QUESTIONS",
                        String.valueOf(finalQuizQuestions.size()),
                        "Final Quiz '" + finalQuizTitle + "' must contain at least 30 questions. Found: "
                                + finalQuizQuestions.size() + ".");
            }
        }

        // Warn about orphaned questions (in QUESTIONS but not mapped to any quiz in CURRICULUM)
        for (Map.Entry<String, List<SheetRow>> entry : questionsByQuizTitle.entrySet()) {
            if (!allQuizTitlesInCurriculum.contains(entry.getKey())) {
                warnings.add("Questions mapped to '" + entry.getValue().get(0).data().get("Question Title")
                        + "' have no matching Quiz in CURRICULUM — these questions will be skipped.");
            }
        }

        // ── If any errors, reject entire import (§22: Atomic) ──
        if (!errors.isEmpty()) {
            throw new CourseImportValidationException((String) errors.get(0).get("message"), errors);
        }

        // ════════════════════════════════════════════════════════════════════════
        // PHASE 2: INSERT (only reached when validation found zero errors)
        // ════════════════════════════════════════════════════════════════════════

        Set<String> reservedPersistedCourseCodes = new java.util.HashSet<>();
        String persistedCourseCode = resolveUniqueCourseCode(
                courseCodeRaw.trim().toUpperCase(Locale.ROOT), reservedPersistedCourseCodes, warnings);

        String requestedStatus = valueOrDefault(courseData, "Status", "DRAFT").toUpperCase(Locale.ROOT);
        if (!"DRAFT".equals(requestedStatus)) {
            warnings.add("Course " + persistedCourseCode
                    + " was imported as DRAFT because trainer imports still require review before publishing.");
        }

        int lessonCount = 0;
        int durationMinutes = 0;
        for (SheetRow sr : syllabusRows) {
            Map<String, String> row = sr.data();
            String type = valueOrDefault(row, "Type", "").trim().toLowerCase(Locale.ROOT);
            if (type.equals("video") || type.equals("text") || type.equals("quiz") || type.equals("pdf")) {
                lessonCount++;
                durationMinutes += parseInteger(valueOrDefault(row, "Duration (Mins)", ""), 0);
            }
        }

        BigDecimal suggestedPrice = calculateSuggestedPrice(trainerProfile, difficulty, lessonCount, durationMinutes);
        Long importedPriceRaw = parseLong(courseData.get("Price"), null);
        BigDecimal importedPrice = importedPriceRaw != null ? BigDecimal.valueOf(importedPriceRaw) : suggestedPrice;

        Course course = Course.builder()
                .title(courseTitle)
                .description(valueOrDefault(courseData, "Description", ""))
                .creator(trainer)
                .category(category)
                .difficulty(difficulty)
                .thumbnailUrl(valueOrDefault(courseData, "Thumbnail URL", ""))
                .code(persistedCourseCode)
                .price(importedPrice)
                .suggestedPrice(suggestedPrice)
                .priceNote("")
                .version(valueOrDefault(courseData, "Version", ""))
                .objectives(valueOrDefault(courseData, "Objectives", ""))
                .estimatedDuration(durationMinutes)
                .status("DRAFT")
                .build();
        Course savedCourse = courseRepository.save(course);
        List<Long> courseIds = List.of(savedCourse.getId());

        int importedSections = 0;
        int importedLessons = 0;
        int importedQuestions = 0;

        Section currentSection = null;
        Map<String, Lesson> lessonsByTitle = new java.util.HashMap<>();

        for (SheetRow sr : syllabusRows) {
            Map<String, String> row = sr.data();
            String type = valueOrDefault(row, "Type", "").trim().toLowerCase(Locale.ROOT);
            String title = valueOrDefault(row, "Title", "").trim();
            if (type.isEmpty() || title.isEmpty()) {
                continue;
            }

            if (type.equals("section")) {
                Section section = Section.builder()
                        .course(savedCourse)
                        .code(persistedCourseCode + "_S" + (importedSections + 1))
                        .title(title)
                        .description("")
                        .displayOrder(importedSections + 1)
                        .version("")
                        .build();
                currentSection = sectionRepository.save(section);
                importedSections++;
            } else if (isLessonType(type)) {
                String lessonType = normalizeLessonType(type);
                String contentUrl = valueOrDefault(row, "Content / Media URL", "");

                String videoTranscript = null;
                if ("video".equalsIgnoreCase(lessonType) && contentUrl != null
                        && contentUrl.toLowerCase().contains("youtu")) {
                    try {
                        videoTranscript = youtubeTranscriptService.fetchTranscript(contentUrl);
                    } catch (Exception ignored) {
                    }
                }

                Integer estimatedTimeMinutes = parseInteger(valueOrDefault(row, "Duration (Mins)", ""), null);

                Lesson lesson = Lesson.builder()
                        .section(currentSection)
                        .code(currentSection.getCode() + "_L" + (importedLessons + 1))
                        .title(title)
                        .lessonType(lessonType)
                        .skill(category)
                        .difficulty(difficulty)
                        .content(contentUrl)
                        .videoTranscript(videoTranscript)
                        .displayOrder(importedLessons + 1)
                        .description("")
                        .pdfName("pdf".equalsIgnoreCase(lessonType) ? contentUrl : null)
                        .questionImageUrl(null)
                        .mediaDurationSeconds(estimatedTimeMinutes != null ? estimatedTimeMinutes * 60 : null)
                        .mediaSizeBytes(null)
                        .estimatedTimeMinutes(estimatedTimeMinutes)
                        .version("")
                        .build();
                Lesson savedLesson = lessonRepository.save(lesson);
                lessonsByTitle.put(title.toLowerCase(Locale.ROOT), savedLesson);
                importedLessons++;
            }
        }

        Map<String, com.hango.hango_backend.entity.QuestionGroup> questionGroupsByPassage = new java.util.HashMap<>();

        for (SheetRow qr : questionRows) {
            Map<String, String> questionRow = qr.data();
            String questionText = valueOrDefault(questionRow, "Question Text", "");
            if (questionText.isBlank()) {
                continue;
            }

            String questionTitle = valueOrDefault(questionRow, "Question Title", "").trim();
            if (questionTitle.isBlank()) {
                continue; // Already validated in Phase 1
            }

            Lesson targetLesson = lessonsByTitle.get(questionTitle.toLowerCase(Locale.ROOT));
            if (targetLesson == null) {
                // Orphaned question — skip (already warned in Phase 1)
                continue;
            }

            String groupName = valueOrDefault(questionRow, "Group", "").trim();
            String passageText = valueOrDefault(questionRow, "Passage Text", "").trim();
            com.hango.hango_backend.entity.QuestionGroup questionGroup = null;

            if (!groupName.isEmpty() && !passageText.isEmpty()) {
                String groupKey = groupName.toLowerCase(Locale.ROOT);
                questionGroup = questionGroupsByPassage.get(groupKey);
                if (questionGroup == null) {
                    questionGroup = new com.hango.hango_backend.entity.QuestionGroup();
                    questionGroup.setContextText(passageText);
                    questionGroup.setGroupTypeParam(resolveGroupType(questionRow, warnings));
                    questionGroup = questionGroupRepository.save(questionGroup);
                    questionGroupsByPassage.put(groupKey, questionGroup);
                }
            }

            Question question = new Question();
            question.setCreatedBy(trainer);
            question.setCode("Q_" + java.util.UUID.randomUUID().toString().substring(0, 8).toUpperCase(Locale.ROOT));
            question.setCategory(resolveQuestionCategory(valueOrDefault(questionRow, "Category", ""), warnings));
            question.setQuestionText(questionText);
            question.setExplanation(
                    valueOrDefault(questionRow, "Explaination", valueOrDefault(questionRow, "Explanation", "")));
            question.setDifficulty(resolveQuestionDifficulty(questionRow, difficulty, warnings));
            question.setSkillParam(resolveQuestionSkill(questionRow, category, warnings));
            question.setSection(targetLesson.getSection());
            question.setQuestionGroup(questionGroup);
            question.setStatus("APPROVED");
            question.setUsageType(1);

            Question savedQuestion = questionRepository.save(question);
            saveQuestionOptions(savedQuestion, questionRow, warnings);

            int displayOrder = parseInt(valueOrDefault(questionRow, "Order Index", ""), importedQuestions + 1);
            jdbcTemplate.update(
                    "INSERT INTO lesson_quizzes (lesson_id, question_id, display_order) VALUES (?, ?, ?)",
                    targetLesson.getId(),
                    savedQuestion.getId(),
                    displayOrder);
            importedQuestions++;
        }

        return CourseImportResultDTO.builder()
                .message("Course workbook imported successfully")
                .importedCourses(courseIds.size())
                .importedSections(importedSections)
                .importedLessons(importedLessons)
                .importedQuestions(importedQuestions)
                .courseIds(courseIds)
                .warnings(warnings)
                .build();
    }

    public byte[] buildTemplateWorkbook() throws IOException {
        ClassPathResource resource = new ClassPathResource("templates/" + TEMPLATE_FILE_NAME);
        if (resource.exists()) {
            return resource.getInputStream().readAllBytes();
        }
        
        throw new IOException("Course import template not found. Expected " + TEMPLATE_FILE_NAME
                + " under classpath:templates/.");
    }

    private void validateWorkbookFile(MultipartFile file) {
        if (file == null || file.isEmpty()) {
            throw new IllegalArgumentException("Please upload a non-empty .xlsx file");
        }
        if (file.getSize() > MAX_IMPORT_BYTES) {
            throw new IllegalArgumentException("Excel file must be 10MB or smaller");
        }
        String name = Objects.toString(file.getOriginalFilename(), "").toLowerCase(Locale.ROOT);
        if (!name.endsWith(".xlsx")) {
            throw new IllegalArgumentException("Only .xlsx files are supported");
        }
    }

    private WorkbookData readWorkbook(MultipartFile file) throws Exception {
        Map<String, byte[]> entries = readZipEntries(file);
        Document workbookXml = parseXml(requiredEntry(entries, "xl/workbook.xml"));
        Document relsXml = parseXml(requiredEntry(entries, "xl/_rels/workbook.xml.rels"));
        List<String> sharedStrings = readSharedStrings(entries.get("xl/sharedStrings.xml"));
        Map<String, String> relTargets = readRelationshipTargets(relsXml);

        Map<String, List<SheetRow>> rowsBySheet = new HashMap<>();
        NodeList sheetNodes = workbookXml.getElementsByTagNameNS("*", "sheet");
        for (int i = 0; i < sheetNodes.getLength(); i++) {
            Element sheet = (Element) sheetNodes.item(i);
            String sheetName = sheet.getAttribute("name").trim().toUpperCase(Locale.ROOT);
            String relationshipId = sheet.getAttribute("r:id");
            String target = relTargets.get(relationshipId);
            if (target == null) {
                continue;
            }

            String entryName = normalizeWorksheetEntryName(target);
            byte[] worksheetBytes = entries.get(entryName);
            if (worksheetBytes == null) {
                continue;
            }
            rowsBySheet.put(sheetName, readSheetRows(parseXml(worksheetBytes), sharedStrings));
        }

        return new WorkbookData(rowsBySheet);
    }

    private Map<String, byte[]> readZipEntries(MultipartFile file) throws IOException {
        Map<String, byte[]> entries = new HashMap<>();
        try (ZipInputStream zip = new ZipInputStream(file.getInputStream())) {
            ZipEntry entry;
            while ((entry = zip.getNextEntry()) != null) {
                String name = entry.getName();
                if (entry.isDirectory() || name.contains("..")) {
                    continue;
                }
                if (!name.equals("xl/workbook.xml")
                        && !name.equals("xl/_rels/workbook.xml.rels")
                        && !name.equals("xl/sharedStrings.xml")
                        && !name.startsWith("xl/worksheets/")) {
                    continue;
                }
                entries.put(name, readLimited(zip, MAX_XML_ENTRY_BYTES));
            }
        }
        return entries;
    }

    private byte[] readLimited(ZipInputStream zip, long maxBytes) throws IOException {
        ByteArrayOutputStream buffer = new ByteArrayOutputStream();
        byte[] chunk = new byte[8192];
        long total = 0;
        int read;
        while ((read = zip.read(chunk)) != -1) {
            total += read;
            if (total > maxBytes) {
                throw new IllegalArgumentException("Excel XML entry is too large");
            }
            buffer.write(chunk, 0, read);
        }
        return buffer.toByteArray();
    }

    private Document parseXml(byte[] bytes) throws Exception {
        DocumentBuilderFactory factory = DocumentBuilderFactory.newInstance();
        factory.setNamespaceAware(true);
        factory.setXIncludeAware(false);
        factory.setExpandEntityReferences(false);
        setFeature(factory, "http://apache.org/xml/features/disallow-doctype-decl", true);
        setFeature(factory, "http://xml.org/sax/features/external-general-entities", false);
        setFeature(factory, "http://xml.org/sax/features/external-parameter-entities", false);
        setAttribute(factory, XMLConstants.ACCESS_EXTERNAL_DTD, "");
        setAttribute(factory, XMLConstants.ACCESS_EXTERNAL_SCHEMA, "");
        return factory.newDocumentBuilder().parse(new InputSource(new ByteArrayInputStream(bytes)));
    }

    private void setFeature(DocumentBuilderFactory factory, String feature, boolean value) throws Exception {
        try {
            factory.setFeature(feature, value);
        } catch (Exception ignored) {
            throw ignored;
        }
    }

    private void setAttribute(DocumentBuilderFactory factory, String attribute, String value) {
        try {
            factory.setAttribute(attribute, value);
        } catch (IllegalArgumentException ignored) {
            // Some XML parsers do not support these attributes.
        }
    }

    private byte[] requiredEntry(Map<String, byte[]> entries, String name) {
        byte[] bytes = entries.get(name);
        if (bytes == null) {
            throw new IllegalArgumentException("Invalid .xlsx file: missing " + name);
        }
        return bytes;
    }

    private List<String> readSharedStrings(byte[] bytes) throws Exception {
        if (bytes == null) {
            return List.of();
        }
        Document sharedStringsXml = parseXml(bytes);
        List<String> sharedStrings = new ArrayList<>();
        NodeList items = sharedStringsXml.getElementsByTagNameNS("*", "si");
        for (int i = 0; i < items.getLength(); i++) {
            sharedStrings.add(items.item(i).getTextContent().trim());
        }
        return sharedStrings;
    }

    private Map<String, String> readRelationshipTargets(Document relsXml) {
        Map<String, String> targets = new HashMap<>();
        NodeList relationships = relsXml.getElementsByTagNameNS("*", "Relationship");
        for (int i = 0; i < relationships.getLength(); i++) {
            Element relationship = (Element) relationships.item(i);
            targets.put(relationship.getAttribute("Id"), relationship.getAttribute("Target"));
        }
        return targets;
    }

    private String normalizeWorksheetEntryName(String target) {
        String normalized = target.startsWith("/") ? target.substring(1) : target;
        if (normalized.startsWith("xl/")) {
            return normalized;
        }
        if (normalized.startsWith("worksheets/")) {
            return "xl/" + normalized;
        }
        return "xl/worksheets/" + normalized;
    }

    private List<SheetRow> readSheetRows(Document worksheetXml, List<String> sharedStrings) {
        NodeList rowNodes = worksheetXml.getElementsByTagNameNS("*", "row");
        Map<Integer, String> headers = new LinkedHashMap<>();
        int headerRow = 2;
        List<SheetRow> rows = new ArrayList<>();

        for (int i = 0; i < rowNodes.getLength(); i++) {
            Element row = (Element) rowNodes.item(i);
            int rowNumber = parseInt(row.getAttribute("r"), i + 1);
            Map<Integer, String> cells = readCells(row, sharedStrings);
            if (rowNumber == headerRow) {
                for (Map.Entry<Integer, String> entry : cells.entrySet()) {
                    if (!entry.getValue().isBlank()) {
                        headers.put(entry.getKey(), entry.getValue().trim());
                    }
                }
                continue;
            }
            if (rowNumber <= headerRow || headers.isEmpty()) {
                continue;
            }

            Map<String, String> mappedRow = new LinkedHashMap<>();
            boolean hasValue = false;
            for (Map.Entry<Integer, String> header : headers.entrySet()) {
                String value = cells.getOrDefault(header.getKey(), "").trim();
                mappedRow.put(header.getValue(), value);
                if (!value.isBlank()) {
                    hasValue = true;
                }
            }
            if (hasValue) {
                rows.add(new SheetRow(rowNumber, mappedRow));
            }
        }
        return rows;
    }

    private Map<Integer, String> readCells(Element row, List<String> sharedStrings) {
        Map<Integer, String> cells = new HashMap<>();
        NodeList cellNodes = row.getElementsByTagNameNS("*", "c");
        for (int i = 0; i < cellNodes.getLength(); i++) {
            Element cell = (Element) cellNodes.item(i);
            int columnIndex = columnIndex(cell.getAttribute("r"));
            cells.put(columnIndex, readCellValue(cell, sharedStrings));
        }
        return cells;
    }

    private String readCellValue(Element cell, List<String> sharedStrings) {
        String type = cell.getAttribute("t");
        if ("inlineStr".equals(type)) {
            return cell.getTextContent() == null ? "" : cell.getTextContent().trim();
        }
        String rawValue = childText(cell, "v");
        if (rawValue.isBlank()) {
            return "";
        }
        if ("s".equals(type)) {
            int index = parseInt(rawValue, -1);
            if (index >= 0 && index < sharedStrings.size()) {
                return sharedStrings.get(index);
            }
        }
        return rawValue.trim();
    }

    private String childText(Element element, String localName) {
        NodeList nodes = element.getElementsByTagNameNS("*", localName);
        if (nodes.getLength() == 0 || nodes.item(0) == null) {
            return "";
        }
        return nodes.item(0).getTextContent();
    }

    private int columnIndex(String cellReference) {
        int result = 0;
        for (int i = 0; i < cellReference.length(); i++) {
            char ch = cellReference.charAt(i);
            if (!Character.isLetter(ch)) {
                break;
            }
            result = result * 26 + Character.toUpperCase(ch) - 'A' + 1;
        }
        return result;
    }

    private Map<String, List<Map<String, String>>> groupRows(List<Map<String, String>> rows, String keyColumn) {
        Map<String, List<Map<String, String>>> grouped = new HashMap<>();
        for (Map<String, String> row : rows) {
            String key = valueOrDefault(row, keyColumn, "");
            if (!key.isBlank()) {
                grouped.computeIfAbsent(key, ignored -> new ArrayList<>()).add(row);
            }
        }
        return grouped;
    }

    private Map<String, List<Map<String, String>>> groupLessons(List<Map<String, String>> lessonRows) {
        Map<String, List<Map<String, String>>> grouped = new HashMap<>();
        for (Map<String, String> row : lessonRows) {
            String courseCode = valueOrDefault(row, "Course Code", "");
            String sectionCode = valueOrDefault(row, "Section Code", "");
            if (!courseCode.isBlank() && !sectionCode.isBlank()) {
                grouped.computeIfAbsent(buildLessonKey(courseCode, sectionCode), ignored -> new ArrayList<>()).add(row);
            }
        }
        return grouped;
    }

    private String buildLessonKey(String courseCode, String sectionCode) {
        return courseCode + "::" + sectionCode;
    }

    private String buildLessonKey(String courseCode, String sectionCode, String lessonCode) {
        return courseCode + "::" + sectionCode + "::" + lessonCode;
    }

    private QuestionCategory resolveQuestionCategory(String rawValue, List<String> warnings) {
        List<QuestionCategory> categories = questionCategoryRepository.findAll();
        if (categories.isEmpty()) {
            throw new RuntimeException("No question categories are configured");
        }
        if (rawValue != null && !rawValue.isBlank()) {
            String normalized = rawValue.trim();
            for (QuestionCategory category : categories) {
                if (category.getName() != null && category.getName().equalsIgnoreCase(normalized)) {
                    return category;
                }
            }
            warnings.add("Unknown question category '" + rawValue + "' was replaced with " + categories.get(0).getName()
                    + ".");
        }
        return categories.get(0);
    }

    private SystemParameter resolveQuestionDifficulty(
            Map<String, String> questionRow,
            SystemParameter fallbackDifficulty,
            List<String> warnings) {
        String rawDifficulty = valueOrDefault(questionRow, "Difficulty", "");
        if (!rawDifficulty.isBlank()) {
            return resolveParameter(
                    "DIFFICULTY",
                    rawDifficulty,
                    fallbackDifficulty != null ? fallbackDifficulty.getParamKey() : "EASY",
                    warnings);
        }
        if (fallbackDifficulty != null) {
            return fallbackDifficulty;
        }
        return resolveParameter("DIFFICULTY", "EASY", "EASY", warnings);
    }

    private SystemParameter resolveQuestionSkill(
            Map<String, String> questionRow,
            SystemParameter courseCategory,
            List<String> warnings) {
        String rawSkill = valueOrDefault(questionRow, "Skill Type", "");

        if (rawSkill.isBlank()) {
            throw new IllegalArgumentException("Question row is missing required value: Skill Type");
        }

        String normalizedSkill = normalizeParameterKey(rawSkill);
        
        // We pass the normalizedSkill as the fallbackKey. 
        // If it's not found in the DB (or in the aliases), resolveParameter will throw: 
        // "System parameter not found: SKILL/[NORMALIZED_SKILL]"
        // This gives the exact error message requested.
        return resolveParameter(
                "SKILL",
                rawSkill,
                normalizedSkill,
                warnings);
    }

    private SystemParameter resolveGroupType(
            Map<String, String> questionRow,
            List<String> warnings) {
        String rawGroupType = valueOrDefault(questionRow, "Group Type", "");
        if (!rawGroupType.isBlank()) {
            return resolveParameter(
                    "GROUP_TYPE",
                    rawGroupType,
                    "READING_COMPREHENSION_8_QUESTIONS",
                    warnings);
        }
        return resolveParameter("GROUP_TYPE", "READING_COMPREHENSION_8_QUESTIONS", "READING_COMPREHENSION_8_QUESTIONS",
                warnings);
    }

    private void saveQuestionOptions(Question question, Map<String, String> questionRow, List<String> warnings) {
        String correctAnswer = valueOrDefault(questionRow, "Correct Answer", "A").trim();
        String[] optionColumns = { "Option A", "Option B", "Option C", "Option D" };
        String[] optionKeys = { "A", "B", "C", "D" };

        // Phat hien loi du lieu THAT SU tung bi AN DI: neu cot "Correct Answer"
        // trong Excel co gia tri khong khop bat ky option nao (vd go nham "E",
        // hoac mot so ngoai pham vi A-D), TRUOC DAY khong co option nao duoc
        // danh dau is_correct=true - cau hoi do bi nhap vao he thong ma KHONG CO
        // dap an dung nao ca (hoc vien khong the nao lam dung cau do), va Trainer
        // khong he duoc canh bao ve viec nay. O day KHONG doi logic xac dinh dap
        // an dung (isCorrectAnswer giu nguyen 100%, tranh rui ro doi hanh vi tren
        // 1 file chua co unit test nao) - chi THEM canh bao de Trainer biet ma tu
        // vao sua lai cau hoi trong Question Bank.
        List<String> presentKeys = new ArrayList<>();
        boolean anyMarkedCorrect = false;
        for (int i = 0; i < optionColumns.length; i++) {
            String optionText = valueOrDefault(questionRow, optionColumns[i], "");
            if (optionText.isBlank()) {
                continue;
            }
            presentKeys.add(optionKeys[i]);
            boolean isCorrect = isCorrectAnswer(correctAnswer, optionKeys[i], i);
            if (isCorrect) {
                anyMarkedCorrect = true;
            }
            QuestionOption option = new QuestionOption();
            option.setQuestion(question);
            option.setOptionText(optionText);
            option.setIsCorrect(isCorrect);
            questionOptionRepository.save(option);
        }

        if (!anyMarkedCorrect && !presentKeys.isEmpty()) {
            warnings.add("Question '" + valueOrDefault(questionRow, "Question Title", "(untitled)")
                    + "': Correct Answer value '" + correctAnswer + "' did not match any option ("
                    + String.join(", ", presentKeys)
                    + "); this question was imported with NO correct answer set - please fix it in the Question Bank.");
        }
    }

    private boolean isCorrectAnswer(String correctAnswer, String optionKey, int optionIndex) {
        if (correctAnswer == null || correctAnswer.isBlank()) {
            return optionIndex == 0;
        }
        String normalized = correctAnswer.trim();
        if (normalized.equalsIgnoreCase(optionKey)) {
            return true;
        }
        try {
            return Integer.parseInt(normalized) == optionIndex + 1;
        } catch (NumberFormatException ignored) {
            return false;
        }
    }

    private SystemParameter resolveParameter(String type, String rawValue, String fallbackKey, List<String> warnings) {
        String normalizedKey = normalizeParameterKey(rawValue);
        return systemParameterRepository.findByParamTypeAndParamKey(type, normalizedKey)
                .or(() -> systemParameterRepository.findByParamTypeAndParamKey(type,
                        aliasParameterKey(type, normalizedKey)))
                .or(() -> fallbackKey != null
                        ? systemParameterRepository.findByParamTypeAndParamKey(type, fallbackKey)
                        : java.util.Optional.empty())
                .map(parameter -> {
                    String selectedKey = parameter.getParamKey();
                    if (!selectedKey.equals(normalizedKey)
                            && !selectedKey.equals(aliasParameterKey(type, normalizedKey))) {
                        warnings.add(
                                "Unknown " + type + " value '" + rawValue + "' was replaced with "
                                        + (fallbackKey != null ? fallbackKey : selectedKey) + ".");
                    }
                    return parameter;
                })
                .orElseThrow(() -> new RuntimeException("System parameter not found: " + type + "/"
                        + (fallbackKey != null ? fallbackKey : normalizedKey)));
    }

    private String normalizeParameterKey(String value) {
        if (value == null) return "";
        return value.trim()
                .replace('-', '_')
                .replace('/', '_')
                .replaceAll("\\s+", "_")
                .replaceAll("_+", "_")
                .toUpperCase(Locale.ROOT);
    }

    private String aliasParameterKey(String type, String key) {
        if ("ACADEMIC_LEVEL".equals(type) && "BEGINNER".equals(key)) {
            return "BASIC";
        }
        if ("COURSE_CATEGORY".equals(type)) {
            if ("READING".equals(key)) {
                return "READING_COMPREHENSION";
            }
            if ("SPEAKING".equals(key)) {
                return "PRONUNCIATION";
            }
            if ("WRITING".equals(key)) {
                return "GRAMMAR";
            }
        }
        return key;
    }

    /** Whether a SYLLABUS row's (lowercased) Type is one of the supported lesson content types. */
    private boolean isLessonType(String type) {
        return type.equals("video") || type.equals("text") || type.equals("quiz") || type.equals("pdf");
    }

    private void addError(List<Map<String, Object>> errors, String sheet, Integer row, String field,
            String errorType, String value, String message) {
        Map<String, Object> err = new LinkedHashMap<>();
        err.put("sheet", sheet);
        err.put("row", row);
        err.put("field", field);
        err.put("errorType", errorType);
        err.put("value", value);
        err.put("message", message);
        errors.add(err);
    }

    private String normalizeLessonType(String lessonType) {
        String normalized = normalizeParameterKey(lessonType);
        if ("VIDEO".equals(normalized)) {
            return "video";
        }
        if ("PDF".equals(normalized)) {
            return "pdf";
        }
        if ("QUIZ".equals(normalized) || "PRACTICE".equals(normalized)) {
            return "quiz";
        }
        return "text";
    }

    private String resolveLessonContent(Map<String, String> lessonRow, String lessonType) {
        if ("video".equals(lessonType) || "pdf".equals(lessonType)) {
            String mediaUrl = valueOrDefault(lessonRow, "Media File URL or Placeholder", "");
            if (!mediaUrl.isBlank()) {
                return mediaUrl;
            }
        }
        String markdown = valueOrDefault(lessonRow, "Text Content Markdown", "");
        if (!markdown.isBlank()) {
            return markdown;
        }
        String html = valueOrDefault(lessonRow, "Text Content HTML", "");
        if (!html.isBlank()) {
            return html;
        }
        return valueOrDefault(lessonRow, "Media File URL or Placeholder", "");
    }

    private String resolvePdfName(Map<String, String> lessonRow) {
        String type = normalizeLessonType(valueOrDefault(lessonRow, "Lesson Type", "TEXT"));
        if ("pdf".equals(type)) {
            return valueOrDefault(lessonRow, "Media File URL or Placeholder", "");
        }
        return null;
    }

    private String resolveImageUrl(Map<String, String> lessonRow) {
        String mediaType = valueOrDefault(lessonRow, "Media Type", "").toLowerCase(Locale.ROOT);
        if (mediaType.startsWith("image/")) {
            return valueOrDefault(lessonRow, "Media File URL or Placeholder", "");
        }
        return null;
    }

    private String required(Map<String, String> row, String column, String sheet) {
        String value = valueOrDefault(row, column, "");
        if (value.isBlank()) {
            throw new IllegalArgumentException(sheet + " sheet is missing required value: " + column);
        }
        return value;
    }

    private String valueOrDefault(Map<String, String> row, String column, String defaultValue) {
        String value = row.get(column);
        return value == null || value.isBlank() ? defaultValue : value.trim();
    }

    private String resolveUniqueCourseCode(
            String requestedCode,
            Set<String> reservedCodes,
            List<String> warnings) {
        String baseCode = trimToMaxLength(requestedCode.trim(), 100);
        String candidate = baseCode;
        int suffix = 2;
        while (courseCodeExists(candidate, reservedCodes)) {
            String suffixText = "-" + suffix++;
            candidate = trimToMaxLength(baseCode, 100 - suffixText.length()) + suffixText;
        }

        reservedCodes.add(candidate.toUpperCase(Locale.ROOT));
        if (!candidate.equals(requestedCode)) {
            warnings.add("Course Code '" + requestedCode + "' already exists and was imported as '" + candidate + "'.");
        }
        return candidate;
    }

    private boolean courseCodeExists(String code, Set<String> reservedCodes) {
        return reservedCodes.contains(code.toUpperCase(Locale.ROOT))
                || courseRepository.existsByCodeIgnoreCase(code);
    }

    private String trimToMaxLength(String value, int maxLength) {
        if (value.length() <= maxLength) {
            return value;
        }
        return value.substring(0, maxLength);
    }

    private int parseInt(String value, int defaultValue) {
        if (value == null || value.isBlank()) {
            return defaultValue;
        }
        try {
            return (int) Double.parseDouble(value.trim());
        } catch (NumberFormatException ignored) {
            return defaultValue;
        }
    }

    private Integer parseInteger(String value, Integer defaultValue) {
        if (value == null || value.isBlank()) {
            return defaultValue;
        }
        try {
            return (int) Double.parseDouble(value.trim());
        } catch (NumberFormatException ignored) {
            return defaultValue;
        }
    }

    private Long parseLong(String value, Long defaultValue) {
        if (value == null || value.isBlank()) {
            return defaultValue;
        }
        try {
            return (long) Double.parseDouble(value.trim());
        } catch (NumberFormatException ignored) {
            return defaultValue;
        }
    }

    // Gia THAM KHAO cho khoa hoc import tu Excel - dung CHINH XAC cong thuc va
    // gioi han (lam tron boi so 50.000d, ke trong 300.000d-700.000d) nhu
    // TrainerDashboardServiceImpl.calculateSuggestedPrice, de nhat quan giua
    // 2 con duong tao course (thu cong qua UI vs import hang loat). Gia BAN
    // THAT SU khong con tinh o day nua - xem importWorkbook() (doc cot "Price"
    // tuy chon, hoac mac dinh ve dung gia tham khao nay).
    private BigDecimal calculateSuggestedPrice(TrainerProfile profile,
            SystemParameter difficulty, int lessonCount, int durationMinutes) {
        long price = 0;
        if (profile != null) {
            if ("PROFESSIONAL".equalsIgnoreCase(profile.getTrainerType())) {
                price += 300000;
            } else if ("PEER_TUTOR".equalsIgnoreCase(profile.getTrainerType())) {
                price += 150000;
            }
            if (profile.getScoreReportUrl() != null && !profile.getScoreReportUrl().isBlank()) {
                price += 150000;
            }
        }
        if (difficulty != null) {
            String level = difficulty.getParamKey();
            if ("ADVANCED".equalsIgnoreCase(level)) {
                price += 200000;
            } else if ("INTERMEDIATE".equalsIgnoreCase(level)) {
                price += 100000;
            } else if ("BASIC".equalsIgnoreCase(level)) {
                price += 50000;
            }
        }
        price += (lessonCount * 10000L);
        price += (durationMinutes * 1000L);

        long roundingStepVnd = 50000L;
        long rounded = Math.round(price / (double) roundingStepVnd) * roundingStepVnd;
        BigDecimal result = BigDecimal.valueOf(rounded);
        BigDecimal min = BigDecimal.valueOf(300000);
        BigDecimal max = BigDecimal.valueOf(700000);
        if (result.compareTo(min) < 0) {
            return min;
        }
        if (result.compareTo(max) > 0) {
            return max;
        }
        return result;
    }

    /**
     * §4: Normalize course name — trim leading/trailing whitespace, collapse
     * multiple internal spaces into a single space, preserve original case.
     */
    private String normalizeCourseName(String name) {
        if (name == null) return null;
        String trimmed = name.trim();
        if (trimmed.isEmpty()) return trimmed;
        return trimmed.replaceAll("\\s+", " ");
    }

    private record WorkbookData(Map<String, List<SheetRow>> rowsBySheet) {
    }

    /** One data row from a sheet, paired with its original Excel row number (1-indexed) for error reporting. */
    private record SheetRow(int rowNumber, Map<String, String> data) {
    }

    /** Parsed section from CURRICULUM for structure validation (§10-12). */
    private static class CurriculumSection {
        final String title;
        final int rowNumber;
        int regularLessonCount = 0;
        int quizCount = 0;
        final List<String> quizTitles = new ArrayList<>();
        final List<CurriculumItem> allItems = new ArrayList<>();

        CurriculumSection(String title, int rowNumber) {
            this.title = title;
            this.rowNumber = rowNumber;
        }
    }

    /** Parsed item (lesson/quiz) within a CurriculumSection. */
    private record CurriculumItem(String type, String title, int rowNumber) {
    }
}
