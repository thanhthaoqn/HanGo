package com.hango.hango_backend.controller;

import com.hango.hango_backend.dto.TaskDTO;
import com.hango.hango_backend.dto.TaskRequestDTO;
import com.hango.hango_backend.dto.TaskStatusUpdateRequest;
import com.hango.hango_backend.entity.User;
import com.hango.hango_backend.repository.UserRepository;
import com.hango.hango_backend.sercurity.UserDetailsImpl;
import com.hango.hango_backend.service.TaskService;
import jakarta.validation.Valid;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.data.domain.Page;
import org.springframework.data.domain.PageRequest;
import org.springframework.data.domain.Pageable;
import org.springframework.data.domain.Sort;
import org.springframework.format.annotation.DateTimeFormat;
import org.springframework.http.ResponseEntity;
import org.springframework.security.access.prepost.PreAuthorize;
import org.springframework.security.core.annotation.AuthenticationPrincipal;
import org.springframework.web.bind.annotation.*;

import java.time.LocalDateTime;

@CrossOrigin(origins = "*", maxAge = 3600)
@RestController
@RequestMapping("/api/v1/tasks")
public class TaskController {

    @Autowired
    private TaskService taskService;

    @Autowired
    private UserRepository userRepository;

    @GetMapping
    @PreAuthorize("hasAnyRole('TRAINER', 'TRAINER_LEAD', 'ADMINISTRATOR')")
    public ResponseEntity<Page<TaskDTO>> getTasks(
            @RequestParam(required = false) Long leadId,
            @RequestParam(required = false) Long creatorId,
            @RequestParam(required = false) @DateTimeFormat(iso = DateTimeFormat.ISO.DATE_TIME) LocalDateTime fromDate,
            @RequestParam(required = false) @DateTimeFormat(iso = DateTimeFormat.ISO.DATE_TIME) LocalDateTime toDate,
            @RequestParam(required = false) String search,
            @RequestParam(defaultValue = "0") int page,
            @RequestParam(defaultValue = "10") int size,
            @RequestParam(defaultValue = "createdAt,desc") String[] sort) {

        String sortField = sort[0];
        Sort.Direction sortDirection = sort[1].equalsIgnoreCase("desc") ? Sort.Direction.DESC : Sort.Direction.ASC;
        Pageable pageable = PageRequest.of(page, size, Sort.by(sortDirection, sortField));

        Page<TaskDTO> tasks = taskService.getTasks(leadId, creatorId, fromDate, toDate, search, pageable);
        return ResponseEntity.ok(tasks);
    }

    @PostMapping
    @PreAuthorize("hasRole('TRAINER_LEAD')")
    public ResponseEntity<?> createTask(@Valid @RequestBody TaskRequestDTO request, 
                                        @AuthenticationPrincipal UserDetailsImpl userDetails) {
        User currentUser = userRepository.findById(userDetails.getId())
                .orElseThrow(() -> new RuntimeException("Current user not found"));
        TaskDTO taskDTO = taskService.createTask(request, currentUser);
        return ResponseEntity.ok(taskDTO);
    }

    @PutMapping("/{id}/status")
    @PreAuthorize("hasAnyRole('TRAINER', 'TRAINER_LEAD')")
    public ResponseEntity<?> updateTaskStatus(@PathVariable Long id, 
                                              @Valid @RequestBody TaskStatusUpdateRequest request,
                                              @AuthenticationPrincipal UserDetailsImpl userDetails) {
        User currentUser = userRepository.findById(userDetails.getId())
                .orElseThrow(() -> new RuntimeException("Current user not found"));
        TaskDTO taskDTO = taskService.updateTaskStatus(id, request, currentUser);
        return ResponseEntity.ok(taskDTO);
    }

    @PutMapping("/{id}")
    @PreAuthorize("hasRole('TRAINER_LEAD')")
    public ResponseEntity<?> updateTask(@PathVariable Long id, 
                                        @Valid @RequestBody TaskRequestDTO request,
                                        @AuthenticationPrincipal UserDetailsImpl userDetails) {
        User currentUser = userRepository.findById(userDetails.getId())
                .orElseThrow(() -> new RuntimeException("Current user not found"));
        TaskDTO taskDTO = taskService.updateTask(id, request, currentUser);
        return ResponseEntity.ok(taskDTO);
    }

    @DeleteMapping("/{id}")
    @PreAuthorize("hasRole('TRAINER_LEAD')")
    public ResponseEntity<?> deleteTask(@PathVariable Long id) {
        taskService.deleteTask(id);
        return ResponseEntity.ok().body("Task deleted successfully");
    }
}
