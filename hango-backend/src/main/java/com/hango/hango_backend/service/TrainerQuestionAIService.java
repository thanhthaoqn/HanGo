package com.hango.hango_backend.service;

import com.fasterxml.jackson.databind.ObjectMapper;
import com.hango.hango_backend.dto.CreateTrainerQuestionAIRequestDTO;
import com.hango.hango_backend.dto.CreateTrainerQuestionAIResponseDTO;
import com.hango.hango_backend.dto.CreateTrainerExamAIResponseDTO;
import com.hango.hango_backend.dto.TrainerExamChatRequestDTO;
import com.hango.hango_backend.dto.GeminiGenerateRequest;
import com.hango.hango_backend.dto.GeminiGenerateResponse;
import com.hango.hango_backend.entity.SystemParameter;
import com.hango.hango_backend.exception.ApiException;
import com.hango.hango_backend.repository.SystemParameterRepository;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.http.HttpStatus;
import org.springframework.stereotype.Service;

import java.util.List;
import java.util.Set;
import java.util.stream.Collectors;

@Service
@RequiredArgsConstructor
@Slf4j
public class TrainerQuestionAIService {

    private static final ObjectMapper LENIENT_MAPPER = com.fasterxml.jackson.databind.json.JsonMapper.builder()
            .enable(com.fasterxml.jackson.core.json.JsonReadFeature.ALLOW_UNQUOTED_FIELD_NAMES)
            .enable(com.fasterxml.jackson.core.json.JsonReadFeature.ALLOW_TRAILING_COMMA)
            .enable(com.fasterxml.jackson.core.json.JsonReadFeature.ALLOW_SINGLE_QUOTES)
            .enable(com.fasterxml.jackson.core.json.JsonReadFeature.ALLOW_JAVA_COMMENTS)
            .build()
            .configure(com.fasterxml.jackson.databind.DeserializationFeature.FAIL_ON_UNKNOWN_PROPERTIES, false);

    private final GeminiClientService geminiClientService;
    private final ObjectMapper objectMapper;
    private final SystemParameterRepository systemParameterRepository;
    private final SystemConfigService systemConfigService;

    public static final String DEFAULT_CHAT_PROMPT = "You are a helpful AI assistant that helps trainers create exams for the HanGo English learning platform.\n" +
            "Your goal is to gather all necessary information to generate an exam.\n" +
            "You need to ask the user for:\n" +
            "- Exam title\n" +
            "- Description\n" +
            "- Duration in minutes\n" +
            "- Passing score percentage\n" +
            "- Expected total question count\n" +
            "- The breakdown of questions (single vs group, skills, difficulty, number of questions for each).\n" +
            "Do NOT ask for everything at once, keep the conversation natural.\n" +
            "When you have enough information, gently confirm with the user. Do NOT generate the actual exam questions here.";

    public static final String DEFAULT_GENERATE_PROMPT = "You are an AI generating an exam JSON structure for the HanGo platform.\n" +
            "You must output ONLY valid JSON matching this structure, with no markdown formatting or extra text.\n" +
            "Structure:\n" +
            "{\n" +
            "  \"title\": \"...\",\n" +
            "  \"description\": \"...\",\n" +
            "  \"durationMinutes\": 60,\n" +
            "  \"passingScore\": 50,\n" +
            "  \"blocks\": [\n" +
            "    {\n" +
            "      \"isQuestionGroup\": false,\n" +
            "      \"passageText\": \"\",\n" +
            "      \"sourceCitation\": \"\",\n" +
            "      \"categoryId\": 1,\n" +
            "      \"skillParamId\": 1,\n" +
            "      \"difficultyId\": 14,\n" +
            "      \"questions\": [\n" +
            "        {\n" +
            "          \"questionText\": \"...\",\n" +
            "          \"explanation\": \"...\",\n" +
            "          \"categoryId\": 1,\n" +
            "          \"difficultyId\": 14,\n" +
            "          \"options\": [\n" +
            "            {\"optionText\": \"...\", \"isCorrect\": true},\n" +
            "            {\"optionText\": \"...\", \"isCorrect\": false},\n" +
            "            {\"optionText\": \"...\", \"isCorrect\": false},\n" +
            "            {\"optionText\": \"...\", \"isCorrect\": false}\n" +
            "          ]\n" +
            "        }\n" +
            "      ]\n" +
            "    }\n" +
            "  ]\n" +
            "}\n" +
            "categoryId can default to 1 (General). difficultyId can be 14 (Easy), 15 (Medium), 16 (Hard). skillParamId can be null if not specified.\n" +
            "For group questions, set isQuestionGroup = true, provide passageText containing ONLY the reading passage (do NOT put 'Adapted from...' or source headers at the beginning of passageText), put multiple questions in the questions array, and provide sourceCitation separately for reading comprehension (e.g. 'Adapted from National Geographic', 'Adapted from BBC Focus') without fabricating fake web URLs.\n" +
            "For single questions, set isQuestionGroup = false, empty passageText, and exactly 1 question in the questions array.\n" +
            "Generate the EXACT number of questions and groups as discussed in the chat.";

