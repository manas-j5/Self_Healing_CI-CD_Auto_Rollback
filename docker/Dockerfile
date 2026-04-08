# ================================================================
# Multi-Stage Dockerfile for Self-Healing CI/CD Application
# ================================================================
#
# STAGE 1: Builder
#   - Uses Maven + JDK 17 to compile and package the application
#   - Creates a fat executable JAR
#
# STAGE 2: Runtime
#   - Uses minimal JRE 17 Alpine image for production (~150MB total)
#   - Copies only the compiled JAR from the builder stage
#   - Runs as a non-root user for security best practices
#   - Exposes port 8080 and configures health check
#
# Usage:
#   docker build -f docker/Dockerfile -t selfhealing-app:v1 .
#   docker run -p 8080:8080 -e APP_VERSION=v1 -e APP_ENV=production selfhealing-app:v1
# ================================================================

# ----------------------------------------------------------------
# STAGE 1: Builder
# ----------------------------------------------------------------
FROM maven:3.9.6-eclipse-temurin-17-alpine AS builder

# Set working directory for build
WORKDIR /build

# Copy Maven project descriptor first (layer caching optimization)
# Docker will only re-download dependencies if pom.xml changes
COPY app/pom.xml ./pom.xml

# Download all dependencies (cached layer — speeds up subsequent builds)
RUN mvn dependency:go-offline -B --no-transfer-progress

# Copy source code
COPY app/src ./src

# Build the application, skip tests (tests run separately in CI pipeline)
RUN mvn clean package -DskipTests -B --no-transfer-progress

# ----------------------------------------------------------------
# STAGE 2: Production Runtime
# ----------------------------------------------------------------
FROM eclipse-temurin:17-jre-alpine AS runtime

# ---- Security: Run as non-root user ----
RUN addgroup -S appgroup && adduser -S appuser -G appgroup

# ---- Application directory ----
WORKDIR /app

# ---- Create log directory with correct permissions ----
RUN mkdir -p /var/log/app && chown appuser:appgroup /var/log/app

# ---- Copy the executable JAR from builder stage ----
COPY --from=builder /build/target/*.jar app.jar

# ---- Set ownership ----
RUN chown appuser:appgroup /app/app.jar

# ---- Switch to non-root user ----
USER appuser

# ---- Expose application port ----
EXPOSE 8080

# ---- Docker health check ----
# Docker will mark container as unhealthy if this fails
# The deployment script also runs its own curl check
HEALTHCHECK --interval=30s --timeout=10s --start-period=60s --retries=3 \
    CMD wget --no-verbose --tries=1 --spider http://localhost:8080/actuator/health || exit 1

# ---- Environment Variables (defaults, override at runtime) ----
ENV APP_VERSION=latest \
    APP_ENV=production \
    SERVER_PORT=8080 \
    JAVA_OPTS="-Xms256m -Xmx512m -XX:+UseG1GC -XX:+UseContainerSupport"

# ---- Entrypoint ----
# JAVA_OPTS allows passing JVM flags at runtime
ENTRYPOINT ["sh", "-c", "java $JAVA_OPTS -jar /app/app.jar"]
