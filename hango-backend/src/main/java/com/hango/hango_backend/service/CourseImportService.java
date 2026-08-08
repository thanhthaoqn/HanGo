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
import lombok.RequiredArgsConstructor;
import org.springframework.jdbc.core.JdbcTemplate;
import java.math.BigDecimal;
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
        List<Map<String, String>> courseRowsRaw = workbook.rowsBySheet.getOrDefault("COURSE", List.of());
        List<Map<String, String>> syllabusRows = workbook.rowsBySheet.getOrDefault("SYLLABUS", List.of());
        List<Map<String, String>> questionRows = workbook.rowsBySheet.getOrDefault("QUESTIONS", List.of());

        if (courseRowsRaw.isEmpty()) {
            throw new IllegalArgumentException("COURSE sheet must contain at least one row");
        }

        Map<String, String> courseData = new java.util.HashMap<>();
        for (Map<String, String> row : courseRowsRaw) {
            String field = valueOrDefault(row, "Information Field", "").trim();
            String data = valueOrDefault(row, "Fill Data", "").trim();
            if (!field.isEmpty()) {
                courseData.put(field, data);
            }
        }

        String courseTitle = courseData.get("Title");
        if (courseTitle == null || courseTitle.isBlank()) {
            throw new IllegalArgumentException("COURSE sheet is missing required value: Title");
        }
        
        List<String> warnings = new ArrayList<>();
        if (courseRepository.existsByTitleIgnoreCase(courseTitle)) {
            throw new IllegalArgumentException("Course with title '" + courseTitle + "' already exists.");
        }

        String courseCodeRaw = courseData.get("Course Code");
        if (courseCodeRaw == null || courseCodeRaw.isBlank()) {
            throw new IllegalArgumentException("COURSE sheet is missing required value: Course Code");
        }
        
        Set<String> reservedPersistedCourseCodes = new java.util.HashSet<>();
        String persistedCourseCode = resolveUniqueCourseCode(courseCodeRaw, reservedPersistedCourseCodes, warnings);

        SystemParameter category = resolveParameter(
                "COURSE_CATEGORY",
                valueOrDefault(courseData, "Category", "GRAMMAR"),
                "GRAMMAR",
                warnings
        );
        SystemParameter difficulty = resolveParameter(
                "ACADEMIC_LEVEL",
                valueOrDefault(courseData, "Academic Level", "BASIC"),
                "BASIC",
                warnings
        );

        String requestedStatus = valueOrDefault(courseData, "Status", "DRAFT").toUpperCase(Locale.ROOT);
        if (!"DRAFT".equals(requestedStatus)) {
            warnings.add("Course " + persistedCourseCode + " was imported as DRAFT because trainer imports still require review before publishing.");
        }

        int lessonCount = 0;
        int durationMinutes = 0;
        for (Map<String, String> row : syllabusRows) {
            String type = valueOrDefault(row, "Type", "").trim().toLowerCase(Locale.ROOT);
            if (type.equals("video") || type.equals("text") || type.equals("quiz") || type.equals("pdf")) {
                lessonCount++;
                durationMinutes += parseInteger(valueOrDefault(row, "Duration (Mins)", ""), 0);
            }
        }

        BigDecimal calculatedPrice = calculateCoursePrice(trainerProfile, difficulty, lessonCount, durationMinutes);

        Course course = Course.builder()
                .title(courseTitle)
                .description(valueOrDefault(courseData, "Description", ""))
                .creator(trainer)
                .category(category)
                .difficulty(difficulty)
                .thumbnailUrl(valueOrDefault(courseData, "Thumbnail URL", ""))
                .code(persistedCourseCode)
                .price(calculatedPrice)
                .suggestedPrice(calculatedPrice)
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
        Set<String> knownSectionTitles = new java.util.HashSet<>();
        Set<String> knownLessonTitles = new java.util.HashSet<>();

        for (int i = 0; i < syllabusRows.size(); i++) {
            Map<String, String> row = syllabusRows.get(i);
            String type = valueOrDefault(row, "Type", "").trim().toLowerCase(Locale.ROOT);
            String title = valueOrDefault(row, "Title", "").trim();
            if (type.isEmpty() || title.isEmpty()) {
                continue;
            }

            if (type.equals("section")) {
                if (!knownSectionTitles.add(title.toLowerCase(Locale.ROOT))) {
                    throw new IllegalArgumentException("Duplicate Section Title in syllabus: " + title);
                }
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
            } else if (type.equals("video") || type.equals("text") || type.equals("quiz") || type.equals("pdf")) {
                if (currentSection == null) {
                    throw new IllegalArgumentException("Found a lesson before any section in SYLLABUS sheet: " + title);
                }
                if (!knownLessonTitles.add(title.toLowerCase(Locale.ROOT))) {
                    throw new IllegalArgumentException("Duplicate Lesson Title in syllabus: " + title);
                }

                String lessonType = normalizeLessonType(type);
                String contentUrl = valueOrDefault(row, "Content / Media URL", "");

                String videoTranscript = null;
                if ("video".equalsIgnoreCase(lessonType) && contentUrl != null && contentUrl.toLowerCase().contains("youtu")) {
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

        for (Map<String, String> questionRow : questionRows) {
            String questionText = valueOrDefault(questionRow, "Question Text", "");
            if (questionText.isBlank()) {
                continue;
            }

            String questionTitle = valueOrDefault(questionRow, "Question Title", "").trim();
            if (questionTitle.isBlank()) {
                warnings.add("Question row skipped because Question Title is missing.");
                continue;
            }

            Lesson targetLesson = lessonsByTitle.get(questionTitle.toLowerCase(Locale.ROOT));
            if (targetLesson == null) {
                warnings.add("Question row skipped because lesson with title '" + questionTitle + "' was not found in SYLLABUS.");
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
            question.setExplanation(valueOrDefault(questionRow, "Explaination", valueOrDefault(questionRow, "Explanation", "")));
            question.setDifficulty(resolveQuestionDifficulty(questionRow, difficulty, warnings));
            question.setSkillParam(resolveQuestionSkill(questionRow, category, warnings));
            question.setSection(targetLesson.getSection());
            question.setQuestionGroup(questionGroup);
            question.setStatus("APPROVED");

            Question savedQuestion = questionRepository.save(question);
            saveQuestionOptions(savedQuestion, questionRow);

            int displayOrder = parseInt(valueOrDefault(questionRow, "Order Index", ""), importedQuestions + 1);
            jdbcTemplate.update(
                    "INSERT INTO lesson_quizzes (lesson_id, question_id, display_order) VALUES (?, ?, ?)",
                    targetLesson.getId(),
                    savedQuestion.getId(),
                    displayOrder
            );
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
        for (Path candidate : templateCandidates()) {
            if (Files.isRegularFile(candidate)) {
                return Files.readAllBytes(candidate);
            }
        }
        throw new IOException("Course import template not found. Expected " + TEMPLATE_FILE_NAME
                + " under doc/specs/templates or doc/templates.");
    }

    private List<Path> templateCandidates() {
        return List.of(
                Paths.get("doc", "specs", "templates", TEMPLATE_FILE_NAME),
                Paths.get("..", "doc", "specs", "templates", TEMPLATE_FILE_NAME),
                Paths.get("doc", "templates", TEMPLATE_FILE_NAME),
                Paths.get("..", "doc", "templates", TEMPLATE_FILE_NAME)
        );
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

        Map<String, List<Map<String, String>>> rowsBySheet = new HashMap<>();
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

    private List<Map<String, String>> readSheetRows(Document worksheetXml, List<String> sharedStrings) {
        NodeList rowNodes = worksheetXml.getElementsByTagNameNS("*", "row");
        Map<Integer, String> headers = new LinkedHashMap<>();
        int headerRow = 2;
        List<Map<String, String>> rows = new ArrayList<>();

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
                rows.add(mappedRow);
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
            warnings.add("Unknown question category '" + rawValue + "' was replaced with " + categories.get(0).getName() + ".");
        }
        return categories.get(0);
    }

    private SystemParameter resolveQuestionDifficulty(
            Map<String, String> questionRow,
            SystemParameter fallbackDifficulty,
            List<String> warnings
    ) {
        String rawDifficulty = valueOrDefault(questionRow, "Difficulty", "");
        if (!rawDifficulty.isBlank()) {
            return resolveParameter(
                    "DIFFICULTY",
                    rawDifficulty,
                    fallbackDifficulty != null ? fallbackDifficulty.getParamKey() : "EASY",
                    warnings
            );
        }
        if (fallbackDifficulty != null) {
            return fallbackDifficulty;
        }
        return resolveParameter("DIFFICULTY", "EASY", "EASY", warnings);
    }

    private SystemParameter resolveQuestionSkill(
            Map<String, String> questionRow,
            SystemParameter fallbackSkill,
            List<String> warnings
    ) {
        String rawSkill = valueOrDefault(questionRow, "Skill Type", "");
        if (!rawSkill.isBlank()) {
            return resolveParameter(
                    "SKILL",
                    rawSkill,
                    fallbackSkill != null ? fallbackSkill.getParamKey() : "GRAMMAR",
                    warnings
            );
        }
        if (fallbackSkill != null) {
            return fallbackSkill;
        }
        return resolveParameter("SKILL", "GRAMMAR", "GRAMMAR", warnings);
    }

    private SystemParameter resolveGroupType(
            Map<String, String> questionRow,
            List<String> warnings
    ) {
        String rawGroupType = valueOrDefault(questionRow, "Group Type", "");
        if (!rawGroupType.isBlank()) {
            return resolveParameter(
                    "GROUP_TYPE",
                    rawGroupType,
                    "READING_COMPREHENSION_8_QUESTIONS",
                    warnings
            );
        }
        return resolveParameter("GROUP_TYPE", "READING_COMPREHENSION_8_QUESTIONS", "READING_COMPREHENSION_8_QUESTIONS", warnings);
    }

    private void saveQuestionOptions(Question question, Map<String, String> questionRow) {
        String correctAnswer = valueOrDefault(questionRow, "Correct Answer", "A").trim();
        String[] optionColumns = {"Option A", "Option B", "Option C", "Option D"};
        String[] optionKeys = {"A", "B", "C", "D"};

        for (int i = 0; i < optionColumns.length; i++) {
            String optionText = valueOrDefault(questionRow, optionColumns[i], "");
            if (optionText.isBlank()) {
                continue;
            }
            QuestionOption option = new QuestionOption();
            option.setQuestion(question);
            option.setOptionText(optionText);
            option.setIsCorrect(isCorrectAnswer(correctAnswer, optionKeys[i], i));
            questionOptionRepository.save(option);
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
                .or(() -> systemParameterRepository.findByParamTypeAndParamKey(type, aliasParameterKey(type, normalizedKey)))
                .or(() -> systemParameterRepository.findByParamTypeAndParamKey(type, fallbackKey))
                .map(parameter -> {
                    String selectedKey = parameter.getParamKey();
                    if (!selectedKey.equals(normalizedKey) && !selectedKey.equals(aliasParameterKey(type, normalizedKey))) {
                        warnings.add("Unknown " + type + " value '" + rawValue + "' was replaced with " + fallbackKey + ".");
                    }
                    return parameter;
                })
                .orElseThrow(() -> new RuntimeException("System parameter not found: " + type + "/" + fallbackKey));
    }

    private String normalizeParameterKey(String value) {
        return value == null ? "" : value.trim()
                .replace('-', '_')
                .replace(' ', '_')
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
            List<String> warnings
    ) {
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
 
    private BigDecimal calculateCoursePrice(TrainerProfile profile, SystemParameter difficulty, int lessonCount, int durationMinutes) {
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
        return BigDecimal.valueOf(price);
    }
 
    private record WorkbookData(Map<String, List<Map<String, String>>> rowsBySheet) {
    }
}