    public CreateTrainerQuestionAIResponseDTO generatePayload(CreateTrainerQuestionAIRequestDTO req) {
        if (req == null) {
            throw new ApiException("request is required", HttpStatus.BAD_REQUEST);
        }
        if (req.getMode() == null || req.getMode().isBlank()) {
            throw new ApiException("mode is required", HttpStatus.BAD_REQUEST);
        }
        if (req.getTopicSeed() == null || req.getTopicSeed().isBlank()) {
            throw new ApiException("topicSeed is required", HttpStatus.BAD_REQUEST);
        }

        String mode = req.getMode().trim().toUpperCase();
        int quantity = req.getQuantity() == null ? 1 : req.getQuantity();
        if (quantity <= 0) quantity = 1;

        long categoryId = req.getCategoryId() != null ? req.getCategoryId() : 1L;
        long difficultyId = req.getDifficultyId() != null ? req.getDifficultyId() : 14L;

        boolean isMultipleBranch = !"SINGLE".equals(mode);
        boolean useSearchGrounding = Boolean.TRUE.equals(req.getUseSearchGrounding());

        List<SystemParameter> activeSkills = isMultipleBranch
                ? systemParameterRepository.findByParamTypeAndIsActiveTrue("SKILL_TYPE")
                : List.of();
        List<SystemParameter> activeDifficulties = isMultipleBranch
                ? systemParameterRepository.findByParamTypeAndIsActiveTrue("DIFFICULTY")
                : List.of();

        String systemPrompt = buildSystemPrompt(req, mode, quantity, activeSkills, activeDifficulties);

        String raw;
        List<GeminiGenerateResponse.WebSource> groundingSources = List.of();

        if (useSearchGrounding) {
            GeminiClientService.GeminiChatResult chatResult = geminiClientService.generateChatResponseDetailed(
                    systemPrompt,
                    List.of(
                            GeminiGenerateRequest.Content.builder()
                                    .role("user")
                                    .parts(List.of(GeminiGenerateRequest.Part.builder().text(buildUserInput(req, activeDifficulties)).build()))
                                    .build()
                    ),
                    true
            );
            raw = chatResult != null ? chatResult.getText() : null;
            if (chatResult != null && chatResult.getSources() != null) {
                groundingSources = chatResult.getSources();
            }
        } else {
            raw = geminiClientService.generateChatResponse(
                    systemPrompt,
                    List.of(
                            GeminiGenerateRequest.Content.builder()
                                    .role("user")
                                    .parts(List.of(GeminiGenerateRequest.Part.builder().text(buildUserInput(req, activeDifficulties)).build()))
                                    .build()
                    )
            );
        }

        if (raw == null || raw.isBlank()) {
            throw new ApiException("AI returned empty response", HttpStatus.BAD_GATEWAY);
        }

        // Gemini đôi khi bọc codeblock ```json ... ```
        raw = raw.replaceAll("(?s)^```json\\s*", "")
                .replaceAll("(?s)```\\s*$", "")
                .trim();
                
        // Auto-repair common LLM JSON syntax quirks (e.g. missing quote on key: `subQuestions":`)
        raw = raw.replaceAll("(?m)^(\\s*)([a-zA-Z0-9_]+)\":", "$1\"$2\":");
        raw = raw.replaceAll(",\\s*([}\\]])", "$1");

        int start = raw.indexOf('{');
        int end = raw.lastIndexOf('}');
        if (start >= 0 && end >= 0 && end > start) {
            raw = raw.substring(start, end + 1);
        }

        CreateTrainerQuestionAIResponseDTO response;
        try {
            response = LENIENT_MAPPER.readValue(raw, CreateTrainerQuestionAIResponseDTO.class);
        } catch (Exception e) {
            log.warn("Parse AI json failed. raw={}", raw, e);
            throw new ApiException("AI returned invalid JSON payload", HttpStatus.BAD_GATEWAY);
        }

        String searchSources = groundingSources.isEmpty() ? null : groundingSources.stream()
                .map(s -> (s.getTitle() != null && !s.getTitle().isBlank())
                        ? s.getTitle() + " (" + s.getUri() + ")"
                        : s.getUri())
                .distinct()
                .collect(Collectors.joining(", "));

        Long chosenSkillId = (req.getSkillType() != null && !req.getSkillType().isBlank())
                ? activeSkills.stream()
                        .filter(s -> s.getParamValue().equalsIgnoreCase(req.getSkillType().trim()))
                        .map(SystemParameter::getId)
                        .findFirst()
                        .orElse(null)
                : null;

        if (isMultipleBranch && response.getGroup() != null) {
            fillSubQuestionSkillAndDifficulty(response.getGroup(), activeSkills, activeDifficulties, chosenSkillId, difficultyId);

            attachCitationToPassage(
                    response.getGroup().getPassageText(),
                    response.getGroup().getSourceCitation(),
                    searchSources,
                    response.getGroup()::setPassageText,
                    response.getGroup()::setSourceCitation
            );
        } else if (!isMultipleBranch && response.getQuestions() != null) {
            for (CreateTrainerQuestionAIResponseDTO.SingleQuestionDTO q : response.getQuestions()) {
                if (q.getDifficultyId() == null) {
                    q.setDifficultyId(difficultyId);
                }
                if (q.getSkillParamId() == null && chosenSkillId != null) {
                    q.setSkillParamId(chosenSkillId);
                }
                String finalCitation;
                if (searchSources != null && !searchSources.isBlank()) {
                    finalCitation = "(Source: " + searchSources + ")";
                } else {
                    finalCitation = formatCitation(q.getSourceCitation(), false);
                }
                q.setSourceCitation(finalCitation);
            }
        }

        return response;
    }

