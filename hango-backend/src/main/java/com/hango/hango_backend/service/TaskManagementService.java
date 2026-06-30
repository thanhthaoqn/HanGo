package com.hango.hango_backend.service;

import com.hango.hango_backend.dto.TaskManagementDto;
import com.hango.hango_backend.entity.CreatorTask;
import com.hango.hango_backend.repository.CreatorTaskRepository;
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
import com.hango.hango_backend.entity.Task;
import com.hango.hango_backend.entity.User;
import com.hango.hango_backend.repository.TaskRepository;
import com.hango.hango_backend.repository.UserRepository;

@Service
public class TaskManagementService {

    @Autowired
    private CreatorTaskRepository creatorTaskRepository;

    @Autowired
    private TaskRepository taskRepository;

    @Autowired
    private UserRepository userRepository;

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
    }
}
