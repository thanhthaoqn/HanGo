package com.hango.hango_backend.dto;

import lombok.*;
import java.util.List;

@Data
@NoArgsConstructor
@AllArgsConstructor
public class RolePermissionsUpdateRequest {
    private List<String> permissionCodes;
}
