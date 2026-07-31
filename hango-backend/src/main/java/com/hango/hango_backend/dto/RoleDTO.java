package com.hango.hango_backend.dto;

import lombok.*;
import java.util.List;

@Data
@NoArgsConstructor
@AllArgsConstructor
@Builder
public class RoleDTO {
    private String roleName;
    private List<PermissionDTO> permissions;
}
