#!/bin/bash
# Build script for grok2api Termux package
# This script cross-compiles the Go backend for Termux (linux/arm64)
# and prepares the package for installation

set -e

# Configuration
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"
BUILD_DIR="$SCRIPT_DIR/build"
OUT_DIR="$SCRIPT_DIR/output"

# Target platform (Termux runs on Android, but uses Linux syscalls)
GOOS=linux
GOARCH=arm64

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

# Cleanup function
cleanup() {
    echo -e "${YELLOW}Cleaning up...${NC}"
    rm -rf "$BUILD_DIR" "$OUT_DIR"
}

trap cleanup EXIT

# Check dependencies
check_dep() {
    if ! command -v "$1" &> /dev/null; then
        echo -e "${RED}Error: $1 is not installed.${NC}"
        echo "Please install it first:"
        echo "  Termux: pkg install $1"
        echo "  Ubuntu/Debian: sudo apt install $1"
        exit 1
    fi
}

echo -e "${BLUE}=== grok2api Termux Package Builder ===${NC}"
echo ""

# Check required tools
check_dep go
check_dep git

# Create directories
mkdir -p "$BUILD_DIR" "$OUT_DIR"

# Step 1: Build the Go backend
echo -e "${BLUE}Step 1/3: Building Go backend for $GOOS/$GOARCH...${NC}"

cd "$PROJECT_ROOT/backend"

# Set Go environment
export GOPATH="$BUILD_DIR/gopath"
export GOBIN="$BUILD_DIR/bin"
mkdir -p "$GOPATH" "$GOBIN"

# Download dependencies
CGO_ENABLED=0 GOOS=$GOOS GOARCH=$GOARCH go mod download

# Build the binary
CGO_ENABLED=0 GOOS=$GOOS GOARCH=$GOARCH \
    go build -buildvcs=false -trimpath -ldflags="-s -w" \
    -o "$BUILD_DIR/grok2api-server" ./cmd/grok2api

if [ ! -f "$BUILD_DIR/grok2api-server" ]; then
    echo -e "${RED}Error: Failed to build Go binary${NC}"
    exit 1
fi

echo -e "${GREEN}Go backend built successfully!${NC}"
echo ""

# Step 2: Build the frontend (optional - requires Node.js)
echo -e "${BLUE}Step 2/3: Building frontend...${NC}"

if command -v node &> /dev/null && command -v pnpm &> /dev/null; then
    cd "$PROJECT_ROOT/frontend"
    
    # Check if pnpm is available
    if ! command -v pnpm &> /dev/null; then
        echo -e "${YELLOW}pnpm not found, trying npm...${NC}"
        npm install
        npm run build
    else
        pnpm install --frozen-lockfile 2>/dev/null || pnpm install
        pnpm build
    fi
    
    if [ -d "dist" ]; then
        mkdir -p "$BUILD_DIR/frontend"
        cp -r dist/* "$BUILD_DIR/frontend/"
        echo -e "${GREEN}Frontend built successfully!${NC}"
    else
        echo -e "${YELLOW}Warning: Frontend build failed or no dist directory${NC}"
        echo "The server will still work without the frontend."
    fi
else
    echo -e "${YELLOW}Skipping frontend build (Node.js/pnpm not installed)${NC}"
fi

echo ""

# Step 3: Create Termux package structure
echo -e "${BLUE}Step 3/3: Creating Termux package...${NC}"

# Create package directories
mkdir -p "$OUT_DIR/data/data"
mkdir -p "$OUT_DIR/data/etc/grok2api"
mkdir -p "$OUT_DIR/data/var/lib/grok2api"
mkdir -p "$OUT_DIR/data/var/log/grok2api"
mkdir -p "$OUT_DIR/data/var/run"
mkdir -p "$OUT_DIR/data/usr/bin"
mkdir -p "$OUT_DIR/data/usr/share/grok2api"

# Install binary
install -Dm755 "$BUILD_DIR/grok2api-server" "$OUT_DIR/data/usr/bin/grok2api-server"

# Install frontend if built
if [ -d "$BUILD_DIR/frontend" ]; then
    mkdir -p "$OUT_DIR/data/usr/share/grok2api/frontend"
    cp -r "$BUILD_DIR/frontend"/* "$OUT_DIR/data/usr/share/grok2api/frontend/"
fi

# Install configuration
install -Dm644 "$PROJECT_ROOT/config.example.yaml" "$OUT_DIR/data/usr/share/grok2api/config.example.yaml"
install -Dm644 "$PROJECT_ROOT/VERSION" "$OUT_DIR/data/usr/share/grok2api/VERSION"

# Install wrapper script
install -Dm755 "$SCRIPT_DIR/grok2api.sh" "$OUT_DIR/data/usr/bin/grok2api"

# Create data directory structure
mkdir -p "$OUT_DIR/data/data"

# Create control files
mkdir -p "$OUT_DIR/control"

# Copy control file
install -Dm644 "$SCRIPT_DIR/control" "$OUT_DIR/control/control"

# Create post-install script
cat > "$OUT_DIR/control/postinst" << 'EOF'
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

chmod 755 "$OUT_DIR/control/postinst"

# Create pre-remove script
cat > "$OUT_DIR/control/prerm" << 'EOF'
#!/bin/bash
# Pre-removal script for grok2api

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

# Remove config backup (keep user's custom config)
# Note: We don't remove /etc/grok2api/config.yaml to preserve user settings
EOF

chmod 755 "$OUT_DIR/control/prerm"

# Create the package tarball
echo -e "${BLUE}Creating package tarball...${NC}"

cd "$OUT_DIR"
PACKAGE_NAME="grok2api_${GOOS}_${GOARCH}_$(cat "$PROJECT_ROOT/VERSION" | tr -d '\n').tar.gz"
tar -czf "$SCRIPT_DIR/$PACKAGE_NAME" data control

echo ""
echo -e "${GREEN}=== Build Complete! ===${NC}"
echo ""
echo "Package created: $SCRIPT_DIR/$PACKAGE_NAME"
echo ""
echo "To install in Termux:"
echo "  1. Copy the package to your Termux device"
echo "  2. In Termux, run:"
echo "     cd /path/to/package"
echo "     tar -xzf $PACKAGE_NAME"
echo "     cd data"
echo "     cp -r * /data"
echo "     cp /data/control/* /data/data/"
echo "  3. Or use dpkg if you've created a .deb"
echo ""
echo "Alternative: Use the build script to create a .deb package"
echo "  See: https://wiki.termux.com/wiki/Creating_packages"
