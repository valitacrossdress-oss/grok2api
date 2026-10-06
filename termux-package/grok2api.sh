#!/bin/bash
# grok2api - Termux wrapper script
# This script manages the grok2api server in Termux

set -e

# Configuration
APP_NAME="grok2api"
BIN_NAME="grok2api"  # The actual Go binary
CONFIG_DIR="$PREFIX/etc/grok2api"
DATA_DIR="$PREFIX/var/lib/grok2api"
LOG_DIR="$PREFIX/var/log/grok2api"
PID_FILE="$PREFIX/var/run/grok2api.pid"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Check if running as root
if [ "$(whoami)" = "root" ]; then
    echo -e "${RED}Error: Do not run as root. Use a regular Termux user.${NC}"
    exit 1
fi

# Create directories
mkdir -p "$CONFIG_DIR" "$DATA_DIR" "$LOG_DIR" "$(dirname "$PID_FILE")"

# Function to get the actual binary path
get_bin_path() {
    # First try the installed binary
    if [ -x "$PREFIX/bin/$BIN_NAME" ]; then
        echo "$PREFIX/bin/$BIN_NAME"
        return 0
    fi
    
    # Fall back to the script's directory
    local script_dir="$(cd "$(dirname "$0")" && pwd)"
    if [ -x "$script_dir/$BIN_NAME" ]; then
        echo "$script_dir/$BIN_NAME"
        return 0
    fi
    
    echo -e "${RED}Error: $BIN_NAME binary not found.${NC}"
    echo "Please install the grok2api package first."
    exit 1
}

# Function to check if server is running
is_running() {
    [ -f "$PID_FILE" ] && kill -0 "$(cat "$PID_FILE")" 2>/dev/null
    return $?
}

# Function to start the server
start_server() {
    local config_file="$CONFIG_DIR/config.yaml"
    local bin_path=$(get_bin_path)
    
    # Check for config file
    if [ ! -f "$config_file" ]; then
        echo -e "${YELLOW}Warning: Config file not found at $config_file${NC}"
        echo "Creating default config from example..."
        if [ -f "$PREFIX/share/grok2api/config.example.yaml" ]; then
            cp "$PREFIX/share/grok2api/config.example.yaml" "$config_file"
            echo -e "${GREEN}Created default config at $config_file${NC}"
            echo "Please edit it and add your secrets and bootstrap admin credentials."
            echo "Then run '$0 start' again."
            exit 1
        fi
    fi
    
    # Check if already running
    if is_running; then
        echo -e "${YELLOW}$APP_NAME is already running (PID: $(cat "$PID_FILE"))${NC}"
        return 0
    fi
    
    # Start the server
    echo -e "${GREEN}Starting $APP_NAME...${NC}"
    echo "Config: $config_file"
    echo "Data dir: $DATA_DIR"
    echo "Log dir: $LOG_DIR"
    
    # Run in background with logging
    nohup "$bin_path" --config "$config_file" --listen "0.0.0.0:8000" \
        >> "$LOG_DIR/server.log" 2>&1 &
    
    # Save PID
    echo $! > "$PID_FILE"
    
    echo -e "${GREEN}$APP_NAME started successfully!${NC}"
    echo "PID: $!"
    echo "Access the admin console at: http://localhost:8000"
    echo "View logs: tail -f $LOG_DIR/server.log"
}

# Function to stop the server
stop_server() {
    if ! is_running; then
        echo -e "${YELLOW}$APP_NAME is not running${NC}"
        return 0
    fi
    
    echo -e "${GREEN}Stopping $APP_NAME...${NC}"
    local pid=$(cat "$PID_FILE")
    kill "$pid" 2>/dev/null
    
    # Wait for graceful shutdown
    local count=0
    while is_running && [ $count -lt 10 ]; do
        sleep 1
        count=$((count + 1))
    done
    
    if is_running; then
        echo -e "${YELLOW}Server did not stop gracefully, killing...${NC}"
        kill -9 "$pid" 2>/dev/null
    fi
    
    rm -f "$PID_FILE"
    echo -e "${GREEN}$APP_NAME stopped${NC}"
}

