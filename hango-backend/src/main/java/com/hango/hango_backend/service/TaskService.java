package com.hango.hango_backend.service;

import com.hango.hango_backend.dto.TaskDTO;
import com.hango.hango_backend.dto.TaskRequestDTO;
import com.hango.hango_backend.dto.TaskStatusUpdateRequest;
import com.hango.hango_backend.entity.Role;
import com.hango.hango_backend.entity.Task;
import com.hango.hango_backend.entity.TaskActivity;
import com.hango.hango_backend.entity.TaskStatus;
import com.hango.hango_backend.entity.TaskType;
import com.hango.hango_backend.entity.User;
import com.hango.hango_backend.repository.TaskActivityRepository;
import com.hango.hango_backend.repository.TaskRepository;
import com.hango.hango_backend.repository.UserRepository;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.data.domain.Page;
import org.springframework.data.domain.Pageable;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.time.LocalDateTime;

@Service
public class TaskService {

    @Autowired
    private TaskRepository taskRepository;

    @Autowired
    private TaskActivityRepository taskActivityRepository;

    @Autowired
    private UserRepository userRepository;

    public Page<TaskDTO> getTasks(Long assignedById, Long assignedToId, TaskType type, 
                                  LocalDateTime fromDate, LocalDateTime toDate, 
                                  String search, Pageable pageable) {
        Page<Task> tasks = taskRepository.findTasksWithFilters(assignedById, assignedToId, type, fromDate, toDate, search, pageable);
        return tasks.map(this::mapToDTO);
    }

    @Transactional
    public TaskDTO createTask(TaskRequestDTO request, User currentUser) {
        User assignee = userRepository.findById(request.getAssignedToId())
                .orElseThrow(() -> new RuntimeException("Assignee not found"));

        boolean isTrainerOrLead = assignee.getRoles().stream()
                .map(Role::getRoleName)
                .anyMatch(role -> role.equals("ROLE_TRAINER") || role.equals("ROLE_TRAINER_LEAD"));
                
        if (!isTrainerOrLead) {
            throw new RuntimeException("Assignee must be a Trainer or Lead");
        }

        User assigner = currentUser;
        if (request.getAssignedById() != null) {
            assigner = userRepository.findById(request.getAssignedById())
                    .orElse(currentUser);
        }

        Task task = Task.builder()
                .content(request.getContent())
                .assignedBy(assigner)
                .assignedTo(assignee)
                .type(request.getType())
                .status(TaskStatus.ASSIGNED)
                .deadline(request.getDeadline())
                .build();

        if (request.getImageBase64() != null && !request.getImageBase64().isEmpty()) {
            try {
                String base64Data = request.getImageBase64();
                if (base64Data.contains(",")) {
                    base64Data = base64Data.split(",")[1];
                }
                byte[] imageBytes = java.util.Base64.getDecoder().decode(base64Data);
                task.setImage(imageBytes);
            } catch (Exception e) {
                // Ignore if invalid base64
            }
        }

        Task savedTask = taskRepository.save(task);

        TaskActivity activity = TaskActivity.builder()
                .task(savedTask)
                .changedBy(currentUser)
                .oldStatus(null)
                .newStatus(TaskStatus.ASSIGNED)
                .note("Task created and assigned")
                .build();
        taskActivityRepository.save(activity);

        return mapToDTO(savedTask);
    }

    @Transactional
    public TaskDTO updateTaskStatus(Long taskId, TaskStatusUpdateRequest request, User currentUser) {
        Task task = taskRepository.findById(taskId)
                .orElseThrow(() -> new RuntimeException("Task not found"));

        TaskStatus oldStatus = task.getStatus();
        task.setStatus(request.getStatus());
        Task savedTask = taskRepository.save(task);

        TaskActivity activity = TaskActivity.builder()
                .task(savedTask)
                .changedBy(currentUser)
                .oldStatus(oldStatus)
                .newStatus(request.getStatus())
                .note(request.getNote())
                .build();
        taskActivityRepository.save(activity);

        return mapToDTO(savedTask);
    }

    @Transactional
    public TaskDTO updateTask(Long taskId, TaskRequestDTO request, User currentUser) {
        Task task = taskRepository.findById(taskId)
                .orElseThrow(() -> new RuntimeException("Task not found"));

        User assignee = userRepository.findById(request.getAssignedToId())
                .orElseThrow(() -> new RuntimeException("Assignee not found"));

        task.setContent(request.getContent());
        task.setAssignedTo(assignee);
        task.setType(request.getType());
        task.setDeadline(request.getDeadline());

        Task savedTask = taskRepository.save(task);

        TaskActivity activity = TaskActivity.builder()
                .task(savedTask)
                .changedBy(currentUser)
                .oldStatus(task.getStatus())
                .newStatus(task.getStatus())
                .note("Task details updated")
                .build();
        taskActivityRepository.save(activity);

        return mapToDTO(savedTask);
    }

    @Transactional
    public void deleteTask(Long taskId) {
        Task task = taskRepository.findById(taskId)
                .orElseThrow(() -> new RuntimeException("Task not found"));
        taskActivityRepository.deleteAll(taskActivityRepository.findByTaskIdOrderByCreatedAtDesc(taskId));
        taskRepository.delete(task);
    }

    private TaskDTO mapToDTO(Task task) {
        return TaskDTO.builder()
                .id(task.getId())
                .content(task.getContent())
                .assignedById(task.getAssignedBy().getId())
                .assignedByName(task.getAssignedBy().getFullName())
                .assignedToId(task.getAssignedTo().getId())
                .assignedToName(task.getAssignedTo().getFullName())
                .type(task.getType())
                .status(task.getStatus())
                .deadline(task.getDeadline())
                .createdAt(task.getCreatedAt())
                .updatedAt(task.getUpdatedAt())
                .build();
    }
}
