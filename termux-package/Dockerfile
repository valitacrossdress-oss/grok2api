# Termux Package Builder Dockerfile
# Use this to build the grok2api Termux package in a clean environment

ARG GO_VERSION=1.26
ARG NODE_VERSION=22
ARG ALPINE_VERSION=3.23

# Build stage
FROM --platform=linux/arm64 golang:${GO_VERSION}-alpine AS builder

ARG GOOS=linux
ARG GOARCH=arm64

# Install build dependencies
RUN apk add --no-cache git ca-certificates make

# Set up Go environment
ENV GOPATH=/go
ENV GOBIN=/go/bin
ENV PATH=$PATH:/go/bin

WORKDIR /src

# Clone the repository (or copy files)
# For this Dockerfile, we'll assume files are mounted via volume
RUN mkdir -p /src/grok2api
WORKDIR /src/grok2api

# Download Go dependencies
RUN CGO_ENABLED=0 GOOS=$GOOS GOARCH=$GOARCH go mod download

# Build the Go binary
RUN CGO_ENABLED=0 GOOS=$GOOS GOARCH=$GOARCH \
    go build -buildvcs=false -trimpath -ldflags="-s -w" \
    -o /out/grok2api-server ./backend/cmd/grok2api

# Final stage - create the package
FROM alpine:${ALPINE_VERSION}

# Install Node.js for frontend build (optional)
RUN apk add --no-cache nodejs npm

WORKDIR /out

# Copy the built binary
COPY --from=builder /out/grok2api-server /out/

# Copy project files (mounted from host)
# These would be available if using: docker run -v $(pwd):/out ...

# Install the binary
RUN mkdir -p /package/usr/bin /package/usr/share/grok2api
COPY grok2api-server /package/usr/bin/

# Copy Termux package files
COPY termux-package/grok2api.sh /package/usr/bin/grok2api
COPY termux-package/control /package/control/
COPY config.example.yaml /package/usr/share/grok2api/config.example.yaml
COPY VERSION /package/usr/share/grok2api/VERSION

# Set permissions
RUN chmod +x /package/usr/bin/grok2api-server /package/usr/bin/grok2api

# Create package structure
RUN mkdir -p /package/control /package/data

# Create post-install script
RUN cat > /package/control/postinst << 'EOF'
#!/bin/bash
# Post-installation script for grok2api

echo "Installing grok2api..."

# Create directories
mkdir -p "$PREFIX/etc/grok2api"
mkdir -p "$PREFIX/var/lib/grok2api"
mkdir -p "$PREFIX/var/log/grok2api"
mkdir -p "$PREFIX/var/run"

# Copy default config if not exists
if [ ! -f "$PREFIX/etc/grok2api/config.yaml" ]; then
    cp "$PREFIX/share/grok2api/config.example.yaml" "$PREFIX/etc/grok2api/config.yaml"
    echo "Created default config at $PREFIX/etc/grok2api/config.yaml"
fi

# Set permissions
chmod -R 755 "$PREFIX/etc/grok2api"
chmod -R 755 "$PREFIX/var/lib/grok2api"
chmod -R 755 "$PREFIX/var/log/grok2api"

echo "grok2api installed successfully!"
echo ""
echo "To start the server:"
echo "  1. Edit your configuration: nano $PREFIX/etc/grok2api/config.yaml"
echo "  2. Generate secrets (if needed): grok2api secrets"
echo "  3. Initialize config: grok2api init"
echo "  4. Start the server: grok2api start"
echo ""
echo "Access the admin console at: http://localhost:8000"
EOF

# Create the package tarball
RUN cd /package && tar -czf /out/grok2api-termux-package.tar.gz data control

# Output
WORKDIR /out
CMD ["echo", "Build complete! Package is at /out/grok2api-termux-package.tar.gz"]
