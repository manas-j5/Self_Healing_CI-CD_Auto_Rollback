package com.devops.selfhealing;

import org.springframework.boot.SpringApplication;
import org.springframework.boot.autoconfigure.SpringBootApplication;

/**
 * SelfHealingApplication - Main entry point for the Self-Healing CI/CD Demo App
 *
 * This Spring Boot application demonstrates:
 *  - Production-grade REST API
 *  - Health endpoint via Spring Actuator (/actuator/health)
 *  - Blue-Green deployment compatibility
 *  - Zero-downtime rolling deployments
 *
 * @author DevOps Team
 * @version 1.0.0
 */
@SpringBootApplication
public class SelfHealingApplication {

    public static void main(String[] args) {
        SpringApplication.run(SelfHealingApplication.class, args);
    }
}
