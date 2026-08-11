package com.hango.hango_backend.util;

import com.hango.hango_backend.dto.CreateGroupQuestionRequestDTO;
import com.hango.hango_backend.dto.CreateOptionDTO;
import com.hango.hango_backend.dto.CreateSubQuestionDTO;

import java.util.ArrayList;
import java.util.LinkedHashMap;
import java.util.List;
import java.util.Map;
import java.util.Objects;

/**
 * Computes a positional diff between the exam questions stored before a save and the
 * payload being saved. Questions/options don't keep a stable id across saves (
 * TrainerDashboardServiceImpl#saveExamQuestions deletes and recreates them every time),
 * so matching is done by index (block/question/option position) rather than by id.
 * A side effect: reordering questions without changing their content will show up as
 * changes here, since there's no id to recognize "same question, new position".
 */
public final class ExamQuestionDiffUtil {

    private ExamQuestionDiffUtil() {
    }

    public static Map<String, Object> diff(List<CreateGroupQuestionRequestDTO> oldBlocksIn,
            List<CreateGroupQuestionRequestDTO> newBlocksIn) {
        List<CreateGroupQuestionRequestDTO> oldBlocks = oldBlocksIn != null ? oldBlocksIn : List.of();
        List<CreateGroupQuestionRequestDTO> newBlocks = newBlocksIn != null ? newBlocksIn : List.of();

        List<Map<String, Object>> changedQuestions = new ArrayList<>();
        List<Map<String, Object>> addedQuestions = new ArrayList<>();
        List<Map<String, Object>> removedQuestions = new ArrayList<>();

        int maxBlocks = Math.max(oldBlocks.size(), newBlocks.size());
        for (int b = 0; b < maxBlocks; b++) {
            CreateGroupQuestionRequestDTO oldBlock = b < oldBlocks.size() ? oldBlocks.get(b) : null;
            CreateGroupQuestionRequestDTO newBlock = b < newBlocks.size() ? newBlocks.get(b) : null;

            List<CreateSubQuestionDTO> oldQs = oldBlock != null && oldBlock.getSubQuestions() != null
                    ? oldBlock.getSubQuestions() : List.of();
            List<CreateSubQuestionDTO> newQs = newBlock != null && newBlock.getSubQuestions() != null
                    ? newBlock.getSubQuestions() : List.of();

            int maxQs = Math.max(oldQs.size(), newQs.size());
            for (int q = 0; q < maxQs; q++) {
                CreateSubQuestionDTO oldQ = q < oldQs.size() ? oldQs.get(q) : null;
                CreateSubQuestionDTO newQ = q < newQs.size() ? newQs.get(q) : null;

                if (oldQ == null) {
                    addedQuestions.add(location(b, q, newQ.getQuestionText()));
                    continue;
                }
                if (newQ == null) {
                    removedQuestions.add(location(b, q, oldQ.getQuestionText()));
                    continue;
                }

                List<Map<String, Object>> fieldChanges = new ArrayList<>();
                compareField(fieldChanges, "questionText", oldQ.getQuestionText(), newQ.getQuestionText());
                compareField(fieldChanges, "explanation", oldQ.getExplanation(), newQ.getExplanation());
                compareField(fieldChanges, "skillParamId", oldQ.getSkillParamId(), newQ.getSkillParamId());
                compareField(fieldChanges, "difficultyId", oldQ.getDifficultyId(), newQ.getDifficultyId());

                List<Map<String, Object>> optionChanges = diffOptions(oldQ.getOptions(), newQ.getOptions());

                if (!fieldChanges.isEmpty() || !optionChanges.isEmpty()) {
                    Map<String, Object> entry = location(b, q, newQ.getQuestionText());
                    entry.put("changedFields", fieldChanges);
                    entry.put("changedOptions", optionChanges);
                    changedQuestions.add(entry);
                }
            }
        }

        Map<String, Object> result = new LinkedHashMap<>();
        result.put("changedQuestions", changedQuestions);
        result.put("addedQuestions", addedQuestions);
        result.put("removedQuestions", removedQuestions);
        return result;
    }

    private static List<Map<String, Object>> diffOptions(List<CreateOptionDTO> oldOptsIn,
            List<CreateOptionDTO> newOptsIn) {
        List<CreateOptionDTO> oldOpts = oldOptsIn != null ? oldOptsIn : List.of();
        List<CreateOptionDTO> newOpts = newOptsIn != null ? newOptsIn : List.of();
        List<Map<String, Object>> optionChanges = new ArrayList<>();

        int maxOpts = Math.max(oldOpts.size(), newOpts.size());
        for (int o = 0; o < maxOpts; o++) {
            CreateOptionDTO oldOpt = o < oldOpts.size() ? oldOpts.get(o) : null;
            CreateOptionDTO newOpt = o < newOpts.size() ? newOpts.get(o) : null;

            if (oldOpt == null) {
                optionChanges.add(optionEntry(o, "added", null, newOpt.getOptionText()));
                continue;
            }
            if (newOpt == null) {
                optionChanges.add(optionEntry(o, "removed", oldOpt.getOptionText(), null));
                continue;
            }
            if (!Objects.equals(oldOpt.getOptionText(), newOpt.getOptionText())) {
                optionChanges.add(optionEntry(o, "optionText", oldOpt.getOptionText(), newOpt.getOptionText()));
            }
            if (!Objects.equals(oldOpt.getIsCorrect(), newOpt.getIsCorrect())) {
                optionChanges.add(optionEntry(o, "isCorrect", oldOpt.getIsCorrect(), newOpt.getIsCorrect()));
            }
        }
        return optionChanges;
    }

    private static Map<String, Object> location(int blockIndex, int questionIndex, String questionText) {
        Map<String, Object> m = new LinkedHashMap<>();
        m.put("blockIndex", blockIndex);
        m.put("questionIndex", questionIndex);
        m.put("questionText", questionText);
        return m;
    }

    private static Map<String, Object> optionEntry(int optionIndex, String field, Object before, Object after) {
        Map<String, Object> m = new LinkedHashMap<>();
        m.put("optionIndex", optionIndex);
        m.put("field", field);
        m.put("before", before);
        m.put("after", after);
        return m;
    }

    private static void compareField(List<Map<String, Object>> out, String field, Object before, Object after) {
        if (!Objects.equals(before, after)) {
            Map<String, Object> m = new LinkedHashMap<>();
            m.put("field", field);
            m.put("before", before);
            m.put("after", after);
            out.add(m);
        }
    }
}