    private static final java.util.regex.Pattern LEADING_CITATION_PATTERN = java.util.regex.Pattern.compile(
            "(?i)^\\s*(?:\\((?:Adapted from|Source|From)[:\\s]+([^)]+)\\)|(?:\\[(?:Adapted from|Source|From)[:\\s]+([^\\]]+)\\])|(?:Adapted from|Source:?)\\s*([^:\n\r]+)[:\\-–])\\s*"
    );

    /**
     * Dọn dẹp và chuẩn hóa bài đọc cùng nguồn trích dẫn:
     * 1. Nếu AI lỡ đặt "Adapted from ...:" ở đầu bài đọc, tự động cắt bỏ khỏi đầu đoạn văn để mở bài tự nhiên.
     * 2. Nếu AI có nguồn (hoặc lấy được từ đầu bài), chuẩn hóa thành (Adapted from: ...) và nối xuống dưới cùng bài đọc.
     */
    private void attachCitationToPassage(
            String rawPassage,
            String rawCitation,
            String searchSources,
            java.util.function.Consumer<String> passageSetter,
            java.util.function.Consumer<String> citationSetter
    ) {
        if (rawPassage == null) {
            rawPassage = "";
        }

        String cleanedPassage = rawPassage.trim();
        String extractedLeadingSource = null;

        java.util.regex.Matcher matcher = LEADING_CITATION_PATTERN.matcher(cleanedPassage);
        if (matcher.find()) {
            String g1 = matcher.group(1);
            String g2 = matcher.group(2);
            String g3 = matcher.group(3);
            extractedLeadingSource = (g1 != null) ? g1 : (g2 != null ? g2 : g3);
            if (extractedLeadingSource != null) {
                extractedLeadingSource = extractedLeadingSource.trim();
            }
            cleanedPassage = cleanedPassage.substring(matcher.end()).trim();
        }

        String finalCitation;
        if (searchSources != null && !searchSources.isBlank()) {
            finalCitation = "(Adapted from: " + searchSources + ")";
        } else {
            String candidate = (rawCitation != null && !rawCitation.isBlank()) ? rawCitation : extractedLeadingSource;
            finalCitation = formatCitation(candidate, true);
        }

        if (finalCitation != null && !finalCitation.isBlank()) {
            if (cleanedPassage.endsWith(finalCitation)) {
                cleanedPassage = cleanedPassage.substring(0, cleanedPassage.length() - finalCitation.length()).trim();
            }
            cleanedPassage = cleanedPassage + "\n\n" + finalCitation;
        }

        passageSetter.accept(cleanedPassage);
        citationSetter.accept(finalCitation);
    }

    /**
     * Chuẩn hóa nguồn trích dẫn văn bản (Textual Citation):
     * - Loại bỏ hoàn toàn các đường dẫn URL (http/https/www) do AI tự bịa để tránh lỗi 404.
     * - Giữ lại tên sách, bài báo, tác giả hợp lệ (ví dụ: "Adapted from The Psychology of Money").
     * - Format chuẩn theo format đề thi (Adapted from: ...) hoặc (Source: ...).
     */
    private String formatCitation(String rawCitation, boolean isMultiple) {
        if (rawCitation == null || rawCitation.isBlank()) {
            return null;
        }

        String cleaned = rawCitation.trim();

        if (cleaned.equalsIgnoreCase("null") || cleaned.equalsIgnoreCase("none")
                || cleaned.equalsIgnoreCase("n/a") || cleaned.equalsIgnoreCase("unknown")
                || cleaned.equalsIgnoreCase("undefined")) {
            return null;
        }

        // Loại bỏ URL đặt trong ngoặc: (https://...), [https://...]
        cleaned = cleaned.replaceAll("(?i)\\s*\\([\\s]*https?://[^)]*\\)", "");
        cleaned = cleaned.replaceAll("(?i)\\s*\\[[\\s]*https?://[^\\]]*\\]", "");

        // Loại bỏ mọi URL trần còn lại
        cleaned = cleaned.replaceAll("(?i)https?://\\S+", "");
        cleaned = cleaned.replaceAll("(?i)www\\.\\S+", "");

        // Dọn dẹp ngoặc rỗng, ngoặc đơn lẻ loi hoặc dấu thừa ở cuối
        cleaned = cleaned.replaceAll("\\(\\s*\\)", "");
        cleaned = cleaned.replaceAll("\\[\\s*\\]", "");
        cleaned = cleaned.replaceAll("[({\\[,:;\\-\\s]+$", "");
        cleaned = cleaned.trim();

        if (cleaned.isBlank()) {
            return null;
        }

        if (cleaned.startsWith("(") && cleaned.endsWith(")")) {
            String inner = cleaned.substring(1, cleaned.length() - 1).trim();
            if (inner.isBlank()) return null;
            return cleaned;
        }

        String lower = cleaned.toLowerCase();
        if (lower.startsWith("adapted from") || lower.startsWith("source:") || lower.startsWith("from:")) {
            return "(" + cleaned + ")";
        }

        String prefix = isMultiple ? "Adapted from: " : "Source: ";
        return "(" + prefix + cleaned + ")";
    }