# Function to show status
show_status() {
    if is_running; then
        local pid=$(cat "$PID_FILE")
        echo -e "${GREEN}$APP_NAME is running${NC}"
        echo "PID: $pid"
        echo "Config: $CONFIG_DIR/config.yaml"
        echo "Data dir: $DATA_DIR"
        echo "Log file: $LOG_DIR/server.log"
        echo "Uptime: $(ps -o etimes= -p "$pid" 2>/dev/null || echo 'unknown') seconds"
    else
        echo -e "${RED}$APP_NAME is not running${NC}"
        if [ -f "$PID_FILE" ]; then
            echo "Stale PID file found: $PID_FILE"
            echo "You may want to remove it manually."
        fi
    fi
}

# Function to show logs
show_logs() {
    local lines=${1:-50}
    if [ -f "$LOG_DIR/server.log" ]; then
        tail -n "$lines" "$LOG_DIR/server.log"
    else
        echo -e "${YELLOW}No log file found at $LOG_DIR/server.log${NC}"
    fi
}

# Function to initialize the configuration
init_config() {
    local config_file="$CONFIG_DIR/config.yaml"
    
    if [ -f "$config_file" ]; then
        echo -e "${YELLOW}Config file already exists at $config_file${NC}"
        echo "Backup your existing config before proceeding."
        read -p "Overwrite existing config? [y/N] " -r
        if [[ ! $REPLY =~ ^[Yy]$ ]]; then
            echo "Aborted."
            exit 1
        fi
    fi
    
    if [ -f "$PREFIX/share/grok2api/config.example.yaml" ]; then
        cp "$PREFIX/share/grok2api/config.example.yaml" "$config_file"
        echo -e "${GREEN}Created config file at $config_file${NC}"
        echo ""
        echo "Next steps:"
        echo "1. Edit $config_file and add your secrets:"
        echo "   - Generate JWT secret: openssl rand -hex 32"
        echo "   - Generate encryption key: openssl rand -base64 32"
        echo "   - Set bootstrap admin username and password"
        echo ""
        echo "2. Run '$0 start' to start the server"
    else
        echo -e "${RED}Error: Could not find example config file${NC}"
        exit 1
    fi
}

# Function to generate secrets
generate_secrets() {
    echo -e "${GREEN}Generating secrets...${NC}"
    echo ""
    echo "JWT Secret (add to config.yaml as jwtSecret):"
    openssl rand -hex 32
    echo ""
    echo "Credential Encryption Key (add to config.yaml as credentialEncryptionKey):"
    openssl rand -base64 32
    echo ""
}

# Main command handling
case "${1:-help}" in
    start)
        start_server
        ;;
    stop)
        stop_server
        ;;
    restart)
        stop_server
        start_server
        ;;
    status)
        show_status
        ;;
    logs)
        show_logs "${2:-50}"
        ;;
    init)
        init_config
        ;;
    secrets)
        generate_secrets
        ;;
    help|--help|-h|"")
        echo "Usage: grok2api [command]"
        echo ""
        echo "Commands:"
        echo "  start        Start the grok2api server"
        echo "  stop         Stop the grok2api server"
        echo "  restart      Restart the grok2api server"
        echo "  status       Show server status"
        echo "  logs [N]     Show last N lines of logs (default: 50)"
        echo "  init         Initialize configuration file"
        echo "  secrets      Generate JWT and encryption secrets"
        echo "  help         Show this help message"
        echo ""
        echo "Configuration:"
        echo "  Config file: $CONFIG_DIR/config.yaml"
        echo "  Data dir:    $DATA_DIR"
        echo "  Log dir:     $LOG_DIR"
        ;;
    *)
        echo -e "${RED}Unknown command: $1${NC}"
        echo "Use '$0 help' for usage information."
        exit 1
        ;;
esac
