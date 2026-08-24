package com.hango.hango_backend.controller;

import static org.junit.jupiter.api.Assertions.assertEquals;

import java.lang.reflect.Method;
import java.util.Map;
import org.junit.jupiter.api.Test;
import org.springframework.security.access.prepost.PreAuthorize;

class AdminConfigControllerSecurityTest {

    @Test
    void aiConfigEndpointsShouldUseAdministratorRole() throws Exception {
        Method getMethod = AdminConfigController.class.getMethod("getAiConfig");
        Method updateMethod = AdminConfigController.class.getMethod(
                "updateAiConfig",
                Map.class);

        assertEquals(
                "hasRole('ADMINISTRATOR')",
                getMethod.getAnnotation(PreAuthorize.class).value());
        assertEquals(
                "hasRole('ADMINISTRATOR')",
                updateMethod.getAnnotation(PreAuthorize.class).value());
    }
}