    /**
     * The AI is asked to pick a skillParamId/difficultyId per subQuestion (see buildSystemPrompt),
     * but it may omit them or hallucinate an id outside the valid set. Fall back to the first
     * valid option so sub-questions never reach the FE with a blank skill/difficulty.
     */
    private void fillSubQuestionSkillAndDifficulty(
            CreateTrainerQuestionAIResponseDTO.MultipleGroupDTO group,
            List<SystemParameter> activeSkills,
            List<SystemParameter> activeDifficulties,
            Long chosenSkillId,
            Long chosenDifficultyId
    ) {
        if (group.getSubQuestions() == null) return;

        Set<Long> validSkillIds = activeSkills.stream().map(SystemParameter::getId).collect(Collectors.toSet());
        Set<Long> validDifficultyIds = activeDifficulties.stream().map(SystemParameter::getId).collect(Collectors.toSet());

        Long fallbackSkillId = chosenSkillId != null && validSkillIds.contains(chosenSkillId)
                ? chosenSkillId
                : (activeSkills.isEmpty() ? null : activeSkills.get(0).getId());
        Long fallbackDifficultyId = chosenDifficultyId != null && validDifficultyIds.contains(chosenDifficultyId)
                ? chosenDifficultyId
                : (group.getDifficultyId() != null && validDifficultyIds.contains(group.getDifficultyId())
                        ? group.getDifficultyId()
                        : (activeDifficulties.isEmpty() ? null : activeDifficulties.get(0).getId()));

        for (CreateTrainerQuestionAIResponseDTO.SubQuestionDTO sub : group.getSubQuestions()) {
            if (sub.getSkillParamId() == null || !validSkillIds.contains(sub.getSkillParamId())) {
                sub.setSkillParamId(fallbackSkillId);
            }
            if (sub.getDifficultyId() == null || !validDifficultyIds.contains(sub.getDifficultyId())) {
                sub.setDifficultyId(fallbackDifficultyId);
            }
        }
    }

    public String handleExamChat(TrainerExamChatRequestDTO req) {
        if (req == null || req.getHistory() == null || req.getHistory().isEmpty()) {
            throw new ApiException("Chat history is required", HttpStatus.BAD_REQUEST);
        }

        String systemPrompt = systemConfigService.getConfigValue("AI", "AI_TRAINER_EXAM_CHAT_PROMPT", DEFAULT_CHAT_PROMPT);

        List<GeminiGenerateRequest.Content> contents = req.getHistory().stream()
                .map(msg -> GeminiGenerateRequest.Content.builder()
                        .role("model".equals(msg.getRole()) ? "model" : "user")
                        .parts(List.of(GeminiGenerateRequest.Part.builder().text(msg.getText()).build()))
                        .build())
                .collect(Collectors.toList());

        return geminiClientService.generateChatResponse(systemPrompt, contents);
    }

