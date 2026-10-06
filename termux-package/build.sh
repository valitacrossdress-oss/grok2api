#!/bin/bash
# Termux package build script for grok2api
# This follows Termux package conventions
# See: https://wiki.termux.com/wiki/Creating_packages

TERMUX_PKG_HOMEPAGE=https://github.com/valitacrossdress-oss/grok2api
TERMUX_PKG_DESCRIPTION="A multi-account API gateway for Grok Build, Grok Web, and Grok Console"
TERMUX_PKG_LICENSE=MIT
TERMUX_PKG_MAINTAINER="grok2api Team @github"
TERMUX_PKG_VERSION=3.1.4
TERMUX_PKG_REVISION=1
TERMUX_PKG_SRCURL=https://github.com/valitacrossdress-oss/grok2api/archive/v${TERMUX_PKG_VERSION}.tar.gz
TERMUX_PKG_SHA256=SKIP_CHECKSUM
TERMUX_PKG_DEPENDS="ca-certificates, openssl"
TERMUX_PKG_BUILD_DEPENDS="golang"
TERMUX_PKG_PLATFORM_INDEPENDENT=false

# Use linux/arm64 for Termux (Android uses Linux syscalls)
TERMUX_PKG_GOOS=linux
TERMUX_PKG_GOARCH=arm64

# This package contains the binary only
TERMUX_PKG_AUTO_UPDATE=true

termux_step_pre_configure() {
    # The source is the entire repository
    # We'll use the existing source in the current directory
    if [ -d "$TERMUX_PKG_SRCDIR" ]; then
        echo "Using existing source directory"
    else
        echo "Source directory not found, cloning..."
        git clone https://github.com/valitacrossdress-oss/grok2api "$TERMUX_PKG_SRCDIR"
        cd "$TERMUX_PKG_SRCDIR"
        git checkout v${TERMUX_PKG_VERSION}
    fi
}

termux_step_post_get_source() {
    # If we cloned, we're already in the right place
    if [ -f "$TERMUX_PKG_SRCDIR/VERSION" ]; then
        return
    fi
    
    # Otherwise, use the parent directory
    ln -sf "$TERMUX_PKG_BUILDER_DIR/.." "$TERMUX_PKG_SRCDIR"
}

termux_step_make() {
    # Set up Go environment
    export GOPATH="$TERMUX_PKG_BUILDDIR/gopath"
    export GOBIN="$TERMUX_PKG_BUILDDIR/bin"
    mkdir -p "$GOPATH" "$GOBIN"
    
    cd "$TERMUX_PKG_SRCDIR/backend"
    
    # Download Go modules
    CGO_ENABLED=0 GOOS=$TERMUX_PKG_GOOS GOARCH=$TERMUX_PKG_GOARCH go mod download
    
    # Build the binary
    CGO_ENABLED=0 GOOS=$TERMUX_PKG_GOOS GOARCH=$TERMUX_PKG_GOARCH \
        go build -buildvcs=false -trimpath -ldflags="-s -w" \
        -o "$TERMUX_PKG_BUILDDIR/grok2api" ./cmd/grok2api
}

termux_step_make_install() {
    # Install the binary
    install -Dm755 "$TERMUX_PKG_BUILDDIR/grok2api" "$TERMUX_PREFIX/bin/grok2api"
    
    # Install default config
    install -Dm644 "$TERMUX_PKG_SRCDIR/config.example.yaml" "$TERMUX_PREFIX/share/grok2api/config.example.yaml"
    
    # Install wrapper script as grok2api-server
    install -Dm755 "$TERMUX_PKG_SRCDIR/termux-package/grok2api.sh" "$TERMUX_PREFIX/bin/grok2api-server"
    
    # Install VERSION file
    install -Dm644 "$TERMUX_PKG_SRCDIR/VERSION" "$TERMUX_PREFIX/share/grok2api/VERSION"
    
    # Create data directories
    mkdir -p "$TERMUX_PREFIX/var/lib/grok2api"
    mkdir -p "$TERMUX_PREFIX/var/log/grok2api"
    mkdir -p "$TERMUX_PREFIX/etc/grok2api"
}

termux_step_create_debscripts() {
    # Post-install script
    cat > "postinst" <<-EOF
	#!/bin/bash
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
	echo "  2. Generate secrets (if needed): grok2api-server secrets"
	echo "  3. Start the server: grok2api-server start"
	echo ""
	echo "Access the admin console at: http://localhost:8000"
	EOF
	
	chmod 755 postinst
	
	# Pre-remove script
	cat > "prerm" <<-EOF
	#!/bin/bash
	echo "Removing grok2api..."
	
	# Stop the server if running
	if [ -f "$PREFIX/var/run/grok2api.pid" ]; then
	    local pid=$(cat "$PREFIX/var/run/grok2api.pid")
	    if kill -0 "$pid" 2>/dev/null; then
	        kill "$pid" 2>/dev/null
	        sleep 2
	        kill -9 "$pid" 2>/dev/null
	    fi
	    rm -f "$PREFIX/var/run/grok2api.pid"
	fi
	
	echo "grok2api stopped."
	EOF
	
	chmod 755 prerm
}
