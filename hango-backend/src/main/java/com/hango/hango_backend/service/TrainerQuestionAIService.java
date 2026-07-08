package com.hango.hango_backend.service;

import com.fasterxml.jackson.databind.ObjectMapper;
import com.hango.hango_backend.config.GeminiProperties;
import com.hango.hango_backend.dto.CreateTrainerQuestionAIRequestDTO;
import com.hango.hango_backend.dto.CreateTrainerQuestionAIResponseDTO;
import com.hango.hango_backend.dto.GeminiGenerateRequest;
import com.hango.hango_backend.exeption.ApiException;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.http.HttpStatus;
import org.springframework.stereotype.Service;

import java.util.List;

@Service
@RequiredArgsConstructor
@Slf4j
public class TrainerQuestionAIService {

    private final GeminiClientService geminiClientService;
    private final ObjectMapper objectMapper;

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

        String systemPrompt = buildSystemPrompt(mode, quantity);

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

        try {
            return objectMapper.readValue(raw, CreateTrainerQuestionAIResponseDTO.class);
        } catch (Exception e) {
            log.warn("Parse AI json failed. raw={}", raw);
            throw new ApiException("AI returned invalid JSON payload", HttpStatus.BAD_GATEWAY);
        }
    }

    private String buildUserInput(CreateTrainerQuestionAIRequestDTO req) {
        return "TOPIC_SEED:\n" + req.getTopicSeed() +
                "\n\nSECTION_ID: " + req.getSectionId() +
                "\nCATEGORY_ID(DEFAULT): " + req.getCategoryId() +
                "\nDIFFICULTY_ID(DEFAULT): " + req.getDifficultyId();
    }

    private String buildSystemPrompt(String mode, int quantity) {
        // Yêu cầu JSON thuần theo schema mà FE parse
        if ("SINGLE".equals(mode)) {
            return "You are an expert English test question generator for HanGo trainer.\n" +
                    "Create ONLY SINGLE multiple-choice questions. 4 options per question. Exactly 1 correct option.\n" +
                    "Return PURE JSON only (no markdown).\n" +
                    "Schema:\n" +
                    "{\n" +
                    "  \"mode\": \"SINGLE\",\n" +
                    "  \"questions\": [\n" +
                    "    {\n" +
                    "      \"questionText\": \"...\",\n" +
                    "      \"explanation\": \"...\",\n" +
                    "      \"categoryId\": 1,\n" +
                    "      \"difficultyId\": 14,\n" +
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
        return "You are an expert English reading comprehension test question generator for HanGo trainer.\n" +
                "Create a group question. passageText + subQuestions[].\n" +
                "Each subQuestion is single-answer multiple-choice with 4 options and exactly 1 correct option.\n" +
                "Return PURE JSON only (no markdown).\n" +
                "Schema:\n" +
                "{\n" +
                "  \"mode\": \"MULTIPLE\",\n" +
                "  \"questions\": [],\n" +
                "  \"group\": {\n" +
                "    \"passageText\": \"...\",\n" +
                "    \"explanation\": \"...\",\n" +
                "    \"categoryId\": 1,\n" +
                "    \"difficultyId\": 14,\n" +
                "    \"subQuestions\": [\n" +
                "      {\n" +
                "        \"questionText\": \"...\",\n" +
                "        \"explanation\": \"...\",\n" +
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
                "Generate at least 2 subQuestions. Here quantity=" + quantity + ". Generate exactly " + quantity + " subQuestions. Explanations should be short.";
    }
}