    public CreateTrainerExamAIResponseDTO generateExamFromChat(TrainerExamChatRequestDTO req) {
        if (req == null || req.getHistory() == null || req.getHistory().isEmpty()) {
            throw new ApiException("Chat history is required", HttpStatus.BAD_REQUEST);
        }
        List<SystemParameter> activeSkills = systemParameterRepository.findByParamTypeAndIsActiveTrue("SKILL_TYPE");
        List<SystemParameter> activeGroupTypes = systemParameterRepository.findByParamTypeAndIsActiveTrue("GROUP_TYPE");
        List<SystemParameter> activeDifficulties = systemParameterRepository.findByParamTypeAndIsActiveTrue("DIFFICULTY");

        String skillOptionsText = activeSkills.stream().map(s -> s.getId() + "=" + s.getParamValue()).collect(Collectors.joining(", "));
        String groupOptionsText = activeGroupTypes.stream().map(g -> g.getId() + "=" + g.getParamValue()).collect(Collectors.joining(", "));
        String diffOptionsText = activeDifficulties.stream().map(d -> d.getId() + "=" + d.getParamValue()).collect(Collectors.joining(", "));

        String baseSystemPrompt = systemConfigService.getConfigValue("AI", "AI_TRAINER_EXAM_GENERATE_PROMPT", DEFAULT_GENERATE_PROMPT);
        
        String systemPrompt = baseSystemPrompt + "\n" +
                "Available IDs:\n" +
                "SKILLS (skillParamId): " + (skillOptionsText.isEmpty() ? "None available" : skillOptionsText) + "\n" +
                "GROUP TYPES (categoryId): " + (groupOptionsText.isEmpty() ? "None available" : groupOptionsText) + "\n" +
                "DIFFICULTIES (difficultyId): " + (diffOptionsText.isEmpty() ? "None available" : diffOptionsText) + "\n" +
                "IMPORTANT: Choose the most appropriate IDs for skillParamId, categoryId, and difficultyId from the Available IDs based on the question content and user request.\n" +
                "For single questions, set isQuestionGroup = false, empty passageText, and exactly 1 question in the questions array. " +
                "For single questions, the categoryId is NOT used for GROUP TYPES, it defaults to a general category ID (like 1).\n" +
                "For group questions (e.g. Reading, Listening), set isQuestionGroup = true, provide passageText, and put multiple questions in the questions array. " +
                "For group questions, categoryId MUST be one of the GROUP TYPES IDs provided above. " +
                "For reading comprehension passages, passageText must contain ONLY the article/passage itself (do NOT include 'Adapted from...' or source headers at the start of passageText). Provide an authentic sourceCitation separately (e.g. 'Adapted from National Geographic', 'Adapted from BBC Science Focus') without fabricating fake web URLs.\n" +
                "Generate the EXACT number of questions and groups as discussed in the chat.";

        List<GeminiGenerateRequest.Content> contents = req.getHistory().stream()
                .map(msg -> GeminiGenerateRequest.Content.builder()
                        .role("model".equals(msg.getRole()) ? "model" : "user")
                        .parts(List.of(GeminiGenerateRequest.Part.builder().text(msg.getText()).build()))
                        .build())
                .collect(Collectors.toList());

        // Add a final user message asking to generate the JSON
        contents.add(GeminiGenerateRequest.Content.builder()
                .role("user")
                .parts(List.of(GeminiGenerateRequest.Part.builder().text("Please generate the JSON for the exam based on our conversation above.").build()))
                .build());

        String raw = geminiClientService.generateChatResponse(systemPrompt, contents);

        raw = raw.replaceAll("(?s)^```json\\s*", "")
                .replaceAll("(?s)```\\s*$", "")
                .trim();
                
        raw = raw.replaceAll("(?m)^(\\s*)([a-zA-Z0-9_]+)\":", "$1\"$2\":");
        raw = raw.replaceAll(",\\s*([}\\]])", "$1");

        int start = raw.indexOf('{');
        int end = raw.lastIndexOf('}');
        if (start >= 0 && end >= 0 && end > start) {
            raw = raw.substring(start, end + 1);
        }

        try {
            CreateTrainerExamAIResponseDTO examResponse = LENIENT_MAPPER.readValue(raw, CreateTrainerExamAIResponseDTO.class);
            if (examResponse != null && examResponse.getBlocks() != null) {
                for (CreateTrainerExamAIResponseDTO.BlockDTO block : examResponse.getBlocks()) {
                    if (Boolean.TRUE.equals(block.getIsQuestionGroup()) && block.getPassageText() != null
                            && !block.getPassageText().isBlank()) {
                        attachCitationToPassage(
                                block.getPassageText(),
                                block.getSourceCitation(),
                                null,
                                block::setPassageText,
                                block::setSourceCitation
                        );
                    }
                }
            }
            return examResponse;
        } catch (Exception e) {
            log.error("Parse AI json failed for exam generation. Error: ", e);
            log.error("Raw JSON string: {}", raw);
            throw new ApiException("AI returned invalid JSON payload for exam. Reason: " + e.getMessage(), HttpStatus.BAD_GATEWAY);
        }
    }

