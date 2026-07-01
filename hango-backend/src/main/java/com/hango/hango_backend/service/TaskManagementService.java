package com.hango.hango_backend.service;

import com.hango.hango_backend.dto.TaskManagementDto;
import com.hango.hango_backend.entity.CreatorTask;
import com.hango.hango_backend.entity.TaskActivity;
import com.hango.hango_backend.repository.CreatorTaskRepository;
import com.hango.hango_backend.repository.TaskActivityRepository;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.data.domain.Page;
import org.springframework.data.domain.PageRequest;
import org.springframework.data.domain.Pageable;
import org.springframework.stereotype.Service;

import java.time.LocalDateTime;
import java.util.List;
import java.util.stream.Collectors;

import java.time.LocalDateTime;
import java.util.List;
import java.util.stream.Collectors;
import java.util.Optional;

import com.hango.hango_backend.dto.CreateTaskRequest;
import com.hango.hango_backend.dto.TaskDetailDto;
import com.hango.hango_backend.dto.UpdateTaskRequest;
import com.hango.hango_backend.dto.TrainerDto;
import com.hango.hango_backend.dto.TaskActivityDto;
import com.hango.hango_backend.entity.Task;
import com.hango.hango_backend.entity.User;
import com.hango.hango_backend.repository.TaskRepository;
import com.hango.hango_backend.repository.UserRepository;

import org.springframework.transaction.annotation.Transactional;

@Service
@Transactional
public class TaskManagementService {

    @Autowired
    private CreatorTaskRepository creatorTaskRepository;

    @Autowired
    private TaskRepository taskRepository;

    @Autowired
    private UserRepository userRepository;

    @Autowired
    private TaskActivityRepository taskActivityRepository;

    private void logActivity(Long taskId, Long userId, String newStatus, String note) {
        TaskActivity activity = TaskActivity.builder()
                .taskId(taskId)
                .userId(userId)
                .newStatus(newStatus)
                .note(note)
                .build();
        taskActivityRepository.save(activity);
    }

    private void checkAutoReject(CreatorTask ct) {
        if ("ASSIGNED".equals(ct.getStatus()) && ct.getTask().getCreatedAt() != null) {
            if (ct.getTask().getCreatedAt().plusHours(8).isBefore(LocalDateTime.now())) {
                ct.setStatus("REJECTED");
                creatorTaskRepository.save(ct);
                // System auto-reject, userId can be null or a system ID, here we use the creator's ID for simplicity or leave it out
                logActivity(ct.getTask().getId(), ct.getCreator().getId(), "REJECTED", "System: Auto-rejected because it was not accepted within 8 hours");
            }
        }
    }
    public Page<TaskManagementDto> getTasksForLead(
            Long leadId,
            LocalDateTime fromDate,
            LocalDateTime toDate,
            String type,
            String search,
            int page,
            int size
    ) {
        Pageable pageable = PageRequest.of(page, size);
        Page<CreatorTask> creatorTasks = creatorTaskRepository.findTasksForLead(leadId, fromDate, toDate, type, search, pageable);

        return creatorTasks.map(this::mapToDto);
    }

    private TaskManagementDto mapToDto(CreatorTask creatorTask) {
        return TaskManagementDto.builder()
                .id(creatorTask.getTask().getId())
                .taskContent(creatorTask.getTask().getTitle())
                .assigneeName(creatorTask.getCreator() != null ? creatorTask.getCreator().getFullName() : null)
                .reviewerName(creatorTask.getReviewer() != null ? creatorTask.getReviewer().getFullName() : null)
                .type(creatorTask.getTask().getType())
                .status(creatorTask.getStatus())
                .deadline(creatorTask.getTask().getDueDate())
                .build();
    }

    public List<TrainerDto> getTrainers() {
        List<User> trainers = userRepository.findByRoleName("TRAINER");
        return trainers.stream().map(t -> TrainerDto.builder()
                .id(t.getId())
                .fullName(t.getFullName())
                .email(t.getEmail())
                .build()
        ).collect(Collectors.toList());
    }

    public List<TrainerDto> getReviewers() {
        List<User> reviewers = userRepository.findByRoleNames(java.util.Arrays.asList("TRAINER", "TRAINER_LEAD"));
        return reviewers.stream().map(t -> TrainerDto.builder()
                .id(t.getId())
                .fullName(t.getFullName())
                .email(t.getEmail())
                .build()
        ).collect(Collectors.toList());
    }

