#!/bin/bash
set -e
/usr/local/bin/banner.sh

# Default values
readonly DEFAULT_PUID=1000
readonly DEFAULT_PGID=1000
readonly DEFAULT_PORT=8060
readonly DEFAULT_PROTOCOL="SHTTP"
readonly FIRST_RUN_FILE="/tmp/first_run_complete"

# Fetch default configuration values
readonly DEFAULT_LIMIT_VALUE=0
readonly DEFAULT_TIMEOUT=30000
readonly DEFAULT_MAX_REDIRECTS=5
readonly DEFAULT_USER_AGENT="Mozilla/5.0 (compatible; FetchMCP/1.0)"

# Function to trim whitespace using parameter expansion
trim() {
    local var="$*"
    var="${var#"${var%%[![:space:]]*}"}"
    var="${var%"${var##*[![:space:]]}"}"
    printf '%s' "$var"
}

# Validate positive integers
is_positive_int() {
    [[ "$1" =~ ^[0-9]+$ ]] && [ "$1" -gt 0 ]
}

# Validate non-negative integers (for limit which can be 0)
is_non_negative_int() {
    [[ "$1" =~ ^[0-9]+$ ]]
}

# Validate directory path
validate_directory() {
    local dir="$1"
    [[ -n "$dir" ]] && [[ "$dir" =~ ^/ ]] && [[ ! "$dir" =~ \.\. ]] && [[ "${#dir}" -le 255 ]]
}

# First run handling
handle_first_run() {
    local uid_gid_changed=0

    # Handle PUID/PGID logic
    if [[ -z "$PUID" && -z "$PGID" ]]; then
        PUID="$DEFAULT_PUID"
        PGID="$DEFAULT_PGID"
        echo "PUID and PGID not set. Using defaults: PUID=$PUID, PGID=$PGID"
    elif [[ -n "$PUID" && -z "$PGID" ]]; then
        if is_positive_int "$PUID"; then
            PGID="$PUID"
        else
            echo "Invalid PUID: '$PUID'. Using default: $DEFAULT_PUID"
            PUID="$DEFAULT_PUID"
            PGID="$DEFAULT_PGID"
        fi
    elif [[ -z "$PUID" && -n "$PGID" ]]; then
        if is_positive_int "$PGID"; then
            PUID="$PGID"
        else
            echo "Invalid PGID: '$PGID'. Using default: $DEFAULT_PGID"
            PUID="$DEFAULT_PUID"
            PGID="$DEFAULT_PGID"
        fi
    else
        if ! is_positive_int "$PUID"; then
            echo "Invalid PUID: '$PUID'. Using default: $DEFAULT_PUID"
            PUID="$DEFAULT_PUID"
        fi
        
        if ! is_positive_int "$PGID"; then
            echo "Invalid PGID: '$PGID'. Using default: $DEFAULT_PGID"
            PGID="$DEFAULT_PGID"
        fi
    fi

    # Check existing UID/GID conflicts
    local current_user current_group
    current_user=$(id -un "$PUID" 2>/dev/null || true)
    current_group=$(getent group "$PGID" | cut -d: -f1 2>/dev/null || true)

    [[ -n "$current_user" && "$current_user" != "node" ]] &&
        echo "Warning: UID $PUID already in use by $current_user - may cause permission issues"

    [[ -n "$current_group" && "$current_group" != "node" ]] &&
        echo "Warning: GID $PGID already in use by $current_group - may cause permission issues"

    # Modify UID/GID if needed
    if [ "$(id -u node)" -ne "$PUID" ]; then
        if usermod -o -u "$PUID" node 2>/dev/null; then
            uid_gid_changed=1
        else
            echo "Error: Failed to change UID to $PUID. Using existing UID $(id -u node)"
            PUID=$(id -u node)
        fi
    fi

    if [ "$(id -g node)" -ne "$PGID" ]; then
        if groupmod -o -g "$PGID" node 2>/dev/null; then
            uid_gid_changed=1
        else
            echo "Error: Failed to change GID to $PGID. Using existing GID $(id -g node)"
            PGID=$(id -g node)
        fi
    fi

    [ "$uid_gid_changed" -eq 1 ] && echo "Updated UID/GID to PUID=$PUID, PGID=$PGID"
    touch "$FIRST_RUN_FILE"
}

# Validate and set PORT
validate_port() {
    # Ensure PORT has a value
    PORT=${PORT:-$DEFAULT_PORT}
    
    # Check if PORT is a positive integer
    if ! is_positive_int "$PORT"; then
        echo "Invalid PORT: '$PORT'. Using default: $DEFAULT_PORT"
        PORT="$DEFAULT_PORT"
    elif [ "$PORT" -lt 1 ] || [ "$PORT" -gt 65535 ]; then
        echo "Invalid PORT: '$PORT'. Using default: $DEFAULT_PORT"
        PORT="$DEFAULT_PORT"
    fi
    
    # Check if port is privileged
    if [ "$PORT" -lt 1024 ] && [ "$(id -u)" -ne 0 ]; then
        echo "Warning: Port $PORT is privileged and might require root"
    fi
}

# Build MCP server command with environment variables
build_mcp_server_cmd() {
    # Start with the base command
    MCP_SERVER_CMD="npx -y fetch-mcp"
    
    # Build environment variable arguments array
    FETCH_ENV_ARGS=()
    
    # Add DEFAULT_LIMIT (optional)
    if [[ -n "${DEFAULT_LIMIT:-}" ]]; then
        FETCH_ENV_ARGS+=(env "DEFAULT_LIMIT=$DEFAULT_LIMIT")
    fi
    
    # Add FETCH_TIMEOUT (optional)
    if [[ -n "${FETCH_TIMEOUT:-}" ]]; then
        FETCH_ENV_ARGS+=(env "FETCH_TIMEOUT=$FETCH_TIMEOUT")
    fi
    
    # Add MAX_REDIRECTS (optional)
    if [[ -n "${MAX_REDIRECTS:-}" ]]; then
        FETCH_ENV_ARGS+=(env "MAX_REDIRECTS=$MAX_REDIRECTS")
    fi
    
    # Add USER_AGENT (optional)
    if [[ -n "${USER_AGENT:-}" ]]; then
        FETCH_ENV_ARGS+=(env "USER_AGENT=$USER_AGENT")
    fi
    
    # Add FOLLOW_REDIRECTS flag (optional)
    if [[ -n "${FOLLOW_REDIRECTS:-}" ]]; then
        FETCH_ENV_ARGS+=(env "FOLLOW_REDIRECTS=$FOLLOW_REDIRECTS")
    fi
    
    # Add VERIFY_SSL flag (optional)
    if [[ -n "${VERIFY_SSL:-}" ]]; then
        FETCH_ENV_ARGS+=(env "VERIFY_SSL=$VERIFY_SSL")
    fi
    
    # Combine env args with the base command
    if [[ ${#FETCH_ENV_ARGS[@]} -gt 0 ]]; then
        MCP_SERVER_CMD="${FETCH_ENV_ARGS[@]} $MCP_SERVER_CMD"
    fi
}

# Validate CORS patterns
validate_cors() {
    CORS_ARGS=()
    ALLOW_ALL_CORS=false
    local cors_value

    if [[ -n "${CORS:-}" ]]; then
        IFS=',' read -ra CORS_VALUES <<< "$CORS"
        for cors_value in "${CORS_VALUES[@]}"; do
            cors_value=$(trim "$cors_value")
            [[ -z "$cors_value" ]] && continue

            if [[ "$cors_value" =~ ^(all|\*)$ ]]; then
                ALLOW_ALL_CORS=true
                CORS_ARGS=(--cors)
                echo "Caution! CORS allowing all origins - security risk in production!"
                break
            elif [[ "$cors_value" =~ ^/.*/$ ]] ||
                 [[ "$cors_value" =~ ^https?:// ]] ||
                 [[ "$cors_value" =~ ^[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+(:[0-9]+)?$ ]] ||
                 [[ "$cors_value" =~ ^https?://[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+(:[0-9]+)?$ ]] ||
                 [[ "$cors_value" =~ ^[a-zA-Z0-9][a-zA-Z0-9.-]+\.[a-zA-Z]{2,}(:[0-9]+)?$ ]]
            then
                CORS_ARGS+=(--cors "$cors_value")
            else
                echo "Warning: Invalid CORS pattern '$cors_value' - skipping"
            fi
        done
    fi
}

# Generate client configuration example
generate_client_config_example() {
    echo ""
    echo "=== FETCH MCP TOOL LIST ==="
    echo "To enable auto-approval in your MCP client, add this to your configuration:"
    echo ""
    echo "\"TOOL LIST\": ["
    echo "  \"fetch_html\","
    echo "  \"fetch_json\","
    echo "  \"fetch_txt\","
    echo "  \"fetch_markdown\""
    echo "]"
    echo ""
    echo "=== END TOOL LIST ==="
    echo ""
}

# Validate and set Fetch environment variables
validate_fetch_env() {
    # Note: Fetch MCP doesn't require an API key - it's open access
    
    # Validate DEFAULT_LIMIT if set (optional)
    if [[ -n "${DEFAULT_LIMIT:-}" ]]; then
        if ! is_non_negative_int "$DEFAULT_LIMIT"; then
            echo "⚠️  Warning: Invalid DEFAULT_LIMIT: '$DEFAULT_LIMIT'. Using default: $DEFAULT_LIMIT_VALUE"
            export DEFAULT_LIMIT="$DEFAULT_LIMIT_VALUE"
        fi
    fi

    # Validate FETCH_TIMEOUT if set (optional)
    if [[ -n "${FETCH_TIMEOUT:-}" ]]; then
        if ! is_positive_int "$FETCH_TIMEOUT"; then
            echo "⚠️  Warning: Invalid FETCH_TIMEOUT: '$FETCH_TIMEOUT'. Using default: $DEFAULT_TIMEOUT"
            export FETCH_TIMEOUT="$DEFAULT_TIMEOUT"
        elif [ "$FETCH_TIMEOUT" -lt 1000 ] || [ "$FETCH_TIMEOUT" -gt 300000 ]; then
            echo "⚠️  Warning: FETCH_TIMEOUT out of reasonable range (1000-300000ms). Using default: $DEFAULT_TIMEOUT"
            export FETCH_TIMEOUT="$DEFAULT_TIMEOUT"
        fi
    fi

    # Validate MAX_REDIRECTS if set (optional)
    if [[ -n "${MAX_REDIRECTS:-}" ]]; then
        if ! is_non_negative_int "$MAX_REDIRECTS"; then
            echo "⚠️  Warning: Invalid MAX_REDIRECTS: '$MAX_REDIRECTS'. Using default: $DEFAULT_MAX_REDIRECTS"
            export MAX_REDIRECTS="$DEFAULT_MAX_REDIRECTS"
        elif [ "$MAX_REDIRECTS" -gt 20 ]; then
            echo "⚠️  Warning: MAX_REDIRECTS too high ($MAX_REDIRECTS). Using default: $DEFAULT_MAX_REDIRECTS"
            export MAX_REDIRECTS="$DEFAULT_MAX_REDIRECTS"
        fi
    fi

    # Validate boolean flags if set (optional)
    if [[ -n "${FOLLOW_REDIRECTS:-}" ]]; then
        local follow_redirects_lower=$(echo "$FOLLOW_REDIRECTS" | tr '[:upper:]' '[:lower:]')
        if [[ "$follow_redirects_lower" != "true" && "$follow_redirects_lower" != "false" ]]; then
            echo "⚠️  Warning: Invalid FOLLOW_REDIRECTS: '$FOLLOW_REDIRECTS'. Using true."
            export FOLLOW_REDIRECTS="true"
        fi
    fi

    if [[ -n "${VERIFY_SSL:-}" ]]; then
        local verify_ssl_lower=$(echo "$VERIFY_SSL" | tr '[:upper:]' '[:lower:]')
        if [[ "$verify_ssl_lower" != "true" && "$verify_ssl_lower" != "false" ]]; then
            echo "⚠️  Warning: Invalid VERIFY_SSL: '$VERIFY_SSL'. Using true."
            export VERIFY_SSL="true"
        fi
    fi

    return 0
}

# Display Fetch configuration summary
display_config_summary() {
    echo ""
    echo "=== FETCH MCP SERVER CONFIGURATION ==="
    
    # Show fetch limits
    local limit_display="${DEFAULT_LIMIT:-$DEFAULT_LIMIT_VALUE}"
    if [[ "$limit_display" == "0" ]]; then
        echo "📦 Size Limit: Unlimited"
    else
        echo "📦 Size Limit: $limit_display bytes"
    fi
    
    # Show timeout if customized
    local timeout_display="${FETCH_TIMEOUT:-$DEFAULT_TIMEOUT}"
    if [[ "$timeout_display" != "$DEFAULT_TIMEOUT" ]]; then
        echo "⏱️  Timeout: ${timeout_display}ms"
    fi
    
    # Show max redirects if customized
    local redirects_display="${MAX_REDIRECTS:-$DEFAULT_MAX_REDIRECTS}"
    if [[ "$redirects_display" != "$DEFAULT_MAX_REDIRECTS" ]]; then
        echo "🔄 Max Redirects: $redirects_display"
    fi
    
    # Show user agent if customized
    if [[ -n "${USER_AGENT:-}" ]]; then
        echo "🌐 User Agent: $USER_AGENT"
    fi
    
    # Show optional flags if enabled/disabled
    if [[ "${FOLLOW_REDIRECTS:-true}" == "false" ]]; then
        echo "⛔ Follow Redirects: disabled"
    fi
    
    if [[ "${VERIFY_SSL:-true}" == "false" ]]; then
        echo "⚠️  SSL Verification: disabled (not recommended for production)"
    fi
    
    # Always show server configuration
    echo "📡 Server:"
    echo "   - Port: $PORT"
    echo "   - Protocol: $PROTOCOL_DISPLAY"
    
    echo "=========================================="
    echo ""
}

# Main execution
main() {
    # Trim all input parameters
    [[ -n "${PUID:-}" ]] && PUID=$(trim "$PUID")
    [[ -n "${PGID:-}" ]] && PGID=$(trim "$PGID")
    [[ -n "${PORT:-}" ]] && PORT=$(trim "$PORT")
    [[ -n "${PROTOCOL:-}" ]] && PROTOCOL=$(trim "$PROTOCOL")
    [[ -n "${CORS:-}" ]] && CORS=$(trim "$CORS")
    
    # Trim Fetch specific environment variables
    [[ -n "${DEFAULT_LIMIT:-}" ]] && DEFAULT_LIMIT=$(trim "$DEFAULT_LIMIT")
    [[ -n "${FETCH_TIMEOUT:-}" ]] && FETCH_TIMEOUT=$(trim "$FETCH_TIMEOUT")
    [[ -n "${MAX_REDIRECTS:-}" ]] && MAX_REDIRECTS=$(trim "$MAX_REDIRECTS")
    [[ -n "${USER_AGENT:-}" ]] && USER_AGENT=$(trim "$USER_AGENT")
    [[ -n "${FOLLOW_REDIRECTS:-}" ]] && FOLLOW_REDIRECTS=$(trim "$FOLLOW_REDIRECTS")
    [[ -n "${VERIFY_SSL:-}" ]] && VERIFY_SSL=$(trim "$VERIFY_SSL")

    # First run handling
    if [[ ! -f "$FIRST_RUN_FILE" ]]; then
        handle_first_run
    fi

    # Validate configurations
    validate_port
    validate_cors
    
    # Validate Fetch environment
    if ! validate_fetch_env; then
        echo "❌ Fetch MCP Server cannot start due to configuration errors."
        exit 1
    fi

    # Build MCP server command with environment variables
    build_mcp_server_cmd

    # Generate client configuration example
    generate_client_config_example

    # Protocol selection
    local PROTOCOL_UPPER=${PROTOCOL:-$DEFAULT_PROTOCOL}
    PROTOCOL_UPPER=${PROTOCOL_UPPER^^}

    case "$PROTOCOL_UPPER" in
        "SHTTP"|"STREAMABLEHTTP")
            CMD_ARGS=(npx --yes supergateway --port "$PORT" --streamableHttpPath /mcp --outputTransport streamableHttp "${CORS_ARGS[@]}" --healthEndpoint /healthz --stdio "$MCP_SERVER_CMD")
            PROTOCOL_DISPLAY="SHTTP/streamableHttp"
            ;;
        "SSE")
            CMD_ARGS=(npx --yes supergateway --port "$PORT" --ssePath /sse --outputTransport sse "${CORS_ARGS[@]}" --healthEndpoint /healthz --stdio "$MCP_SERVER_CMD")
            PROTOCOL_DISPLAY="SSE/Server-Sent Events"
            ;;
        "WS"|"WEBSOCKET")
            CMD_ARGS=(npx --yes supergateway --port "$PORT" --messagePath /message --outputTransport ws "${CORS_ARGS[@]}" --healthEndpoint /healthz --stdio "$MCP_SERVER_CMD")
            PROTOCOL_DISPLAY="WS/WebSocket"
            ;;
        *)
            echo "Invalid PROTOCOL: '$PROTOCOL'. Using default: $DEFAULT_PROTOCOL"
            CMD_ARGS=(npx --yes supergateway --port "$PORT" --streamableHttpPath /mcp --outputTransport streamableHttp "${CORS_ARGS[@]}" --healthEndpoint /healthz --stdio "$MCP_SERVER_CMD")
            PROTOCOL_DISPLAY="SHTTP/streamableHttp"
            ;;
    esac

    # Display configuration summary
    display_config_summary

    # Debug mode handling
    case "${DEBUG_MODE:-}" in
        [1YyTt]*|[Oo][Nn]|[Yy][Ee][Ss]|[Ee][Nn][Aa][Bb][Ll][Ee]*)
            echo "DEBUG MODE: Installing nano and pausing container"
            apk add --no-cache nano 2>/dev/null || echo "Warning: Failed to install nano"
            echo "Container paused for debugging. Exec into container to investigate."
            exec tail -f /dev/null
            ;;
        *)
            # Normal execution
            echo "🚀 Launching Fetch MCP Server with protocol: $PROTOCOL_DISPLAY on port: $PORT"
            
            # Check for npx availability
            if ! command -v npx &>/dev/null; then
                echo "❌ Error: npx not available. Cannot start server."
                exit 1
            fi

            # Display the actual command being executed for debugging
            if [[ "${DEBUG_MODE:-}" == "verbose" ]]; then
                echo "🔧 DEBUG - Final command: ${CMD_ARGS[*]}"
            fi

            if [ "$(id -u)" -eq 0 ]; then
                echo "👤 Running as user: node (PUID: $PUID, PGID: $PGID)"
                exec su-exec node "${CMD_ARGS[@]}"
            else
                if [ "$PORT" -lt 1024 ]; then
                    echo "❌ Error: Cannot bind to privileged port $PORT without root"
                    exit 1
                fi
                echo "👤 Running as current user"
                exec "${CMD_ARGS[@]}"
            fi
            ;;
    esac
}

# Run the script with error handling
if main "$@"; then
    exit 0
else
    echo "❌ Fetch MCP Server failed to start"
    exit 1
fi
