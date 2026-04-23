package com.devops.selfhealing;  // ⚠️ replace with your package

import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.RestController;

import java.nio.file.Files;
import java.nio.file.Paths;

@RestController
public class LogsController {

    @GetMapping("/api/logs")
    public String getLogs() {
        try {
            return new String(
                Files.readAllBytes(Paths.get("/var/log/app/app.log"))
            );
        } catch (Exception e) {
            return "No logs available...";
        }
    }
}