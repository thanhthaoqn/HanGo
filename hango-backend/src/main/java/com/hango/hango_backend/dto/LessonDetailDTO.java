package com.hango.hango_backend.dto;

import lombok.AllArgsConstructor;
import lombok.Builder;
import lombok.Data;
import lombok.NoArgsConstructor;

import java.util.List;

@Data
@Builder
@NoArgsConstructor
@AllArgsConstructor
public class LessonDetailDTO {
    private Long id;
    private String title;
    private String content;
    private Long sectionId;
    private Long courseId;
    private List<CommentDTO> comments;
}
