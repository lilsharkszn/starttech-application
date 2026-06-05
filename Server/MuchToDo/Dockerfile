# =========================
# Stage 1 — Builder
# =========================
FROM golang:1.23-alpine AS builder

WORKDIR /app

# Install build dependencies
RUN apk add --no-cache git ca-certificates tzdata

# Create non-root user for runtime stage
RUN adduser -D -g '' appuser

# Copy dependency files first (maximise layer cache)
COPY go.mod go.sum ./

# Download and verify dependencies
RUN go mod download && go mod verify

# Copy application source
COPY . .

# Build fully static binary — no CGO, stripped symbols for minimal size
RUN CGO_ENABLED=0 GOOS=linux GOARCH=amd64 go build \
    -ldflags='-w -s -extldflags "-static"' \
    -a -o muchtodo ./cmd/api

# =========================
# Stage 2 — Runtime
# =========================
FROM alpine:3.21

WORKDIR /app

# Security patches + CA certs for TLS (MongoDB Atlas, Redis TLS)
RUN apk add --no-cache ca-certificates tzdata wget && \
    update-ca-certificates

# Create non-root user
RUN adduser -D -g '' appuser

# Pull binary from builder stage
COPY --from=builder /app/muchtodo .

# Ensure correct ownership
RUN chown appuser:appuser ./muchtodo

# Drop to non-root
USER appuser

EXPOSE 8080

# Health check — aligns with ALB health check path /ping
HEALTHCHECK --interval=30s --timeout=5s --start-period=15s --retries=3 \
    CMD wget --no-verbose --tries=1 --spider http://localhost:8080/ping || exit 1

ENTRYPOINT ["./muchtodo"]
