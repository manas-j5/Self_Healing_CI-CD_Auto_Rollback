package com.devops.selfhealing;

import com.devops.selfhealing.controller.AppInfoController;
import org.junit.jupiter.api.DisplayName;
import org.junit.jupiter.api.Test;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.boot.test.autoconfigure.web.servlet.AutoConfigureMockMvc;
import org.springframework.boot.test.context.SpringBootTest;
import org.springframework.http.MediaType;
import org.springframework.test.web.servlet.MockMvc;

import static org.assertj.core.api.Assertions.assertThat;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.get;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.*;

/**
 * SelfHealingApplicationTests — Integration + unit tests for the Self-Healing App.
 *
 * Tests:
 *   1. Application context loads successfully
 *   2. AppInfoController is wired correctly
 *   3. GET /api/info returns 200 OK with expected fields
 *   4. GET /api/ping returns 200 OK with "pong"
 *   5. GET /actuator/health returns 200 OK with status "UP"
 *
 * The test suite is run during the CI pipeline (mvn test).
 * A failure here will stop the pipeline and prevent broken code from deploying.
 */
@SpringBootTest(webEnvironment = SpringBootTest.WebEnvironment.RANDOM_PORT)
@AutoConfigureMockMvc
class SelfHealingApplicationTests {

    @Autowired
    private MockMvc mockMvc;

    @Autowired(required = false)
    private AppInfoController appInfoController;

    // ------------------------------------------------------------------
    // 1. Context Load Test
    // ------------------------------------------------------------------
    @Test
    @DisplayName("Application context loads without errors")
    void contextLoads() {
        // Spring context must fully initialize; failure here = misconfiguration
        assertThat(appInfoController).isNotNull();
    }

    // ------------------------------------------------------------------
    // 2. GET /api/info — Application Metadata
    // ------------------------------------------------------------------
    @Test
    @DisplayName("GET /api/info returns 200 OK with application metadata")
    void getInfo_Returns200WithMetadata() throws Exception {
        mockMvc.perform(get("/api/info")
                        .accept(MediaType.APPLICATION_JSON))
                .andExpect(status().isOk())
                .andExpect(content().contentTypeCompatibleWith(MediaType.APPLICATION_JSON))
                .andExpect(jsonPath("$.application").exists())
                .andExpect(jsonPath("$.version").exists())
                .andExpect(jsonPath("$.status").value("RUNNING"))
                .andExpect(jsonPath("$.message").exists());
    }

    // ------------------------------------------------------------------
    // 3. GET /api/ping — Liveness Probe
    // ------------------------------------------------------------------
    @Test
    @DisplayName("GET /api/ping returns 200 OK with pong status")
    void ping_Returns200WithPong() throws Exception {
        mockMvc.perform(get("/api/ping")
                        .accept(MediaType.APPLICATION_JSON))
                .andExpect(status().isOk())
                .andExpect(content().contentTypeCompatibleWith(MediaType.APPLICATION_JSON))
                .andExpect(jsonPath("$.status").value("pong"));
    }

    // ------------------------------------------------------------------
    // 4. GET /api/version — Version Endpoint
    // ------------------------------------------------------------------
    @Test
    @DisplayName("GET /api/version returns 200 OK with version info")
    void getVersion_Returns200WithVersion() throws Exception {
        mockMvc.perform(get("/api/version")
                        .accept(MediaType.APPLICATION_JSON))
                .andExpect(status().isOk())
                .andExpect(content().contentTypeCompatibleWith(MediaType.APPLICATION_JSON))
                .andExpect(jsonPath("$.version").exists())
                .andExpect(jsonPath("$.deployedAt").exists());
    }

    // ------------------------------------------------------------------
    // 5. GET /actuator/health — Spring Actuator Health Check
    //    This is the CORE endpoint used by the self-healing deployment script
    // ------------------------------------------------------------------
    @Test
    @DisplayName("GET /actuator/health returns UP status (core self-healing check)")
    void actuatorHealth_ReturnsUp() throws Exception {
        mockMvc.perform(get("/actuator/health")
                        .accept(MediaType.APPLICATION_JSON))
                .andExpect(status().isOk())
                .andExpect(content().contentTypeCompatibleWith(MediaType.APPLICATION_JSON))
                .andExpect(jsonPath("$.status").value("UP"));
    }
}
