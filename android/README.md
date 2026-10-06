# grok2api Android APK

This directory contains the Android application project for grok2api, allowing you to run the server directly on your Android device as a native APK.

## Overview

The Android app provides:
- A native Android interface for starting/stopping the grok2api server
- A built-in WebView for accessing the admin console
- Background service that keeps the server running
- Log viewing capability
- Automatic configuration management

## Architecture

The app consists of:
- **MainActivity**: User interface with start/stop buttons and WebView
- **Grok2ApiService**: Background service that runs the Go server
- **Grok2ApiApp**: Application class for initialization
- **Assets**: Contains the Go binary and default configuration

The Go server runs as a separate process spawned by the Android service, with its output redirected to a log file.

## Prerequisites

To build the APK, you need:

### On Linux/macOS/Windows:
1. **Java JDK 17+** - For Android development
2. **Android SDK** - With API level 34
3. **Android NDK** - For cross-compiling Go (optional, but recommended)
4. **Go 1.26+** - For building the Go binary
5. **Gradle** - Build system for Android

### Environment Variables
```bash
export ANDROID_HOME=/path/to/android/sdk
export ANDROID_NDK_HOME=/path/to/android/ndk
export PATH=$PATH:$ANDROID_HOME/cmdline-tools/latest/bin
export PATH=$PATH:$ANDROID_HOME/platform-tools
```

## Quick Start

### Method 1: Using the build script (Recommended)

```bash
# Make the build script executable
chmod +x android/build-apk.sh

# Run the build
./android/build-apk.sh
```

The script will:
1. Check dependencies
2. Cross-compile the Go binary for Android (arm64)
3. Copy configuration files
4. Build the Android APK

### Method 2: Manual Build

```bash
# 1. Cross-compile Go for Android
cd backend
CGO_ENABLED=0 GOOS=android GOARCH=arm64 go build -o ../android/app/src/main/assets/grok2api ./cmd/grok2api

# 2. Copy config files
cp config.example.yaml android/app/src/main/assets/config.example.yaml
cp VERSION android/app/src/main/assets/VERSION

# 3. Build APK with Gradle
cd android
./gradlew assembleDebug
```

## Building with Android Studio

1. Open Android Studio
2. Select **File > Open** and navigate to the `android` directory
3. Wait for Gradle to sync
4. Click **Build > Build Bundle(s) / APK(s) > Build APK**
5. The APK will be created in `android/app/build/outputs/apk/debug/`

## Cross-compiling Go for Android

### Without NDK (static binary):
```bash
CGO_ENABLED=0 GOOS=android GOARCH=arm64 \
  go build -trimpath -ldflags="-s -w" \
  -o android/app/src/main/assets/grok2api \
  ./cmd/grok2api
```

### With NDK (better performance):
```bash
export ANDROID_NDK_HOME=/path/to/ndk
export CGO_ENABLED=1
export GOOS=android
export GOARCH=arm64
export CC="$ANDROID_NDK_HOME/toolchains/llvm/prebuilt/linux-x86_64/bin/aarch64-linux-android34-clang"
export CXX="$ANDROID_NDK_HOME/toolchains/llvm/prebuilt/linux-x86_64/bin/aarch64-linux-android34-clang++"

go build -trimpath \
  -o android/app/src/main/assets/grok2api \
  ./cmd/grok2api
```

## Installing the APK

### Method 1: Direct Install
1. Copy the APK file to your Android device
2. Enable "Install from unknown sources" in Settings > Security
3. Open the APK file to install

### Method 2: Using ADB
```bash
adb install android/app/build/outputs/apk/debug/app-debug.apk
```

### Method 3: Using Gradle
```bash
cd android
./gradlew installDebug
```

## Using the App

### First Launch
1. Open the Grok2API app
2. Tap **Start Server**
3. The app will create a default configuration file
4. The server will start on port 8000

### Accessing the Admin Console
1. Tap **Open Console** button
2. The WebView will open with the admin interface
3. Sign in with the bootstrap admin credentials (configured in config.yaml)