    private String buildUserInput(CreateTrainerQuestionAIRequestDTO req, List<SystemParameter> activeDifficulties) {
        Long diffId = req.getDifficultyId() != null ? req.getDifficultyId() : 14L;
        String difficultyName = activeDifficulties.stream()
                .filter(d -> d.getId().equals(diffId))
                .map(SystemParameter::getParamValue)
                .findFirst()
                .orElse(diffId == 12L ? "Easy" : diffId == 13L ? "Medium" : diffId == 15L ? "Very Hard" : "Hard");

        StringBuilder sb = new StringBuilder();
        sb.append("EXAM_TARGET: Kỳ thi tốt nghiệp THPT Quốc Gia môn Tiếng Anh (Format mới 2025/2026 - Chuẩn GDPT 2018)\n")
          .append("TOPIC_SEED:\n").append(req.getTopicSeed())
          .append("\n\nSECTION_ID: ").append(req.getSectionId())
          .append("\nCATEGORY_ID(DEFAULT): ").append(req.getCategoryId())
          .append("\nDIFFICULTY_ID(DEFAULT): ").append(req.getDifficultyId())
          .append("\nDIFFICULTY_LEVEL: ").append(difficultyName);
          
        if (req.getSkillType() != null && !req.getSkillType().isBlank()) {
            sb.append("\nSKILL_TYPE: ").append(req.getSkillType());
        }
        if (req.getGroupType() != null && !req.getGroupType().isBlank()) {
            sb.append("\nGROUP_TYPE: ").append(req.getGroupType());
        }
        if (Boolean.TRUE.equals(req.getUseSearchGrounding())) {
            sb.append("\nUSE_SEARCH_GROUNDING: true");
        }
        return sb.toString();
    }

