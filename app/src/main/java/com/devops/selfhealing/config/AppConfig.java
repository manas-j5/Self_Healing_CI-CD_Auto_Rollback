package com.devops.selfhealing.config;

import org.springframework.context.annotation.Bean;
import org.springframework.context.annotation.Configuration;
import org.springframework.web.servlet.config.annotation.CorsRegistry;
import org.springframework.web.servlet.config.annotation.WebMvcConfigurer;

/**
 * AppConfig - Application-wide configuration for the Self-Healing CI/CD App.
 *
 * Configures:
 *  - CORS (Cross-Origin Resource Sharing) policy for API endpoints
 */
@Configuration
public class AppConfig {

    /**
     * CORS configuration — allows all origins for demo/internal use.
     * In production, restrict to your domain(s) only.
     */
    @Bean
    public WebMvcConfigurer corsConfigurer() {
        return new WebMvcConfigurer() {
            @Override
            public void addCorsMappings(CorsRegistry registry) {
                registry.addMapping("/api/**")
                        .allowedOrigins("*")
                        .allowedMethods("GET", "POST", "PUT", "DELETE", "OPTIONS")
                        .allowedHeaders("*")
                        .maxAge(3600);
            }
        };
    }
}