    public void createTask(CreateTaskRequest request, Long leadId) {
        User lead = userRepository.findById(leadId).orElseThrow(() -> new RuntimeException("Lead not found"));
        User assignee = userRepository.findById(request.getAssigneeId()).orElseThrow(() -> new RuntimeException("Assignee not found"));
        User reviewer = null;
        if (request.getReviewerId() != null) {
            reviewer = userRepository.findById(request.getReviewerId()).orElseThrow(() -> new RuntimeException("Reviewer not found"));
        }

        Task task = Task.builder()
                .lead(lead)
                .title(request.getTitle())
                .description(request.getDescription())
                .type(request.getType())
                .dueDate(request.getReviewDeadline())
                .build();
        
        taskRepository.save(task);

        CreatorTask creatorTask = CreatorTask.builder()
                .task(task)
                .creator(assignee)
                .reviewer(reviewer)
                .status("ASSIGNED")
                .build();

        creatorTaskRepository.save(creatorTask);
        
        logActivity(task.getId(), leadId, "ASSIGNED", "Assigned task to " + assignee.getFullName() + ".");
    }

    public TaskDetailDto getTaskDetail(Long taskId, Long leadId) {
        Task task = taskRepository.findById(taskId).orElseThrow(() -> new RuntimeException("Task not found"));
        if (!task.getLead().getId().equals(leadId)) {
            throw new RuntimeException("Unauthorized to view this task");
        }

        CreatorTask creatorTask = creatorTaskRepository.findByTaskId(taskId)
                .orElseThrow(() -> new RuntimeException("Creator task not found"));

        return TaskDetailDto.builder()
                .id(task.getId())
                .title(task.getTitle())
                .description(task.getDescription())
                .type(task.getType())
                .deadline(task.getDueDate())
                .assigneeId(creatorTask.getCreator().getId())
                .reviewerId(creatorTask.getReviewer() != null ? creatorTask.getReviewer().getId() : null)
                .status(creatorTask.getStatus())
                .build();
    }

    public void updateTask(Long taskId, UpdateTaskRequest request, Long leadId) {
        Task task = taskRepository.findById(taskId).orElseThrow(() -> new RuntimeException("Task not found"));
        if (!task.getLead().getId().equals(leadId)) {
            throw new RuntimeException("Unauthorized to update this task");
        }

        CreatorTask creatorTask = creatorTaskRepository.findByTaskId(taskId)
                .orElseThrow(() -> new RuntimeException("Creator task not found"));

        User assignee = userRepository.findById(request.getAssigneeId()).orElseThrow(() -> new RuntimeException("Assignee not found"));
        User reviewer = null;
        if (request.getReviewerId() != null) {
            reviewer = userRepository.findById(request.getReviewerId()).orElseThrow(() -> new RuntimeException("Reviewer not found"));
        }

        task.setTitle(request.getTitle());
        task.setDescription(request.getDescription());
        task.setType(request.getType());
        task.setDueDate(request.getDeadline());
        taskRepository.save(task);

        creatorTask.setCreator(assignee);
        creatorTask.setReviewer(reviewer);
        if (request.getStatus() != null && !request.getStatus().isEmpty()) {
            creatorTask.setStatus(request.getStatus());
        }
        creatorTaskRepository.save(creatorTask);

        logActivity(taskId, leadId, creatorTask.getStatus(), "Updated task details.");
    }

    public void updateTaskStatus(Long taskId, String status, Long leadId) {
        Task task = taskRepository.findById(taskId).orElseThrow(() -> new RuntimeException("Task not found"));
        if (!task.getLead().getId().equals(leadId)) {
            throw new RuntimeException("Unauthorized to update this task");
        }
        CreatorTask creatorTask = creatorTaskRepository.findByTaskId(taskId)
                .orElseThrow(() -> new RuntimeException("Creator task not found"));
        creatorTask.setStatus(status);
        creatorTaskRepository.save(creatorTask);
        
        logActivity(taskId, leadId, status, "Changed status to " + status + ".");
    }

