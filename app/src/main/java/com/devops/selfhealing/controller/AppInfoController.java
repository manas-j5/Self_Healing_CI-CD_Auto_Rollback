package com.devops.selfhealing.controller;

import org.springframework.beans.factory.annotation.Value;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RestController;

import java.time.Instant;
import java.util.LinkedHashMap;
import java.util.Map;

/**
 * AppInfoController - Provides application metadata and version information.
 *
 * Endpoints:
 *   GET /api/info    → Returns app name, version, environment, and timestamp
 *   GET /api/ping    → Simple liveness check (returns "pong")
 *
 * Note: The primary health check endpoint /actuator/health is handled
 * automatically by Spring Boot Actuator. This controller adds
 * application-level context for deployment tracking.
 */
@RestController
@RequestMapping("/api")
public class AppInfoController {

    // Injected via environment variable APP_VERSION (defaults to "local")
    @Value("${app.version:local}")
    private String appVersion;

    // Injected via environment variable APP_ENV (defaults to "development")
    @Value("${app.env:development}")
    private String appEnv;

    // Application name
    @Value("${spring.application.name:selfhealing-app}")
    private String appName;

    /**
     * GET /api/info
     *
     * Returns application metadata including current version.
     * Used by the deployment pipeline to verify which version is running.
     *
     * @return JSON with app name, version, environment, and deployment timestamp
     */
    @GetMapping("/info")
    public ResponseEntity<Map<String, Object>> getInfo() {
        Map<String, Object> info = new LinkedHashMap<>();
        info.put("application", appName);
        info.put("version", appVersion);
        info.put("environment", appEnv);
        info.put("status", "RUNNING");
        info.put("timestamp", Instant.now().toString());
        info.put("message", "Self-Healing CI/CD Deployment System - Active");

        return ResponseEntity.ok(info);
    }

    /**
     * GET /api/ping
     *
     * Simple liveness probe endpoint.
     * Fast response to confirm the application is reachable.
     *
     * @return "pong" string
     */
    @GetMapping("/ping")
    public ResponseEntity<Map<String, String>> ping() {
        Map<String, String> response = new LinkedHashMap<>();
        response.put("status", "pong");
        response.put("version", appVersion);
        return ResponseEntity.ok(response);
    }

    /**
     * GET /api/version
     *
     * Returns only the current version tag.
     * Used in deployment scripts to log which version is active.
     *
     * @return version string
     */
    @GetMapping("/version")
    public ResponseEntity<Map<String, String>> getVersion() {
        Map<String, String> response = new LinkedHashMap<>();
        response.put("version", appVersion);
        response.put("deployedAt", Instant.now().toString());
        return ResponseEntity.ok(response);
    }
}