### Configuration
The app stores configuration in:
- **Config**: `$FILES_DIR/grok2api/config/config.yaml`
- **Data**: `$FILES_DIR/grok2api/`
- **Logs**: `$FILES_DIR/grok2api/server.log`

To edit the configuration:
1. Stop the server
2. Use a file manager to navigate to the config file
3. Edit it with a text editor
4. Start the server again

### Managing the Server
- **Start Server**: Starts the grok2api server in the background
- **Stop Server**: Stops the running server
- **Open Console**: Opens the admin console in a WebView
- **View Logs**: Opens the server log file

## Features

### Automatic Configuration
- Creates default config from assets on first run
- Stores config in app's private storage

### Background Service
- Server runs as a foreground service with notification
- Survives app closure (until explicitly stopped)
- Proper cleanup on app uninstall

### WebView Integration
- Built-in browser for the admin console
- No need to open external browser
- Works with localhost:8000

### Log Viewing
- View server logs directly from the app
- Opens with default text viewer

### Notifications
- Foreground service notification while server is running
- Shows server status in notification

## Customization

### Changing Port
Edit the port in `Grok2ApiService.java`:
```java
command.add("--listen");
command.add("127.0.0.1:8000");  // Change this line
```

### Changing Default Config
Replace `config.example.yaml` in the assets directory with your custom configuration.

### Adding More Features
The app can be extended to:
- Add settings screen for configuration
- Support multiple configuration profiles
- Add authentication to the app itself
- Implement push notifications
- Add dark mode support

## Troubleshooting

### "Binary not found" error
The Go binary failed to compile or copy to assets. Try:
```bash
cd backend
CGO_ENABLED=0 GOOS=android GOARCH=arm64 go build -o ../android/app/src/main/assets/grok2api ./cmd/grok2api
```

### "Permission denied" when starting server
Make sure the binary is executable:
```bash
chmod +x android/app/src/main/assets/grok2api
```

### App crashes on startup
Check the logcat output:
```bash
adb logcat | grep -i grok2api
```

### WebView doesn't load
- Make sure the server is running
- Check that the port matches (default: 8000)
- Try clearing app data and restarting

### Server starts but can't access console
- The server might be binding to the wrong IP
- Check the config.yaml file
- Try changing the listen address to `0.0.0.0:8000`

## Known Limitations

1. **Only arm64 supported**: Currently only builds for ARM64 devices
2. **No x86 support**: Won't work on Android emulators (x86)
3. **Static binary**: Without NDK, the binary is statically linked
4. **No auto-update**: Configuration changes require server restart
5. **WebView limitations**: Some admin console features might not work perfectly in WebView

## Building for Different Architectures

To build for other architectures, modify the GOARCH and GOOS:

| Architecture | GOOS | GOARCH |
|--------------|------|--------|
| ARM64 | android | arm64 |
| ARMv7 | android | arm |
| x86 | android | 386 |
| x86_64 | android | amd64 |

Example for ARMv7:
```bash
CGO_ENABLED=0 GOOS=android GOARCH=arm \
  go build -trimpath -ldflags="-s -w" \
  -o android/app/src/main/assets/grok2api \
  ./cmd/grok2api
```

## Security Considerations

1. **App Storage**: All data is stored in the app's private storage
2. **Network**: Server only listens on localhost by default
3. **Permissions**: App requests INTERNET and FOREGROUND_SERVICE permissions
4. **No Root**: App does not require root access
5. **Isolation**: Each app instance has its own isolated data

## Performance Tips

1. Use NDK for cross-compilation (better performance)
2. Build with CGO_ENABLED=1 for better system integration
3. Use a device with sufficient RAM (2GB+ recommended)
4. Close other apps to free up memory
5. Consider using a device with active cooling for long-running sessions

## Contributing

To contribute to the Android app:
1. Fork the repository
2. Make your changes in the `android/` directory
3. Test on a real Android device
4. Submit a pull request

## License

The Android app is licensed under the same terms as grok2api (MIT License).

## Support

For issues with the Android app:
1. Check the troubleshooting section above
2. Check the main grok2api [README](../../README.md)
3. Open an issue on GitHub with the tag `android`
