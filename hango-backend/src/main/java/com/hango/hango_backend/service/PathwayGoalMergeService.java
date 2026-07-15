package com.hango.hango_backend.service;

import com.fasterxml.jackson.core.JsonProcessingException;
import com.fasterxml.jackson.databind.ObjectMapper;
import com.hango.hango_backend.dto.MergePreviewDTO;
import com.hango.hango_backend.dto.PathwayNodeDTO;
import com.hango.hango_backend.entity.Course;
import com.hango.hango_backend.entity.LearningPathway;
import com.hango.hango_backend.entity.LearningPathwayGoal;
import com.hango.hango_backend.entity.PathwayNode;
import com.hango.hango_backend.repository.CourseRepository;
import com.hango.hango_backend.repository.LearningPathwayGoalRepository;
import com.hango.hango_backend.repository.LearningPathwayRepository;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.util.*;
import java.util.stream.Collectors;

@Service
@RequiredArgsConstructor
@Slf4j
public class PathwayGoalMergeService {

    private final CourseRepository courseRepository;
    private final LearningPathwayRepository pathwayRepository;
    private final LearningPathwayGoalRepository goalRepository;
    private final ObjectMapper objectMapper;

    /**
     * Previews a merged pathway based on a list of courses that represent multiple goals.
     */
    public MergePreviewDTO mergePreview(List<Long> courseIds) {
        List<Course> courses = courseRepository.findAllById(courseIds);
        
        int originalCount = courses.size();
        int removedDuplicates = 0;
        int sharedSteps = 0;
        
        // 1. Exact course deduplication
        Map<Long, Course> uniqueCoursesMap = new LinkedHashMap<>();
        for (Course c : courses) {
            if (!uniqueCoursesMap.containsKey(c.getId())) {
                uniqueCoursesMap.put(c.getId(), c);
            } else {
                removedDuplicates++;
            }
        }
        
        // 2. Skill type & difficulty deduplication
        List<Course> uniqueCourses = new ArrayList<>(uniqueCoursesMap.values());
        Map<String, Course> skillDiffMap = new LinkedHashMap<>();
        
        List<Course> finalCoursesToKeep = new ArrayList<>();
        
        for (Course c : uniqueCourses) {
            String skill = c.getCategory() != null ? c.getCategory().getParamValue() : "NONE";
            String diff = c.getDifficulty() != null ? c.getDifficulty().getParamValue() : "NONE";
            String key = skill + "_" + diff;
            
            if (skillDiffMap.containsKey(key)) {
                removedDuplicates++;
                sharedSteps++; // It's shared concept
                // Keep the one with highest rating or just keep existing for simplicity in v1
            } else {
                skillDiffMap.put(key, c);
                finalCoursesToKeep.add(c);
            }
        }
        
        // Convert to NodeDTOs
        List<PathwayNodeDTO> mergedNodes = new ArrayList<>();
        for (int i = 0; i < finalCoursesToKeep.size(); i++) {
            Course c = finalCoursesToKeep.get(i);
            
            List<String> goalLabels = new ArrayList<>();
            goalLabels.add("Goal_" + (i % 2 == 0 ? "A" : "B")); // Mock goal assignment
            
            String mergeReason = null;
            if (i > 0 && i % 3 == 0) {
                goalLabels.add("Goal_A");
                goalLabels.add("Goal_B");
                mergeReason = "Shared prerequisite across multiple goals.";
                sharedSteps++;
            }
            
            mergedNodes.add(PathwayNodeDTO.builder()
                    .step(i + 1)
                    .courseId(c.getId())
                    .courseTitle(c.getTitle())
                    .status(i == 0 ? "IN_PROGRESS" : "LOCKED")
                    .progressPercent(0)
                    .skillType(c.getCategory() != null ? c.getCategory().getParamValue() : null)
                    .sourceGoalLabels(goalLabels)
                    .mergeReason(mergeReason)
                    .tags(c.getCategory() != null ? List.of("#" + c.getCategory().getParamValue()) : Collections.emptyList())
                    .nodeType(mergeReason != null ? "MERGED" : "NORMAL")
                    .build());
        }

        return MergePreviewDTO.builder()
                .removedDuplicates(removedDuplicates)
                .sharedSteps(sharedSteps)
                .estimatedTimeSavedHours(removedDuplicates * 2) // Assume 2 hours per removed course
                .mergedNodes(mergedNodes)
                .build();
    }

    @Transactional
    public void mergeConfirm(Long pathwayId, Long studentId, MergePreviewDTO previewDTO) {
        LearningPathway pathway = pathwayRepository.findById(pathwayId)
                .orElseThrow(() -> new IllegalArgumentException("Pathway not found"));

        if (!pathway.getStudent().getId().equals(studentId)) {
            throw new IllegalArgumentException("Access denied");
        }

        // Clear existing nodes
        pathway.getNodes().clear();
        
        // Rebuild from preview
        for (PathwayNodeDTO nodeDto : previewDTO.getMergedNodes()) {
            Course course = courseRepository.findById(nodeDto.getCourseId())
                    .orElseThrow(() -> new IllegalArgumentException("Course not found: " + nodeDto.getCourseId()));
            
            String goalLabelsJson = null;
            try {
                if (nodeDto.getSourceGoalLabels() != null) {
                    goalLabelsJson = objectMapper.writeValueAsString(nodeDto.getSourceGoalLabels());
                }
            } catch (JsonProcessingException e) {
                log.warn("Failed to serialize goal labels", e);
            }
            
            PathwayNode node = PathwayNode.builder()
                    .learningPathway(pathway)
                    .stepOrder(nodeDto.getStep())
                    .course(course)
                    .status(nodeDto.getStatus())
                    .progressPercent(nodeDto.getProgressPercent())
                    .reasonWhy(nodeDto.getReasonWhy())
                    .nodeType(nodeDto.getNodeType())
                    .mergeReason(nodeDto.getMergeReason())
                    .sourceGoalLabels(goalLabelsJson)
                    .build();
                    
            pathway.addNode(node);
        }
        
        pathwayRepository.save(pathway);
        
        // We might also update LearningPathwayGoals here based on the final goals
    }
}
