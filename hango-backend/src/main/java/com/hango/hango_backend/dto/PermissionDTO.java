package com.hango.hango_backend.dto;

import lombok.*;

@Data
@NoArgsConstructor
@AllArgsConstructor
@Builder
public class PermissionDTO {
    private String code;
    private String name;
    private String description;
    private String module;
    private String coreForRoles;
    private String restrictedForRoles;
}