    private String buildSystemPrompt(
            CreateTrainerQuestionAIRequestDTO req,
            String mode,
            int quantity,
            List<SystemParameter> activeSkills,
            List<SystemParameter> activeDifficulties
    ) {
        // Yêu cầu JSON thuần theo schema mà FE parse
        Long difficultyId = req.getDifficultyId() != null ? req.getDifficultyId() : 14L;
        Long categoryId = req.getCategoryId() != null ? req.getCategoryId() : 1L;
        boolean useSearchGrounding = Boolean.TRUE.equals(req.getUseSearchGrounding());

        String difficultyName = activeDifficulties.stream()
                .filter(d -> d.getId().equals(difficultyId))
                .map(SystemParameter::getParamValue)
                .findFirst()
                .orElse(difficultyId == 12L ? "Easy" : difficultyId == 13L ? "Medium" : difficultyId == 15L ? "Very Hard" : "Hard");

        String skillOptionsText = activeSkills.isEmpty() ? "" : activeSkills.stream()
                .map(s -> s.getId() + "=" + s.getParamValue())
                .collect(Collectors.joining(", "));
        String difficultyOptionsText = activeDifficulties.isEmpty() ? "" : activeDifficulties.stream()
                .map(d -> d.getId() + "=" + d.getParamValue())
                .collect(Collectors.joining(", "));

        Long chosenSkillId = (req.getSkillType() != null && !req.getSkillType().isBlank())
                ? activeSkills.stream()
                        .filter(s -> s.getParamValue().equalsIgnoreCase(req.getSkillType().trim()))
                        .map(SystemParameter::getId)
                        .findFirst()
                        .orElse(null)
                : null;

        if ("SINGLE".equals(mode)) {
            String skillReq = (req.getSkillType() != null && !req.getSkillType().isBlank()) 
                    ? "The question MUST specifically test the skill: \"" + req.getSkillType() + "\" as tested in the Vietnamese THPT Quốc Gia English exam.\n" 
                    : "";
            String groundingReq = useSearchGrounding
                    ? "Use Google Search to retrieve authentic grammar references, dictionaries, or reputable facts.\n"
                    : "";
            Long skillParamIdToOutput = chosenSkillId != null ? chosenSkillId : (activeSkills.isEmpty() ? 1L : activeSkills.get(0).getId());

            return "You are an expert English test author for the Vietnamese National High School Graduation Exam (Kỳ thi tốt nghiệp THPT Quốc Gia môn Tiếng Anh - chuẩn chương trình GDPT 2018 format mới 2025/2026 của Bộ Giáo Dục và Đào Tạo).\n" +
                    "Create ONLY SINGLE multiple-choice questions matching THPT Quốc Gia standards.\n" +
                    "Each question must have exactly 4 options (A, B, C, D) with exactly 1 correct option and 3 plausible distractors.\n" +
                    "The question and its options MUST be strictly designed at difficulty level: " + difficultyName + " (theo 4 mức độ tư duy của Bộ GD&ĐT: Nhận biết [Easy], Thông hiểu [Medium], Vận dụng [Hard], Vận dụng cao [Very Hard]).\n" +
                    skillReq + groundingReq +
                    "Return PURE JSON only (no markdown).\n" +
                    "Schema:\n" +
                    "{\n" +
                    "  \"mode\": \"SINGLE\",\n" +
                    "  \"questions\": [\n" +
                    "    {\n" +
                    "      \"questionText\": \"...\",\n" +
                    "      \"explanation\": \"...\",\n" +
                    "      \"sourceCitation\": \"...\",\n" +
                    "      \"categoryId\": " + categoryId + ",\n" +
                    "      \"difficultyId\": " + difficultyId + ",\n" +
                    "      \"skillParamId\": " + skillParamIdToOutput + ",\n" +
                    "      \"options\": [\n" +
                    "        {\"optionText\": \"...\", \"isCorrect\": true},\n" +
                    "        {\"optionText\": \"...\", \"isCorrect\": false},\n" +
                    "        {\"optionText\": \"...\", \"isCorrect\": false},\n" +
                    "        {\"optionText\": \"...\", \"isCorrect\": false}\n" +
                    "      ]\n" +
                    "    }\n" +
                    "  ]\n" +
                    "}\n" +
                    "Generate exactly " + quantity + " questions. Explanations should be short and insightful. Options should be plausible distractors.\n" +
                    "For sourceCitation: provide a brief citation of the reference book or publication if applicable (e.g. 'Source: BBC Learning English') without inventing fake URLs.";
        }

        // MULTIPLE (Question Group with reading passage)
        String gType = req.getGroupType() != null ? req.getGroupType().trim() : "";
        String gTypeLower = gType.toLowerCase();
        boolean isBlankFilling = gTypeLower.contains("notice") || gTypeLower.contains("leaflet") || gTypeLower.contains("advertisement") || gTypeLower.contains("cloze");
        boolean isReordering = gTypeLower.contains("reorder") || gTypeLower.contains("arrangement");

        String groupReq;
        String skillReqMulti;

        if (isBlankFilling) {
            String textTypeLabel = gTypeLower.contains("notice")
                    ? "a formal public, school, or organizational notice/announcement (starting with a clear title like 'NOTICE / ANNOUNCEMENT', followed by concise bulleted or numbered items)"
                    : gTypeLower.contains("cloze")
                            ? "an authentic informative or narrative article for a cloze test"
                            : "an engaging promotional leaflet, flyer, or advertisement (with a catchy header, bullet points, and key details)";

            groupReq = "The passageText MUST be written as " + textTypeLabel + " according to group type \"" + gType + "\".\n" +
                    "CRUCIAL BLANK-FILLING RULES (THPT QUỐC GIA FORMAT 2025/2026):\n" +
                    "1. The passageText MUST contain EXACTLY " + quantity + " numbered blanks, numbered sequentially from (1) to (" + quantity + "), formatted as: (1) _______, (2) _______, ... up to (" + quantity + ") _______.\n" +
                    "   (Example: 'All luggage (1) _______ in the terminal will be removed immediately. Passengers wishing to change seats (2) _______ the front desk. Any assistance needed (3) _______ to staff in advance.')\n" +
                    "   DO NOT write a full text without blanks. The blanks are where key words/phrases are omitted for test-takers to fill in.\n" +
                    "2. For each blank (i) in the passageText, generate the corresponding subQuestion (from i=1 to " + quantity + "):\n" +
                    "   - questionText MUST be formatted as: \"Choose the best option to fill in blank (\" + i + \").\"\n" +
                    "   - options MUST contain 4 candidate words, phrases, or clauses (A, B, C, D) to fill into blank (i) in the passage.\n" +
                    "   - Exactly 1 option must be grammatically and semantically correct; the other 3 are plausible distractors.\n" +
                    "   - explanation should clearly explain why the correct option fits blank (i) and why other choices are grammatically/lexically wrong.\n";

            if (req.getSkillType() != null && !req.getSkillType().isBlank()) {
                skillReqMulti = "CRUCIAL SKILL RULE: Each blank in the passage and its 4 options MUST specifically test the skill: \"" + req.getSkillType() + "\" (e.g., correct grammatical form, reduced relative clause, preposition, collocations, word forms).\n" +
                        "For each subQuestion, set skillParamId = " + (chosenSkillId != null ? chosenSkillId : "the matching id") + 
                        " corresponding to '" + req.getSkillType() + "'.\n";
            } else {
                skillReqMulti = "Each blank tests its own specific grammar or vocabulary skill appropriate for THPT Quốc Gia.\n" +
                        "For every subQuestion, pick the single most relevant skillParamId from this list: [" + skillOptionsText + "].\n";
            }
        } else if (isReordering) {
            groupReq = "The passageText MUST be a jumbled text, conversation, or letter where sentences or short paragraphs are labeled [a], [b], [c], [d], [e]... for group type \"" + gType + "\".\n" +
                    "Each subQuestion asks for the correct order/arrangement of the labeled sentences (e.g. 'a - c - b - d').\n";

            if (req.getSkillType() != null && !req.getSkillType().isBlank()) {
                skillReqMulti = "Each subQuestion tests the skill: \"" + req.getSkillType() + "\".\n" +
                        "For each subQuestion, set skillParamId = " + (chosenSkillId != null ? chosenSkillId : "the matching id") + 
                        " corresponding to '" + req.getSkillType() + "'.\n";
            } else {
                skillReqMulti = "For every subQuestion, pick the single most relevant skillParamId from this list: [" + skillOptionsText + "].\n";
            }
        } else if (!gType.isBlank()) {
            groupReq = "The format and passage MUST strictly follow the structure and style of group type: \"" + gType + "\" according to the Vietnamese National High School Graduation Exam (THPT Quốc Gia) format 2025/2026.\n" +
                    "The passage provides the reading context and does NOT test an isolated skill by itself.\n";

            if (req.getSkillType() != null && !req.getSkillType().isBlank()) {
                skillReqMulti = "Each subQuestion MUST specifically test the reading comprehension skill: \"" + req.getSkillType() + "\".\n" +
                        "For each subQuestion, set skillParamId = " + (chosenSkillId != null ? chosenSkillId : "the matching id") + 
                        " corresponding to '" + req.getSkillType() + "'.\n";
            } else {
                skillReqMulti = "Each subQuestion tests its own specific reading skill (e.g. Main idea, Detail, Synonym/Vocabulary in context, Reference, Inference) appropriate for THPT Quốc Gia.\n" +
                        "For every subQuestion, pick the single most relevant skillParamId from this list: [" + skillOptionsText + "].\n";
            }
        } else {
            groupReq = "The passage MUST be an authentic reading passage suitable for the THPT Quốc Gia English exam.\n";

            if (req.getSkillType() != null && !req.getSkillType().isBlank()) {
                skillReqMulti = "Each subQuestion MUST specifically test the reading comprehension skill: \"" + req.getSkillType() + "\".\n" +
                        "For each subQuestion, set skillParamId = " + (chosenSkillId != null ? chosenSkillId : "the matching id") + 
                        " corresponding to '" + req.getSkillType() + "'.\n";
            } else {
                skillReqMulti = "Each subQuestion tests its own specific reading skill (e.g. Main idea, Detail, Synonym/Vocabulary in context, Reference, Inference) appropriate for THPT Quốc Gia.\n" +
                        "For every subQuestion, pick the single most relevant skillParamId from this list: [" + skillOptionsText + "].\n";
            }
        }

        String diffReqMulti = "The reading passage and all subQuestions MUST be strictly designed at difficulty level: " + difficultyName + 
                " (theo chuẩn THPT Quốc Gia: Nhận biết [Easy], Thông hiểu [Medium], Vận dụng [Hard], Vận dụng cao [Very Hard]).\n";

        String groundingReqMulti = useSearchGrounding
                ? "Use Google Search to find an authentic, reputable English reading passage/article (e.g. from BBC, The Guardian, National Geographic, British Council). The passage must be factual, engaging, and appropriate for high school students.\n"
                : "";

        return "You are an expert English reading comprehension test question generator for HanGo trainer (Kỳ thi tốt nghiệp THPT Quốc Gia môn Tiếng Anh - chuẩn chương trình GDPT 2018 format mới 2025/2026 của Bộ Giáo Dục và Đào Tạo).\n" +
                "Create a group question consisting of passageText + subQuestions[].\n" +
                groupReq +
                diffReqMulti +
                skillReqMulti +
                groundingReqMulti +
                (difficultyOptionsText.isEmpty() ? "" : "\nDifficulty options: [" + difficultyOptionsText + "].\n") +
                "Each subQuestion is single-answer multiple-choice with exactly 4 options (A, B, C, D) and exactly 1 correct option.\n" +
                "For every subQuestion, set difficultyId = " + difficultyId + " (" + difficultyName + ").\n" +
                "Return PURE JSON only (no markdown).\n" +
                "Schema:\n" +
                "{\n" +
                "  \"mode\": \"MULTIPLE\",\n" +
                "  \"questions\": [],\n" +
                "  \"group\": {\n" +
                "    \"passageText\": \"...\",\n" +
                "    \"explanation\": \"...\",\n" +
                "    \"sourceCitation\": \"...\",\n" +
                "    \"categoryId\": " + categoryId + ",\n" +
                "    \"difficultyId\": " + difficultyId + ",\n" +
                "    \"subQuestions\": [\n" +
                "      {\n" +
                "        \"questionText\": \"...\",\n" +
                "        \"explanation\": \"...\",\n" +
                "        \"skillParamId\": <id from the skill list above>,\n" +
                "        \"difficultyId\": " + difficultyId + ",\n" +
                "        \"options\": [\n" +
                "          {\"optionText\": \"...\", \"isCorrect\": true},\n" +
                "          {\"optionText\": \"...\", \"isCorrect\": false},\n" +
                "          {\"optionText\": \"...\", \"isCorrect\": false},\n" +
                "          {\"optionText\": \"...\", \"isCorrect\": false}\n" +
                "        ]\n" +
                "      }\n" +
                "    ]\n" +
                "  }\n" +
                "}\n" +
                "Generate at least 2 subQuestions. Here quantity=" + quantity + ". Generate exactly " + quantity + " subQuestions. Explanations should be short and insightful. Options should be plausible distractors.\n" +
                "passageText must contain ONLY the article/passage itself (do NOT write 'Adapted from...' or source headers at the start of passageText). Provide the citation in the sourceCitation field instead.\n" +
                "For sourceCitation: provide an authentic citation of the work, book, magazine, or article adapted for this passage (e.g. 'Adapted from The Psychology of Money', 'Adapted from National Geographic'). Do NOT invent fake web URLs (no http/https links).";
    }
}
