#!/bin/bash
# Termux subpackage build script for grok2api
# This script is used by termux-package-builder

TERMUX_PKG_HOMEPAGE=https://github.com/valitacrossdress-oss/grok2api
TERMUX_PKG_DESCRIPTION="A multi-account API gateway for Grok Build, Grok Web, and Grok Console"
TERMUX_PKG_LICENSE=MIT
TERMUX_PKG_MAINTAINER="grok2api Team <grok2api@example.com>"
TERMUX_PKG_VERSION=3.1.4
TERMUX_PKG_REVISION=1
TERMUX_PKG_SRCURL=https://github.com/valitacrossdress-oss/grok2api/archive/refs/tags/v${TERMUX_PKG_VERSION}.tar.gz
TERMUX_PKG_SHA256=$(curl -sL "$TERMUX_PKG_SRCURL" | sha256sum | cut -d' ' -f1)
TERMUX_PKG_DEPENDS="ca-certificates, openssl, nodejs"
TERMUX_PKG_BUILD_IN_SRC=true
TERMUX_PKG_PLATFORM_INDEPENDENT=false

# Go build settings
TERMUX_PKG_GOOS=linux
TERMUX_PKG_GOARCH=arm64

termux_step_pre_configure() {
    # Install Go if not present
    if ! command -v go &> /dev/null; then
        echo "Go not found. Installing..."
        pkg install golang
    fi
}

termux_step_make() {
    # Build the Go backend
    cd backend
    
    # Set up Go environment
    export GOPATH=$TERMUX_PREFIX/go
    export PATH=$PATH:$GOPATH/bin
    
    # Build for linux/arm64 (Termux runs on Android which uses Linux syscalls)
    CGO_ENABLED=0 GOOS=$TERMUX_PKG_GOOS GOARCH=$TERMUX_PKG_GOARCH \
        go build -buildvcs=false -trimpath -ldflags="-s -w" \
        -o $TERMUX_PREFIX/bin/grok2api-server ./cmd/grok2api
    
    # Build the frontend (this is simplified - actual build may need more deps)
    cd ../frontend
    if command -v pnpm &> /dev/null; then
        pnpm install --frozen-lockfile
        pnpm build
    else
        echo "pnpm not found, skipping frontend build"
    fi
}

termux_step_make_install() {
    # Install the binary
    install -Dm700 $TERMUX_PKG_SRCDIR/backend/grok2api-server $TERMUX_PREFIX/bin/grok2api
    
    # Install frontend assets
    mkdir -p $TERMUX_PREFIX/share/grok2api/frontend
    if [ -d "$TERMUX_PKG_SRCDIR/frontend/dist" ]; then
        cp -r $TERMUX_PKG_SRCDIR/frontend/dist/* $TERMUX_PREFIX/share/grok2api/frontend/
    fi
    
    # Install default config
    install -Dm600 $TERMUX_PKG_SRCDIR/config.example.yaml $TERMUX_PREFIX/share/grok2api/config.example.yaml
    
    # Install wrapper script
    install -Dm700 $TERMUX_PKG_SRCDIR/termux-package/grok2api.sh $TERMUX_PREFIX/bin/grok2api
    
    # Install VERSION file
    install -Dm600 $TERMUX_PKG_SRCDIR/VERSION $TERMUX_PREFIX/share/grok2api/VERSION
}
