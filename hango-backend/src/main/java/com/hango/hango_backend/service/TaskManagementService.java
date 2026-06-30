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

import com.hango.hango_backend.dto.CreateTaskRequest;
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
                .id(creatorTask.getId())
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
}