    public List<TaskActivityDto> getTaskActivities(Long taskId, Long leadId) {
        Task task = taskRepository.findById(taskId).orElseThrow(() -> new RuntimeException("Task not found"));
        if (!task.getLead().getId().equals(leadId)) {
            throw new RuntimeException("Unauthorized to view this task");
        }
        
        List<TaskActivity> activities = taskActivityRepository.findByTaskIdOrderByCreatedAtDesc(taskId);
        return activities.stream().map(a -> {
            User u = userRepository.findById(a.getUserId()).orElse(null);
            String userName = u != null ? u.getFullName() : "Unknown User";
            return TaskActivityDto.builder()
                    .id(a.getId())
                    .taskId(a.getTaskId())
                    .userId(a.getUserId())
                    .userName(userName)
                    .actionType(a.getNewStatus())
                    .description(a.getNote())
                    .createdAt(a.getCreatedAt())
                    .build();
        }).collect(Collectors.toList());
    }

    public Page<com.hango.hango_backend.dto.TrainerTaskDto> getTasksForTrainer(
            Long trainerId, LocalDateTime fromDate, LocalDateTime toDate, String type, String search, int page, int size
    ) {
        Pageable pageable = org.springframework.data.domain.PageRequest.of(page, size, org.springframework.data.domain.Sort.by("task.dueDate").ascending());
        Page<CreatorTask> tasks = creatorTaskRepository.findTasksForTrainer(trainerId, fromDate, toDate, type, search, pageable);

        return tasks.map(ct -> {
            checkAutoReject(ct);
            return com.hango.hango_backend.dto.TrainerTaskDto.builder()
                    .id(ct.getId())
                    .taskId(ct.getTask().getId())
                    .taskContent(ct.getTask().getTitle())
                    .deadline(ct.getTask().getDueDate())
                    .type(ct.getTask().getType())
                    .status(ct.getStatus())
                    .build();
        });
    }

    public void acceptTaskByTrainer(Long creatorTaskId, Long trainerId) {
        CreatorTask creatorTask = creatorTaskRepository.findById(creatorTaskId)
                .orElseThrow(() -> new RuntimeException("Creator task not found"));

        if (!creatorTask.getCreator().getId().equals(trainerId)) {
            throw new RuntimeException("Unauthorized to accept this task");
        }

        checkAutoReject(creatorTask);

        if ("ASSIGNED".equals(creatorTask.getStatus())) {
            creatorTask.setStatus("IN_PROGRESS");
            creatorTaskRepository.save(creatorTask);
            logActivity(creatorTask.getTask().getId(), trainerId, "IN_PROGRESS", "Task accepted by trainer.");
        } else {
            throw new RuntimeException("Task cannot be accepted from status: " + creatorTask.getStatus());
        }
    }

    public TaskDetailDto getTaskDetailForTrainer(Long creatorTaskId, Long trainerId) {
        CreatorTask ct = creatorTaskRepository.findById(creatorTaskId)
                .orElseThrow(() -> new RuntimeException("Creator task not found"));

        if (!ct.getCreator().getId().equals(trainerId)) {
            throw new RuntimeException("Unauthorized to view this task");
        }

        checkAutoReject(ct);

        return TaskDetailDto.builder()
                .id(ct.getTask().getId())
                .title(ct.getTask().getTitle())
                .description(ct.getTask().getDescription())
                .type(ct.getTask().getType())
                .assigneeId(ct.getCreator() != null ? ct.getCreator().getId() : null)
                .assigneeName(ct.getCreator() != null ? ct.getCreator().getFullName() : null)
                .reviewerId(ct.getReviewer() != null ? ct.getReviewer().getId() : null)
                .reviewerName(ct.getReviewer() != null ? ct.getReviewer().getFullName() : null)
                .deadline(ct.getTask().getDueDate())
                .status(ct.getStatus())
                .build();
    }

    public List<TaskActivityDto> getTaskActivitiesForTrainer(Long creatorTaskId, Long trainerId) {
        CreatorTask ct = creatorTaskRepository.findById(creatorTaskId)
                .orElseThrow(() -> new RuntimeException("Creator task not found"));

        if (!ct.getCreator().getId().equals(trainerId)) {
            throw new RuntimeException("Unauthorized to view this task activities");
        }

        List<TaskActivity> activities = taskActivityRepository.findByTaskIdOrderByCreatedAtDesc(ct.getTask().getId());
        return activities.stream().map(a -> {
            User u = userRepository.findById(a.getUserId()).orElse(null);
            String userName = u != null ? u.getFullName() : "System";
            return TaskActivityDto.builder()
                    .id(a.getId())
                    .taskId(a.getTaskId())
                    .userId(a.getUserId())
                    .userName(userName)
                    .actionType(a.getNewStatus())
                    .description(a.getNote())
                    .createdAt(a.getCreatedAt())
                    .build();
        }).collect(Collectors.toList());
    }
}
