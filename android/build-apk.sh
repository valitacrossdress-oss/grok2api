#!/bin/bash
# Build script for grok2api Android APK
# This script compiles the Go binary for Android and builds the APK

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"
ANDROID_DIR="$PROJECT_ROOT/android"
BUILD_DIR="$ANDROID_DIR/build"

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

echo -e "${BLUE}=== grok2api Android APK Builder ===${NC}"
echo ""

# Step 1: Check dependencies
echo -e "${BLUE}Step 1: Checking dependencies...${NC}"

if ! command -v go &> /dev/null; then
    echo -e "${RED}Error: Go is not installed.${NC}"
    echo "Please install Go 1.26+ from https://golang.org"
    exit 1
fi

if ! command -v java &> /dev/null; then
    echo -e "${RED}Error: Java is not installed.${NC}"
    echo "Please install Java JDK 17+ from https://www.oracle.com/java/technologies/javase-downloads.html"
    exit 1
fi

# Check for Android SDK
if [ -z "$ANDROID_HOME" ] || [ ! -d "$ANDROID_HOME" ]; then
    echo -e "${RED}Error: Android SDK not found.${NC}"
    echo "Please set ANDROID_HOME environment variable to your Android SDK path."
    exit 1
fi

# Check for Android NDK (for cross-compilation)
if [ -z "$ANDROID_NDK_HOME" ] || [ ! -d "$ANDROID_NDK_HOME" ]; then
    echo -e "${YELLOW}Warning: Android NDK not found.${NC}"
    echo "Native compilation will be skipped. Using pre-built binary."
fi

# Check Gradle
if ! command -v gradle &> /dev/null; then
    echo -e "${YELLOW}Warning: Gradle not found in PATH.${NC}"
    echo "Will use gradle wrapper if available."
fi

echo -e "${GREEN}Dependencies check complete!${NC}"
echo ""

# Step 2: Build Go binary for Android
echo -e "${BLUE}Step 2: Building Go binary for Android...${NC}"

cd "$PROJECT_ROOT/backend"

# Set up Go environment for Android cross-compilation
export GOPATH="$BUILD_DIR/gopath"
export GOBIN="$BUILD_DIR/bin"
mkdir -p "$GOPATH" "$GOBIN"

# Set Android NDK paths if available
if [ -n "$ANDROID_NDK_HOME" ]; then
    export CGO_ENABLED=1
    export GOOS=android
    export GOARCH=arm64
    export CC="$ANDROID_NDK_HOME/toolchains/llvm/prebuilt/linux-x86_64/bin/aarch64-linux-android34-clang"
    export CXX="$ANDROID_NDK_HOME/toolchains/llvm/prebuilt/linux-x86_64/bin/aarch64-linux-android34-clang++"
    
    echo "Building with CGO for Android (arm64)..."
    go build -buildvcs=false -trimpath \
        -o "$ANDROID_DIR/app/src/main/assets/grok2api" \
        ./cmd/grok2api
else
    # Build without CGO (static binary)
    export CGO_ENABLED=0
    export GOOS=android
    export GOARCH=arm64
    
    echo "Building without CGO (static binary)..."
    go build -buildvcs=false -trimpath -ldflags="-s -w" \
        -o "$ANDROID_DIR/app/src/main/assets/grok2api" \
        ./cmd/grok2api
fi

if [ ! -f "$ANDROID_DIR/app/src/main/assets/grok2api" ]; then
    echo -e "${RED}Error: Failed to build Go binary for Android${NC}"
    exit 1
fi

chmod +x "$ANDROID_DIR/app/src/main/assets/grok2api"
echo -e "${GREEN}Go binary built successfully!${NC}"
echo ""

# Step 3: Copy config example to assets
echo -e "${BLUE}Step 3: Copying configuration files...${NC}"

cp "$PROJECT_ROOT/config.example.yaml" "$ANDROID_DIR/app/src/main/assets/config.example.yaml"
cp "$PROJECT_ROOT/VERSION" "$ANDROID_DIR/app/src/main/assets/VERSION"

echo -e "${GREEN}Configuration files copied!${NC}"
echo ""

# Step 4: Build Android APK
echo -e "${BLUE}Step 4: Building Android APK...${NC}"

cd "$ANDROID_DIR"

# Use gradle wrapper if available
if [ -f "gradlew" ]; then
    ./gradlew clean assembleDebug
elif command -v gradle &> /dev/null; then
    gradle clean assembleDebug
else
    echo -e "${RED}Error: Neither gradle wrapper nor gradle command found${NC}"
    exit 1
fi

echo ""
echo -e "${GREEN}=== Build Complete! ===${NC}"
echo ""

# Find the APK
APK_FILE=$(find "$ANDROID_DIR" -name "*.apk" -type f | head -n 1)

if [ -n "$APK_FILE" ]; then
    echo -e "APK created: ${GREEN}$APK_FILE${NC}"
    echo ""
    echo "To install on your Android device:"
    echo "  1. Copy the APK to your device"
    echo "  2. Enable 'Install from unknown sources' in Settings"
    echo "  3. Open the APK file to install"
    echo ""
    echo "Or use adb:"
    echo "  adb install $APK_FILE"
else
    echo -e "${RED}Error: APK file not found${NC}"
    exit 1
fi
