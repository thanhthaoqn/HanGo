package com.hango.hango_backend.controller;

import com.hango.hango_backend.dto.CertificateDTO;
import com.hango.hango_backend.security.UserDetailsImpl;
import com.hango.hango_backend.service.CertificateService;
import lombok.RequiredArgsConstructor;
import org.springframework.http.ResponseEntity;
import org.springframework.security.access.prepost.PreAuthorize;
import org.springframework.security.core.annotation.AuthenticationPrincipal;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.PathVariable;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RestController;

@RestController
@RequestMapping("/api/v1/certificates")
@RequiredArgsConstructor
public class CertificateController {

    private final CertificateService certificateService;

    @GetMapping("/courses/{courseId}")
    @PreAuthorize("hasRole('LEARNER') or hasRole('TRAINER')")
    public ResponseEntity<CertificateDTO> getCertificateForCourse(
            @AuthenticationPrincipal UserDetailsImpl userDetails,
            @PathVariable Long courseId) {
        return ResponseEntity.ok(certificateService.getCertificate(userDetails.getId(), courseId));
    }

    @GetMapping("/{credentialId}")
    public ResponseEntity<CertificateDTO> getCertificateByCredentialId(@PathVariable String credentialId) {
        return ResponseEntity.ok(certificateService.getCertificateByCredentialId(credentialId));
    }
}
