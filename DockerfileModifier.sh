#!/bin/bash
set -ex
# Set variables first
REPO_NAME='fetch-mcp'
BASE_IMAGE=$(cat ./build_data/base-image 2>/dev/null || echo "node:current-alpine")
FETCH_MCP_VERSION=$(cat ./build_data/version 2>/dev/null || exit 1)
# mcp-proxy: stdio<->StreamableHTTP/SSE bridge. Replaces supergateway.
# Stateful by default (one stdio child shared across all sessions) - avoids
# the spawn-per-request memory leak that affected supergateway in stateless
# mode (supercorp-ai/supergateway#108).
MCP_PROXY_PKG=$(cat ./build_data/mcp_proxy_version 2>/dev/null || echo "mcp-proxy")
FETCH_MCP_REPO="mcp-fetch-server"
FETCH_MCP_PKG="${FETCH_MCP_REPO}@${FETCH_MCP_VERSION}"
DOCKERFILE_NAME="Dockerfile.$REPO_NAME"
OTHER_NPM_DEPENDENCIES=$(cat ./build_data/npm_dependencies 2>/dev/null || echo "")

# Create a temporary file safely
TEMP_FILE=$(mktemp "${DOCKERFILE_NAME}.XXXXXX") || {
    echo "Error creating temporary file" >&2
    exit 1
}

# Check if this is a publication build
if [ -e ./build_data/publication ]; then
    # For publication builds, create a minimal Dockerfile that just tags the existing image
    {
        echo "ARG BASE_IMAGE=$BASE_IMAGE"
        echo "FROM $BASE_IMAGE"
    } > "$TEMP_FILE"
else
    # Write the Dockerfile content to the temporary file first
    {
        echo "ARG BASE_IMAGE=$BASE_IMAGE"
        cat << EOF
FROM $BASE_IMAGE AS build

# Author info:
LABEL org.opencontainers.image.authors="MOHAMMAD MEKAYEL ANIK <mekayel.anik@gmail.com>"
LABEL org.opencontainers.image.description="Fetch MCP Server - Fetch web content in HTML, JSON, text, and Markdown formats"
LABEL org.opencontainers.image.source="https://github.com/mekayelanik/fetch-mcp-docker"

# Copy the entrypoint script into the container and make it executable
COPY ./resources/ /usr/local/bin/
RUN chmod +x /usr/local/bin/entrypoint.sh /usr/local/bin/banner.sh /usr/local/bin/healthcheck.sh \\
    && mkdir -p /etc/haproxy \\
    && mv -vf /usr/local/bin/haproxy.cfg.template /etc/haproxy/haproxy.cfg.template

# Install required APK packages
RUN echo "https://dl-cdn.alpinelinux.org/alpine/edge/main" > /etc/apk/repositories && \\
    echo "https://dl-cdn.alpinelinux.org/alpine/edge/community" >> /etc/apk/repositories && \\
    apk --update-cache --no-cache add bash shadow su-exec tzdata bc haproxy netcat-openbsd openssl ca-certificates curl python3 py3-pip && \\
    rm -rf /var/cache/apk/*

# Create node user with specific UID/GID if they don't exist
RUN if ! id -u node >/dev/null 2>&1; then \\
        addgroup -g 1000 node && \\
        adduser -u 1000 -G node -D node; \\
    fi

# Install Fetch MCP server
RUN echo "Installing Fetch MCP server: ${FETCH_MCP_PKG}" && \\
    npm install -g ${FETCH_MCP_PKG} --loglevel verbose && \\
    echo "Package installed successfully"

# Install mcp-proxy (replaces supergateway). Pure-Python via pip.
RUN --mount=type=cache,target=/root/.cache/pip \\
    echo "Installing ${MCP_PROXY_PKG}..." && \\
    pip install --no-cache-dir --break-system-packages ${MCP_PROXY_PKG} && \\
    mcp-proxy --version || true && \\
    npm cache clean --force

EOF

        # Add Other NPM Dependencies if they exist
        if [ -n "$OTHER_NPM_DEPENDENCIES" ]; then
            cat << EOF
# Install Other NPM Dependencies
RUN echo "Installing other NPM Dependencies: ${OTHER_NPM_DEPENDENCIES}" && \\
    npm install -g ${OTHER_NPM_DEPENDENCIES} --loglevel verbose && \\
    echo "Packages installed successfully"

EOF
        fi

        cat << EOF
# Use an ARG for the default port
ARG PORT=8060

# Set an ENV variable from the ARG for runtime
ENV PORT=\${PORT}

# Fetch specific environment variables with defaults
ENV DEFAULT_LIMIT=0
ENV FETCH_TIMEOUT=30000
ENV MAX_REDIRECTS=5

# mcp-proxy and HAProxy concurrency defaults (overridable at runtime).
ENV MCP_PROXY_STATELESS=false
ENV FETCH_MAX_MEM_MB=4096
ENV HAPROXY_FRONTEND_MAXCONN=64
ENV HAPROXY_SERVER_MAXCONN=16

LABEL org.opencontainers.image.description="Fetch MCP Server (mcp-proxy stdio<->HTTP bridge)"

# Expose the port
EXPOSE \${PORT}

# L7 health check: HAProxy answers /healthz locally
HEALTHCHECK --interval=30s --timeout=10s --start-period=60s --retries=3 \\
    CMD ["/usr/local/bin/healthcheck.sh"]

# Set the entrypoint
ENTRYPOINT ["/usr/local/bin/entrypoint.sh"]

EOF
    } > "$TEMP_FILE"
fi

# Atomically replace the target file with the temporary file
if mv -f "$TEMP_FILE" "$DOCKERFILE_NAME"; then
    echo "Dockerfile for $REPO_NAME created successfully."
else
    echo "Error: Failed to create Dockerfile for $REPO_NAME" >&2
    rm -f "$TEMP_FILE"
    exit 1
fi
