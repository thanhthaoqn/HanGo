package com.hango.hango_backend.service;

import com.fasterxml.jackson.databind.ObjectMapper;
import com.hango.hango_backend.config.GeminiProperties;
import com.hango.hango_backend.dto.CreateTrainerQuestionAIRequestDTO;
import com.hango.hango_backend.dto.CreateTrainerQuestionAIResponseDTO;
import com.hango.hango_backend.dto.CreateTrainerExamAIResponseDTO;
import com.hango.hango_backend.dto.TrainerExamChatRequestDTO;
import com.hango.hango_backend.dto.GeminiGenerateRequest;
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

    private final GeminiClientService geminiClientService;
    private final ObjectMapper objectMapper;
    private final SystemParameterRepository systemParameterRepository;

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
        List<SystemParameter> activeSkills = isMultipleBranch
                ? systemParameterRepository.findByParamTypeAndIsActiveTrue("SKILL_TYPE")
                : List.of();
        List<SystemParameter> activeDifficulties = isMultipleBranch
                ? systemParameterRepository.findByParamTypeAndIsActiveTrue("DIFFICULTY")
                : List.of();

        String systemPrompt = buildSystemPrompt(req, mode, quantity, activeSkills, activeDifficulties);

        String raw = geminiClientService.generateChatResponse(
                systemPrompt,
                List.of(
                        GeminiGenerateRequest.Content.builder()
                                .role("user")
                                .parts(List.of(GeminiGenerateRequest.Part.builder().text(buildUserInput(req)).build()))
                                .build()
                )
        );

        // Gemini đôi khi bọc codeblock ```json ... ```
        raw = raw.replaceAll("(?s)^```json\\s*", "")
                .replaceAll("(?s)```\\s*$", "")
                .trim();
                
        int start = raw.indexOf('{');
        int end = raw.lastIndexOf('}');
        if (start >= 0 && end >= 0 && end > start) {
            raw = raw.substring(start, end + 1);
        }

        CreateTrainerQuestionAIResponseDTO response;
        try {
            response = objectMapper.readValue(raw, CreateTrainerQuestionAIResponseDTO.class);
        } catch (Exception e) {
            log.warn("Parse AI json failed. raw={}", raw);
            throw new ApiException("AI returned invalid JSON payload", HttpStatus.BAD_GATEWAY);
        }

        if (isMultipleBranch && response.getGroup() != null) {
            fillSubQuestionSkillAndDifficulty(response.getGroup(), activeSkills, activeDifficulties);
        }

        return response;
    }

    /**
     * The AI is asked to pick a skillParamId/difficultyId per subQuestion (see buildSystemPrompt),
     * but it may omit them or hallucinate an id outside the valid set. Fall back to the first
     * valid option so sub-questions never reach the FE with a blank skill/difficulty.
     */
    private void fillSubQuestionSkillAndDifficulty(
            CreateTrainerQuestionAIResponseDTO.MultipleGroupDTO group,
            List<SystemParameter> activeSkills,
            List<SystemParameter> activeDifficulties
    ) {
        if (group.getSubQuestions() == null) return;

        Set<Long> validSkillIds = activeSkills.stream().map(SystemParameter::getId).collect(Collectors.toSet());
        Set<Long> validDifficultyIds = activeDifficulties.stream().map(SystemParameter::getId).collect(Collectors.toSet());

        Long fallbackSkillId = activeSkills.isEmpty() ? null : activeSkills.get(0).getId();
        Long fallbackDifficultyId = group.getDifficultyId() != null && validDifficultyIds.contains(group.getDifficultyId())
                ? group.getDifficultyId()
                : (activeDifficulties.isEmpty() ? null : activeDifficulties.get(0).getId());

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

        String systemPrompt = "You are a helpful AI assistant that helps trainers create exams for the HanGo English learning platform.\n" +
                "Your goal is to gather all necessary information to generate an exam.\n" +
                "You need to ask the user for:\n" +
                "- Exam title\n" +
                "- Description\n" +
                "- Duration in minutes\n" +
                "- Passing score percentage\n" +
                "- Expected total question count\n" +
                "- The breakdown of questions (single vs group, skills, difficulty, number of questions for each).\n" +
                "Do NOT ask for everything at once, keep the conversation natural.\n" +
                "When you have enough information, explicitly summarize the gathered details and ask the user if they want to 'Generate Exam'.";

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

        String systemPrompt = "You are an expert English test question generator for HanGo trainer.\n" +
                "Based on the chat history provided, generate a COMPLETE EXAM in JSON format.\n" +
                "Return PURE JSON only (no markdown). Do NOT use unescaped control characters or literal newlines in JSON strings (use \\\\n instead).\n" +
                "Schema:\n" +
                "{\n" +
                "  \"title\": \"Exam Title\",\n" +
                "  \"description\": \"Exam Description\",\n" +
                "  \"durationMinutes\": 60,\n" +
                "  \"passingScore\": 50.0,\n" +
                "  \"expectedQuestionCount\": 20,\n" +
                "  \"blocks\": [\n" +
                "    {\n" +
                "      \"isQuestionGroup\": false,\n" +
                "      \"passageText\": \"\",\n" +
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
                "For group questions, set isQuestionGroup = true, provide passageText, and put multiple questions in the questions array.\n" +
                "For single questions, set isQuestionGroup = false, empty passageText, and exactly 1 question in the questions array.\n" +
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
                
        int start = raw.indexOf('{');
        int end = raw.lastIndexOf('}');
        if (start >= 0 && end >= 0 && end > start) {
            raw = raw.substring(start, end + 1);
        }

        try {
            return objectMapper.readValue(raw, CreateTrainerExamAIResponseDTO.class);
        } catch (Exception e) {
            log.error("Parse AI json failed for exam generation. Error: ", e);
            log.error("Raw JSON string: {}", raw);
            throw new ApiException("AI returned invalid JSON payload for exam. Reason: " + e.getMessage(), HttpStatus.BAD_GATEWAY);
        }
    }

    private String buildUserInput(CreateTrainerQuestionAIRequestDTO req) {
        StringBuilder sb = new StringBuilder();
        sb.append("TOPIC_SEED:\n").append(req.getTopicSeed())
          .append("\n\nSECTION_ID: ").append(req.getSectionId())
          .append("\nCATEGORY_ID(DEFAULT): ").append(req.getCategoryId())
          .append("\nDIFFICULTY_ID(DEFAULT): ").append(req.getDifficultyId());
          
        if (req.getSkillType() != null && !req.getSkillType().isBlank()) {
            sb.append("\nSKILL_TYPE: ").append(req.getSkillType());
        }
        if (req.getGroupType() != null && !req.getGroupType().isBlank()) {
            sb.append("\nGROUP_TYPE: ").append(req.getGroupType());
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

        if ("SINGLE".equals(mode)) {
            String skillReq = (req.getSkillType() != null && !req.getSkillType().isBlank()) 
                    ? " The question MUST specifically test the skill: " + req.getSkillType() + "." 
                    : "";
            return "You are an expert English test question generator for HanGo trainer.\n" +
                    "Create ONLY SINGLE multiple-choice questions. 4 options per question. Exactly 1 correct option." + skillReq + "\n" +
                    "Return PURE JSON only (no markdown).\n" +
                    "Schema:\n" +
                    "{\n" +
                    "  \"mode\": \"SINGLE\",\n" +
                    "  \"questions\": [\n" +
                    "    {\n" +
                    "      \"questionText\": \"...\",\n" +
                    "      \"explanation\": \"...\",\n" +
                    "      \"categoryId\": " + categoryId + ",\n" +
                    "      \"difficultyId\": " + difficultyId + ",\n" +
                    "      \"options\": [\n" +
                    "        {\"optionText\": \"...\", \"isCorrect\": true},\n" +
                    "        {\"optionText\": \"...\", \"isCorrect\": false},\n" +
                    "        {\"optionText\": \"...\", \"isCorrect\": false},\n" +
                    "        {\"optionText\": \"...\", \"isCorrect\": false}\n" +
                    "      ]\n" +
                    "    }\n" +
                    "  ]\n" +
                    "}\n" +
                    "Generate exactly " + quantity + " questions. Explanations should be short. Options should be plausible distractors.";
        }

        // MULTIPLE
        String skillReqMulti = (req.getSkillType() != null && !req.getSkillType().isBlank())
                ? " The questions MUST specifically test the skill: " + req.getSkillType() + "."
                : "";
        String groupReq = (req.getGroupType() != null && !req.getGroupType().isBlank())
                ? " The format and passage MUST follow the structure of group type: " + req.getGroupType() + "."
                : "";

        String skillOptionsText = activeSkills.isEmpty() ? "" : activeSkills.stream()
                .map(s -> s.getId() + "=" + s.getParamValue())
                .collect(Collectors.joining(", "));
        String difficultyOptionsText = activeDifficulties.isEmpty() ? "" : activeDifficulties.stream()
                .map(d -> d.getId() + "=" + d.getParamValue())
                .collect(Collectors.joining(", "));
        String perSubQuestionSkillReq = skillOptionsText.isEmpty() ? "" :
                "\nEach subQuestion tests its own specific skill (they do NOT need to share the same skill). " +
                "For every subQuestion, pick the single most relevant skillParamId from this list: [" + skillOptionsText + "].";
        String perSubQuestionDifficultyReq = difficultyOptionsText.isEmpty() ? "" :
                "\nFor every subQuestion, pick the most appropriate difficultyId from this list: [" + difficultyOptionsText + "].";

        return "You are an expert English reading comprehension test question generator for HanGo trainer.\n" +
                "Create a group question. passageText + subQuestions[]." + groupReq + "\n" +
                "Each subQuestion is single-answer multiple-choice with 4 options and exactly 1 correct option." + skillReqMulti +
                perSubQuestionSkillReq + perSubQuestionDifficultyReq + "\n" +
                "Return PURE JSON only (no markdown).\n" +
                "Schema:\n" +
                "{\n" +
                "  \"mode\": \"MULTIPLE\",\n" +
                "  \"questions\": [],\n" +
                "  \"group\": {\n" +
                "    \"passageText\": \"...\",\n" +
                "    \"explanation\": \"...\",\n" +
                "    \"categoryId\": " + categoryId + ",\n" +
                "    \"difficultyId\": " + difficultyId + ",\n" +
                "    \"subQuestions\": [\n" +
                "      {\n" +
                "        \"questionText\": \"...\",\n" +
                "        \"explanation\": \"...\",\n" +
                "        \"skillParamId\": <id from the skill list above, or null if none given>,\n" +
                "        \"difficultyId\": <id from the difficulty list above, or null if none given>,\n" +
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
                "Generate at least 2 subQuestions. Here quantity=" + quantity + ". Generate exactly " + quantity + " subQuestions. Explanations should be short. Options should be plausible distractors.";
    }
}
