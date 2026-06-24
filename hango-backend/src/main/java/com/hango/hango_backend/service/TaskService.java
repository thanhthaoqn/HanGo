package com.hango.hango_backend.service;

import com.hango.hango_backend.dto.TaskDTO;
import com.hango.hango_backend.dto.TaskRequestDTO;
import com.hango.hango_backend.dto.TaskStatusUpdateRequest;
import com.hango.hango_backend.entity.Role;
import com.hango.hango_backend.entity.Task;
import com.hango.hango_backend.entity.TaskStatus;
import com.hango.hango_backend.entity.User;
import com.hango.hango_backend.repository.TaskRepository;
import com.hango.hango_backend.repository.UserRepository;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.data.domain.Page;
import org.springframework.data.domain.Pageable;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.time.LocalDateTime;
import java.util.List;
import java.util.stream.Collectors;

@Service
public class TaskService {

    @Autowired
    private TaskRepository taskRepository;

    @Autowired
    private UserRepository userRepository;

    public Page<TaskDTO> getTasks(Long leadId, Long creatorId,
            LocalDateTime fromDate, LocalDateTime toDate,
            String search, Pageable pageable) {
        Page<Task> tasks = taskRepository.findTasksWithFilters(leadId, creatorId, fromDate, toDate, search, pageable);
        return tasks.map(this::mapToDTO);
    }

    @Transactional
    public TaskDTO createTask(TaskRequestDTO request, User currentUser) {
        User reviewer = userRepository.findById(request.getReviewerId())
                .orElseThrow(() -> new RuntimeException("Reviewer not found: " + request.getReviewerId()));

        User assignee = userRepository.findById(request.getAssigneeId())
                .orElseThrow(() -> new RuntimeException("Assignee not found: " + request.getAssigneeId()));

        boolean isTrainer = assignee.getRoles().stream()
                .map(Role::getRoleName)
                .anyMatch(role -> role.equals("TRAINER") || role.equals("ROLE_TRAINER"));

        if (!isTrainer) {
            throw new RuntimeException("Assignee must be a Trainer. Invalid user ID: " + request.getAssigneeId());
        }

        Task task = Task.builder()
                .title(request.getTitle())
                .description(request.getDescription())
                .type(request.getType())
                .lead(currentUser)
                .dueDate(request.getDueDate())
                .assignee(assignee)
                .reviewer(reviewer)
                .status(TaskStatus.ASSIGNED)
                .build();

        Task savedTask = taskRepository.save(task);

        return mapToDTO(savedTask);
    }

    @Transactional
    public TaskDTO updateTaskStatus(Long taskId, TaskStatusUpdateRequest request, User currentUser) {
        Task task = taskRepository.findById(taskId)
                .orElseThrow(() -> new RuntimeException("Task not found"));

        Long targetCreatorId = request.getCreatorId() != null ? request.getCreatorId() : currentUser.getId();

        if (!task.getAssignee().getId().equals(targetCreatorId) && !task.getReviewer().getId().equals(currentUser.getId())) {
            throw new RuntimeException("Assignee task not found or you don't have permission");
        }

        task.setStatus(TaskStatus.valueOf(request.getStatus()));

        if (request.getStatus().equals("SUBMITTED")) {
            task.setSubmittedAt(LocalDateTime.now());
            if (request.getSubmissionNotes() != null) {
                task.setSubmissionNotes(request.getSubmissionNotes());
            }
        } else if (request.getStatus().equals("APPROVED") || request.getStatus().equals("REJECTED")) {
            task.setReviewedAt(LocalDateTime.now());
            if (request.getReviewComment() != null) {
                task.setReviewComment(request.getReviewComment());
            }
        }

        taskRepository.save(task);

        return mapToDTO(task);
    }

    @Transactional
    public TaskDTO updateTask(Long taskId, TaskRequestDTO request, User currentUser) {
        Task task = taskRepository.findById(taskId)
                .orElseThrow(() -> new RuntimeException("Task not found"));

        if (!task.getLead().getId().equals(currentUser.getId())) {
            throw new RuntimeException("Only the lead who created the task can update it");
        }

        User assignee = userRepository.findById(request.getAssigneeId())
                .orElseThrow(() -> new RuntimeException("Assignee not found: " + request.getAssigneeId()));
        
        User reviewer = userRepository.findById(request.getReviewerId())
                .orElseThrow(() -> new RuntimeException("Reviewer not found: " + request.getReviewerId()));

        task.setTitle(request.getTitle());
        task.setDescription(request.getDescription());
        task.setType(request.getType());
        task.setDueDate(request.getDueDate());
        task.setAssignee(assignee);
        task.setReviewer(reviewer);
        
        Task savedTask = taskRepository.save(task);

        return mapToDTO(savedTask);
    }

    @Transactional
    public void deleteTask(Long taskId) {
        Task task = taskRepository.findById(taskId)
                .orElseThrow(() -> new RuntimeException("Task not found"));
        taskRepository.delete(task);
    }

    private TaskDTO mapToDTO(Task task) {
        String creatorName = "Unknown";
        Long creatorId = null;
        if (task.getAssignee() != null) {
            try {
                creatorId = task.getAssignee().getId();
                creatorName = task.getAssignee().getFullName();
            } catch (Exception e) {}
        }
        
        String reviewerName = "Unknown";
        Long reviewerId = null;
        if (task.getReviewer() != null) {
            try {
                reviewerId = task.getReviewer().getId();
                reviewerName = task.getReviewer().getFullName();
            } catch (Exception e) {}
        }

        TaskDTO.CreatorTaskDTO assigneeDTO = TaskDTO.CreatorTaskDTO.builder()
                .creatorTaskId(task.getId())
                .creatorId(creatorId)
                .creatorName(creatorName)
                .status(task.getStatus() != null ? task.getStatus().name() : "ASSIGNED")
                .reviewerId(reviewerId)
                .reviewerName(reviewerName)
                .reviewComment(task.getReviewComment())
                .reviewedAt(task.getReviewedAt())
                .submissionNotes(task.getSubmissionNotes())
                .submittedAt(task.getSubmittedAt())
                .build();

        List<TaskDTO.CreatorTaskDTO> assigneeDTOs = List.of(assigneeDTO);

        String leadName = "Unknown";
        Long leadId = null;
        if (task.getLead() != null) {
            try {
                leadId = task.getLead().getId();
                leadName = task.getLead().getFullName();
            } catch (Exception e) {
            }
        }

        return TaskDTO.builder()
                .id(task.getId())
                .leadId(leadId)
                .leadName(leadName)
                .title(task.getTitle())
                .description(task.getDescription())
                .type(task.getType())
                .dueDate(task.getDueDate())
                .createdAt(task.getCreatedAt())
                .assignees(assigneeDTOs)
                .build();
    }
}
