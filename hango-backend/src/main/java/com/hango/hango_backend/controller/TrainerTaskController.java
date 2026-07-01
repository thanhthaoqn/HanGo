package com.hango.hango_backend.controller;

import com.hango.hango_backend.dto.TrainerTaskDto;
import com.hango.hango_backend.sercurity.UserDetailsImpl;
import com.hango.hango_backend.service.TaskManagementService;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.data.domain.Page;
import org.springframework.format.annotation.DateTimeFormat;
import org.springframework.http.ResponseEntity;
import org.springframework.security.access.prepost.PreAuthorize;
import org.springframework.security.core.Authentication;
import org.springframework.security.core.context.SecurityContextHolder;
import org.springframework.web.bind.annotation.*;

import java.time.LocalDateTime;

@RestController
@RequestMapping("/api/v1/trainer/tasks")
@CrossOrigin(origins = "*", maxAge = 3600)
public class TrainerTaskController {

    @Autowired
    private TaskManagementService taskManagementService;

    @GetMapping
    @PreAuthorize("hasRole('TRAINER')")
    public ResponseEntity<Page<TrainerTaskDto>> getTasks(
            @RequestParam(required = false) @DateTimeFormat(iso = DateTimeFormat.ISO.DATE_TIME) LocalDateTime fromDate,
            @RequestParam(required = false) @DateTimeFormat(iso = DateTimeFormat.ISO.DATE_TIME) LocalDateTime toDate,
            @RequestParam(required = false) String type,
            @RequestParam(required = false) String search,
            @RequestParam(defaultValue = "0") int page,
            @RequestParam(defaultValue = "10") int size
    ) {
        Authentication authentication = SecurityContextHolder.getContext().getAuthentication();
        UserDetailsImpl userDetails = (UserDetailsImpl) authentication.getPrincipal();
        Long trainerId = userDetails.getId();

        Page<TrainerTaskDto> tasks = taskManagementService.getTasksForTrainer(
                trainerId, fromDate, toDate, type, search, page, size
        );

        return ResponseEntity.ok(tasks);
    }

    @PutMapping("/{id}/accept")
    @PreAuthorize("hasRole('TRAINER')")
    public ResponseEntity<Void> acceptTask(@PathVariable Long id) {
        Authentication authentication = SecurityContextHolder.getContext().getAuthentication();
        UserDetailsImpl userDetails = (UserDetailsImpl) authentication.getPrincipal();
        Long trainerId = userDetails.getId();

        taskManagementService.acceptTaskByTrainer(id, trainerId);
        return ResponseEntity.ok().build();
    }

    @GetMapping("/{id}")
    @PreAuthorize("hasRole('TRAINER')")
    public ResponseEntity<com.hango.hango_backend.dto.TaskDetailDto> getTaskDetail(@PathVariable Long id) {
        Authentication authentication = SecurityContextHolder.getContext().getAuthentication();
        UserDetailsImpl userDetails = (UserDetailsImpl) authentication.getPrincipal();
        Long trainerId = userDetails.getId();

        com.hango.hango_backend.dto.TaskDetailDto detail = taskManagementService.getTaskDetailForTrainer(id, trainerId);
        return ResponseEntity.ok(detail);
    }

    @GetMapping("/{id}/activities")
    @PreAuthorize("hasRole('TRAINER')")
    public ResponseEntity<java.util.List<com.hango.hango_backend.dto.TaskActivityDto>> getTaskActivities(@PathVariable Long id) {
        Authentication authentication = SecurityContextHolder.getContext().getAuthentication();
        UserDetailsImpl userDetails = (UserDetailsImpl) authentication.getPrincipal();
        Long trainerId = userDetails.getId();

        java.util.List<com.hango.hango_backend.dto.TaskActivityDto> activities = taskManagementService.getTaskActivitiesForTrainer(id, trainerId);
        return ResponseEntity.ok(activities);
    }
}
