# ============================================
# Multi-stage Dockerfile for Online Shopping App
# Stage 1: Build WAR with Maven
# Stage 2: Deploy WAR to Tomcat 10
# ============================================

# Stage 1: Build
FROM maven:3.9-eclipse-temurin-17 AS builder
WORKDIR /app
COPY pom.xml .
# Download dependencies first (cache layer)
RUN mvn dependency:go-offline -q
COPY src/ src/
# Build WAR (skip tests — already run in CI)
RUN mvn package -DskipTests -q

# Stage 2: Production
FROM tomcat:10-jdk17-temurin
# Remove default Tomcat apps
RUN rm -rf /usr/local/tomcat/webapps/*
# Copy built WAR (named ROOT.war → deployed at /)
COPY --from=builder /app/target/ROOT.war /usr/local/tomcat/webapps/ROOT.war

EXPOSE 8080

HEALTHCHECK --interval=30s --timeout=5s --retries=3 \
    CMD curl -f http://localhost:8080/ || exit 1

CMD ["catalina.sh", "run"]
