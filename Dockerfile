# Use the official Golang image to create a build artifact.
FROM golang:1.26-bookworm as builder

# Create and change to the app directory.
WORKDIR /app

# Retrieve application dependencies.
COPY go.mod go.sum ./
RUN go mod download

# Copy local code to the container image.
COPY . ./

# Build the binary.
RUN CGO_ENABLED=0 GOOS=linux go build -v -o server

# Use the official Debian slim image for a lean production container.
FROM debian:bookworm-slim
RUN set -x && apt-get update && DEBIAN_FRONTEND=noninteractive apt-get install -y \
    ca-certificates && \
    rm -rf /var/lib/apt/lists/*

WORKDIR /app

# Copy the binary to the production image from the builder stage.
COPY --from=builder /app/server /app/server
COPY --from=builder /app/static /app/static

# Run the web service on container startup.
CMD ["/app/server"]
