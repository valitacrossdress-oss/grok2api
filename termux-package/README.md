# grok2api Termux Package

This directory contains the files needed to build and install grok2api on **Termux** for Android.

## Overview

Termux is a powerful terminal emulator for Android that provides a Linux environment. This package allows you to run grok2api directly on your Android device without needing a rooted device or special permissions.

## Prerequisites

### On Your Android Device
1. Install **Termux** from [F-Droid](https://f-droid.org/en/packages/com.termux/) (recommended) or Google Play
2. Update Termux packages:
   ```bash
   pkg update && pkg upgrade
   ```
3. Install required dependencies:
   ```bash
   pkg install git golang nodejs openssl ca-certificates
   ```

### On Your Build Machine (Optional)
If you want to cross-compile the package on your computer:
- Linux or macOS
- Go 1.26+
- Docker (optional, for cleaner builds)

## Quick Start (Direct Installation in Termux)

The easiest way to get started is to clone and build directly in Termux:

```bash
# In Termux:
pkg install git golang nodejs

# Clone the repository
git clone https://github.com/valitacrossdress-oss/grok2api
cd grok2api

# Build and install (this will take a while)
./termux-package/build-termux.sh

# After build completes, install the binary
cp termux-package/build/grok2api-server $PREFIX/bin/
cp termux-package/grok2api.sh $PREFIX/bin/grok2api
chmod +x $PREFIX/bin/grok2api
```

## Using the Package

### Initialize Configuration
```bash
grok2api init
```

This creates a default configuration file at `$PREFIX/etc/grok2api/config.yaml`.

### Generate Secrets
```bash
grok2api secrets
```

This generates the JWT secret and credential encryption key that you need to add to your config.

### Edit Configuration
```bash
nano $PREFIX/etc/grok2api/config.yaml
```

Update the following in your config:
```yaml
secrets:
  jwtSecret: "your-generated-hex-value"
  credentialEncryptionKey: "your-generated-base64-key"

bootstrapAdmin:
  username: "admin"
  password: "your-strong-password"

server:
  listen: "0.0.0.0:8000"
```

### Start the Server
```bash
grok2api start
```

### Check Status
```bash
grok2api status
```

### View Logs
```bash
grok2api logs
# Or follow logs in real-time
tail -f $PREFIX/var/log/grok2api/server.log
```

### Stop the Server
```bash
grok2api stop
```

### Restart the Server
```bash
grok2api restart
```

## Accessing the Admin Console

After starting the server, open a web browser on your Android device and go to:
```
http://localhost:8000
```

If you want to access it from another device on your network, you'll need to:
1. Find your device's IP address
2. Make sure Termux has network access
3. Access it via `http://<your-device-ip>:8000`

> **Note**: Android may block incoming connections. You may need to configure your firewall or use Termux's built-in HTTP server.

## Building the Package

### Method 1: Build in Termux (Recommended)

```bash
# Install build dependencies
pkg install git golang nodejs

# Clone and build
cd ~/grok2api
./termux-package/build-termux.sh

# Install the built files
cp termux-package/build/grok2api-server $PREFIX/bin/
cp termux-package/grok2api.sh $PREFIX/bin/grok2api
chmod +x $PREFIX/bin/grok2api
```

### Method 2: Cross-Compile on Your Computer

```bash
# Clone the repository
git clone https://github.com/valitacrossdress-oss/grok2api
cd grok2api/termux-package

# Make the build script executable
chmod +x build-termux.sh

# Run the build
./build-termux.sh

# The package will be created in termux-package/
# Copy it to your Android device and extract it
```

### Method 3: Using Docker (Clean Build Environment)

```bash
# Build the Docker image
docker build -t grok2api-termux-builder .

# Run the build
docker run --rm -v $(pwd)/output:/output grok2api-termux-builder
```

## Package Structure

```
termux-package/
├── build-termux.sh      # Main build script
├── control             # Termux package control file
├── grok2api.sh         # Wrapper script for Termux
├── grok2api.subpackage.sh  # Termux subpackage definition
└── README.md           # This file
```

## Directory Locations in Termux

| Purpose | Location |
|---------|----------|
| Binary | `$PREFIX/bin/grok2api` |
| Server Binary | `$PREFIX/bin/grok2api-server` |
| Configuration | `$PREFIX/etc/grok2api/config.yaml` |
| Data | `$PREFIX/var/lib/grok2api/` |
| Logs | `$PREFIX/var/log/grok2api/` |
| PID File | `$PREFIX/var/run/grok2api.pid` |
| Frontend Assets | `$PREFIX/share/grok2api/frontend/` |

## Troubleshooting

### "Permission denied" when starting
Make sure the binary is executable:
```bash
chmod +x $PREFIX/bin/grok2api
chmod +x $PREFIX/bin/grok2api-server
```

### Go build fails with "unknown runtime"
Make sure you're using Go 1.26+ and that CGO is disabled:
```bash
CGO_ENABLED=0 GOOS=linux GOARCH=arm64 go build
```

### Frontend build fails
The frontend requires Node.js and pnpm:
```bash
pkg install nodejs
npm install -g pnpm
```

### Port already in use
Check what's using port 8000:
```bash
ss -tulnp | grep 8000
```

Then either stop the conflicting service or change the port in your config:
```yaml
server:
  listen: "0.0.0.0:8080"
```

### Can't access from browser
- Make sure the server is running: `grok2api status`
- Check the logs: `grok2api logs`
- Try accessing from Termux: `curl http://localhost:8000`
- If using Chrome, try Firefox or the Termux browser

## Creating a Termux .deb Package

For advanced users who want to create a proper Termux package:

1. Set up the Termux package builder:
   ```bash
   git clone https://github.com/termux/termux-packages
   cd termux-packages
   ```

2. Create a new package directory:
   ```bash
   mkdir -p packages/grok2api
   cd packages/grok2api
   ```

3. Copy the files from this directory:
   - `control`
   - `grok2api.subpackage.sh` (as `build.sh`)
   - Any post-install scripts

4. Build the package:
   ```bash
   ./scripts/build-package.sh -a grok2api
   ```

5. The .deb file will be created in `debs/`

## Uninstalling

To completely remove grok2api:

```bash
# Stop the server
grok2api stop

# Remove the binary
rm -f $PREFIX/bin/grok2api
rm -f $PREFIX/bin/grok2api-server

# Remove data (optional - this will delete your config and data)
rm -rf $PREFIX/etc/grok2api
rm -rf $PREFIX/var/lib/grok2api
rm -rf $PREFIX/var/log/grok2api
rm -rf $PREFIX/share/grok2api

# Remove PID file
rm -f $PREFIX/var/run/grok2api.pid
```

## Performance Considerations

- Running a Go server on Android may use more battery
- For best performance, use a device with a powerful processor
- Close other apps to free up memory
- Consider using a device with active cooling

## Security Notes

- The server runs with your user permissions
- Keep your config.yaml secure (contains secrets)
- Don't expose the server to the internet without proper security
- Use HTTPS if accessing from other devices
- The default configuration listens on all interfaces (0.0.0.0)

## Updates

To update grok2api:
1. Stop the server: `grok2api stop`
2. Pull the latest changes: `cd ~/grok2api && git pull`
3. Rebuild: `./termux-package/build-termux.sh`
4. Reinstall the binary
5. Start the server: `grok2api start`

## Support

For issues with this Termux package:
1. Check the troubleshooting section above
2. Check the main grok2api [README](../../README.md)
3. Open an issue on GitHub

## License

This Termux package is licensed under the same terms as grok2api (MIT License).
