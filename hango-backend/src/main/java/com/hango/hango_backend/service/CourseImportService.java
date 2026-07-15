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
import com.hango.hango_backend.repository.UserRepository;
import lombok.RequiredArgsConstructor;
import org.springframework.jdbc.core.JdbcTemplate;
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
    private final CourseRepository courseRepository;
    private final SectionRepository sectionRepository;
    private final LessonRepository lessonRepository;
    private final QuestionRepository questionRepository;
    private final QuestionOptionRepository questionOptionRepository;
    private final QuestionCategoryRepository questionCategoryRepository;
    private final SystemParameterRepository systemParameterRepository;
    private final JdbcTemplate jdbcTemplate;

    @Transactional
    public CourseImportResultDTO importWorkbook(String trainerEmail, MultipartFile file) throws Exception {
        validateWorkbookFile(file);

        User trainer = userRepository.findByEmail(trainerEmail)
                .orElseThrow(() -> new RuntimeException("User not found with email: " + trainerEmail));

        WorkbookData workbook = readWorkbook(file);
        List<Map<String, String>> courseRows = workbook.rowsBySheet.getOrDefault("COURSE", List.of());
        List<Map<String, String>> sectionRows = workbook.rowsBySheet.getOrDefault("SECTIONS", List.of());
        List<Map<String, String>> lessonRows = workbook.rowsBySheet.getOrDefault("LESSONS", List.of());
        List<Map<String, String>> questionRows = workbook.rowsBySheet.getOrDefault("QUESTIONS", List.of());

        if (courseRows.isEmpty()) {
            throw new IllegalArgumentException("COURSE sheet must contain at least one course row");
        }

        List<String> warnings = new ArrayList<>();
        Map<String, List<Map<String, String>>> sectionsByCourse = groupRows(sectionRows, "Course Code");
        Map<String, List<Map<String, String>>> lessonsByCourseAndSection = groupLessons(lessonRows);
        Map<String, Lesson> lessonsByImportKey = new HashMap<>();
        Map<String, Section> sectionsByImportKey = new HashMap<>();
        Map<String, SystemParameter> categoryByCourseCode = new HashMap<>();
        Map<String, SystemParameter> difficultyByCourseCode = new HashMap<>();

        List<Long> courseIds = new ArrayList<>();
        int importedSections = 0;
        int importedLessons = 0;
        int importedQuestions = 0;

        Set<String> knownCourseCodes = new java.util.HashSet<>();
        for (Map<String, String> courseRow : courseRows) {
            String courseCode = required(courseRow, "Course Code", "COURSE");
            if (!knownCourseCodes.add(courseCode)) {
                throw new IllegalArgumentException("Duplicate Course Code in COURSE sheet: " + courseCode);
            }

            SystemParameter category = resolveParameter(
                    "COURSE_CATEGORY",
                    valueOrDefault(courseRow, "Category", "GRAMMAR"),
                    "GRAMMAR",
                    warnings
            );
            SystemParameter difficulty = resolveParameter(
                    "ACADEMIC_LEVEL",
                    valueOrDefault(courseRow, "Difficulty", "BASIC"),
                    "BASIC",
                    warnings
            );
            categoryByCourseCode.put(courseCode, category);
            difficultyByCourseCode.put(courseCode, difficulty);

            String requestedStatus = valueOrDefault(courseRow, "Status", "DRAFT").toUpperCase(Locale.ROOT);
            if (!"DRAFT".equals(requestedStatus)) {
                warnings.add("Course " + courseCode + " was imported as DRAFT because trainer imports still require review before publishing.");
            }

            Course course = Course.builder()
                    .title(required(courseRow, "Title", "COURSE"))
                    .description(valueOrDefault(courseRow, "Description", ""))
                    .creator(trainer)
                    .category(category)
                    .difficulty(difficulty)
                    .thumbnailUrl(valueOrDefault(courseRow, "Thumbnail URL", ""))
                    .status("DRAFT")
                    .build();
            Course savedCourse = courseRepository.save(course);
            courseIds.add(savedCourse.getId());

            List<Map<String, String>> matchingSections = new ArrayList<>(sectionsByCourse.getOrDefault(courseCode, List.of()));
            matchingSections.sort(Comparator.comparingInt(row -> parseInt(valueOrDefault(row, "Section Order Index", "0"), 0)));

            Set<String> knownSectionCodes = new java.util.HashSet<>();
            for (int sectionIndex = 0; sectionIndex < matchingSections.size(); sectionIndex++) {
                Map<String, String> sectionRow = matchingSections.get(sectionIndex);
                String sectionCode = required(sectionRow, "Section Code", "SECTIONS");
                if (!knownSectionCodes.add(sectionCode)) {
                    throw new IllegalArgumentException("Duplicate Section Code in course " + courseCode + ": " + sectionCode);
                }

                Section section = Section.builder()
                        .course(savedCourse)
                        .title(required(sectionRow, "Section Title", "SECTIONS"))
                        .description(valueOrDefault(sectionRow, "Section Description", ""))
                        .displayOrder(parseInt(valueOrDefault(sectionRow, "Section Order Index", ""), sectionIndex + 1))
                        .build();
                Section savedSection = sectionRepository.save(section);
                sectionsByImportKey.put(buildLessonKey(courseCode, sectionCode), savedSection);
                importedSections++;

                String lessonKey = buildLessonKey(courseCode, sectionCode);
                List<Map<String, String>> matchingLessons = new ArrayList<>(lessonsByCourseAndSection.getOrDefault(lessonKey, List.of()));
                matchingLessons.sort(Comparator.comparingInt(row -> parseInt(valueOrDefault(row, "Order Index", "0"), 0)));

                Set<String> knownLessonCodes = new java.util.HashSet<>();
                for (int lessonIndex = 0; lessonIndex < matchingLessons.size(); lessonIndex++) {
                    Map<String, String> lessonRow = matchingLessons.get(lessonIndex);
                    String lessonCode = required(lessonRow, "Lesson Code", "LESSONS");
                    if (!knownLessonCodes.add(lessonCode)) {
                        throw new IllegalArgumentException("Duplicate Lesson Code in section " + sectionCode + ": " + lessonCode);
                    }

                    Lesson lesson = Lesson.builder()
                            .section(savedSection)
                            .title(required(lessonRow, "Lesson Title", "LESSONS"))
                            .lessonType(normalizeLessonType(valueOrDefault(lessonRow, "Lesson Type", "TEXT")))
                            .skill(category)
                            .difficulty(difficulty)
                            .content(resolveLessonContent(lessonRow))
                            .displayOrder(parseInt(valueOrDefault(lessonRow, "Order Index", ""), lessonIndex + 1))
                            .description(valueOrDefault(lessonRow, "Learning Objectives", ""))
                            .pdfName(resolvePdfName(lessonRow))
                            .questionImageUrl(resolveImageUrl(lessonRow))
                            .build();
                    Lesson savedLesson = lessonRepository.save(lesson);
                    lessonsByImportKey.put(buildLessonKey(courseCode, sectionCode, lessonCode), savedLesson);
                    importedLessons++;
                }
            }
        }

        for (Map<String, String> sectionRow : sectionRows) {
            String courseCode = valueOrDefault(sectionRow, "Course Code", "");
            if (!courseCode.isBlank() && !knownCourseCodes.contains(courseCode)) {
                warnings.add("Section row references unknown Course Code: " + courseCode);
            }
        }

        for (Map<String, String> questionRow : questionRows) {
            if (valueOrDefault(questionRow, "Question Text", "").isBlank()) {
                continue;
            }

            String courseCode = valueOrDefault(questionRow, "Course Code", "");
            String sectionCode = valueOrDefault(questionRow, "Section Code", "");
            String lessonCode = valueOrDefault(questionRow, "Lesson Code", "");
            if (courseCode.isBlank() || sectionCode.isBlank() || lessonCode.isBlank()) {
                warnings.add("Question row skipped because Course Code, Section Code, or Lesson Code is missing.");
                continue;
            }

            Lesson targetLesson = lessonsByImportKey.get(buildLessonKey(courseCode, sectionCode, lessonCode));
            if (targetLesson == null) {
                warnings.add("Question row skipped because lesson mapping was not found: "
                        + courseCode + "/" + sectionCode + "/" + lessonCode + ".");
                continue;
            }

            Section targetSection = sectionsByImportKey.get(buildLessonKey(courseCode, sectionCode));
            SystemParameter courseCategory = categoryByCourseCode.get(courseCode);
            SystemParameter courseDifficulty = difficultyByCourseCode.get(courseCode);
            Question question = new Question();
            question.setCreatedBy(trainer);
            question.setCategory(resolveQuestionCategory(valueOrDefault(questionRow, "Category", ""), warnings));
            question.setQuestionText(required(questionRow, "Question Text", "QUESTIONS"));
            question.setExplanation(valueOrDefault(questionRow, "Explaination", valueOrDefault(questionRow, "Explanation", "")));
            question.setDifficulty(resolveQuestionDifficulty(questionRow, courseDifficulty, warnings));
            question.setSkillParam(resolveQuestionSkill(questionRow, courseCategory, warnings));
            question.setSection(targetSection);
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
                    "ACADEMIC_LEVEL",
                    rawDifficulty,
                    fallbackDifficulty != null ? fallbackDifficulty.getParamKey() : "BASIC",
                    warnings
            );
        }
        if (fallbackDifficulty != null) {
            return fallbackDifficulty;
        }
        return resolveParameter("ACADEMIC_LEVEL", "BASIC", "BASIC", warnings);
    }

    private SystemParameter resolveQuestionSkill(
            Map<String, String> questionRow,
            SystemParameter fallbackSkill,
            List<String> warnings
    ) {
        String rawSkill = valueOrDefault(questionRow, "Skill Type", "");
        if (!rawSkill.isBlank()) {
            return resolveParameter(
                    "COURSE_CATEGORY",
                    rawSkill,
                    fallbackSkill != null ? fallbackSkill.getParamKey() : "GRAMMAR",
                    warnings
            );
        }
        if (fallbackSkill != null) {
            return fallbackSkill;
        }
        return resolveParameter("COURSE_CATEGORY", "GRAMMAR", "GRAMMAR", warnings);
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

    private String resolveLessonContent(Map<String, String> lessonRow) {
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

    private record WorkbookData(Map<String, List<Map<String, String>>> rowsBySheet) {
    }
}
