# Fetch MCP Server
### Multi-Architecture Docker Image for Distributed Deployment

<div align="left">

<img alt="fetch-mcp" src="https://img.shields.io/badge/Fetch-MCP-FF6B6B?style=for-the-badge&logo=safari&logoColor=white" width="400">

[![Docker Pulls](https://img.shields.io/docker/pulls/mekayelanik/fetch-mcp.svg?style=flat-square)](https://hub.docker.com/r/mekayelanik/fetch-mcp)
[![Docker Stars](https://img.shields.io/docker/stars/mekayelanik/fetch-mcp.svg?style=flat-square)](https://hub.docker.com/r/mekayelanik/fetch-mcp)
[![License](https://img.shields.io/badge/license-GPL-blue.svg?style=flat-square)](https://raw.githubusercontent.com/MekayelAnik/fetch-mcp-docker/refs/heads/main/LICENSE)

**[NPM Package](https://www.npmjs.com/package/fetch-mcp)** • **[GitHub Repository](https://github.com/mekayelanik/fetch-mcp-docker)** • **[Docker Hub](https://hub.docker.com/r/mekayelanik/fetch-mcp)**

</div>

---

## 📋 Table of Contents

- [Overview](#overview)
- [Quick Start](#quick-start)
- [Configuration](#configuration)
- [MCP Client Setup](#mcp-client-setup)
- [Available Tools](#available-tools)
- [Advanced Usage](#advanced-usage)
- [Troubleshooting](#troubleshooting)
- [Resources & Support](#resources--support)

---

## Overview

Fetch MCP Server empowers AI assistants with powerful web content retrieval capabilities. Fetch any webpage and receive content in your preferred format—HTML, JSON, plain text, or Markdown. Seamlessly integrates with VS Code, Cursor, Windsurf, Claude Desktop, and any MCP-compatible client.

### Key Features

✨ **Multiple Format Support** - HTML, JSON, plain text, and Markdown conversion  
🔒 **Secure & Configurable** - Custom headers, SSL verification, redirect control  
⚡ **High Performance** - Configurable timeouts, size limits, and redirect handling  
🌐 **CORS Ready** - Built-in CORS support for browser-based clients  
🚀 **Multiple Protocols** - HTTP, SSE, and WebSocket transport support  
🎯 **Zero Configuration** - Works out of the box with sensible defaults  
🔧 **Highly Customizable** - Fine-tune every aspect via environment variables  
📊 **Health Monitoring** - Built-in health check endpoint

### Supported Architectures

| Architecture | Status | Notes |
|:-------------|:------:|:------|
| **x86-64** | ✅ Stable | Intel/AMD processors |
| **ARM64** | ✅ Stable | Raspberry Pi, Apple Silicon |

### Available Tags

| Tag | Stability | Use Case |
|:----|:---------:|:---------|
| `stable` | ⭐⭐⭐ | **Production (recommended)** |
| `latest` | ⭐⭐⭐ | Latest stable features |
| `1.x.x` | ⭐⭐⭐ | Version pinning |
| `beta` | ⚠️ | Testing only |

---

## Quick Start

### Prerequisites

- Docker Engine 23.0+
- Network access for fetching web content

### Docker Compose (Recommended)

```yaml
services:
  fetch-mcp:
    image: mekayelanik/fetch-mcp:stable
    container_name: fetch-mcp
    restart: unless-stopped
    ports:
      - "8060:8060"
    environment:
      - PORT=8060
      - PUID=1000
      - PGID=1000
      - TZ=Asia/Dhaka
      - PROTOCOL=SHTTP
      - CORS=*
      - DEFAULT_LIMIT=0
      - FETCH_TIMEOUT=30000
      - MAX_REDIRECTS=5
      - FOLLOW_REDIRECTS=true
      - VERIFY_SSL=true
```

**Deploy:**

```bash
docker compose up -d
docker compose logs -f fetch-mcp
```

### Docker CLI

```bash
docker run -d \
  --name=fetch-mcp \
  --restart=unless-stopped \
  -p 8060:8060 \
  -e PORT=8060 \
  -e PUID=1000 \
  -e PGID=1000 \
  -e PROTOCOL=SHTTP \
  -e CORS=* \
  mekayelanik/fetch-mcp:stable
```

### Access Endpoints

| Protocol | Endpoint | Use Case |
|:---------|:---------|:---------|
| **HTTP** | `http://host-ip:8060/mcp` | **Recommended** |
| **SSE** | `http://host-ip:8060/sse` | Real-time streaming |
| **WebSocket** | `ws://host-ip:8060/message` | Bidirectional |
| **Health** | `http://host-ip:8060/healthz` | Monitoring |

> ⏱️ Server ready in 5-10 seconds after container start

---

## Configuration

### Environment Variables

#### Core Settings

| Variable | Default | Description |
|:---------|:-------:|:------------|
| `PORT` | `8060` | Server port (1-65535) |
| `PUID` | `1000` | User ID for file permissions |
| `PGID` | `1000` | Group ID for file permissions |
| `TZ` | `Asia/Dhaka` | Container timezone |
| `PROTOCOL` | `SHTTP` | Transport protocol |
| `CORS` | _(none)_ | Cross-Origin configuration |

#### Fetch Settings

| Variable | Default | Description |
|:---------|:-------:|:------------|
| `DEFAULT_LIMIT` | `0` | Max response size (bytes, 0=unlimited) |
| `FETCH_TIMEOUT` | `30000` | Request timeout (ms, 1000-300000) |
| `MAX_REDIRECTS` | `5` | Maximum redirect follow count (0-20) |
| `FOLLOW_REDIRECTS` | `true` | Enable automatic redirect following |
| `VERIFY_SSL` | `true` | Enable SSL certificate verification |
| `USER_AGENT` | _(default)_ | Custom User-Agent header |

#### Advanced Settings

| Variable | Default | Description |
|:---------|:-------:|:------------|
| `DEBUG_MODE` | `false` | Enable debug mode (`true`, `false`, `verbose`) |

### Protocol Configuration

```yaml
# HTTP/Streamable HTTP (Recommended)
environment:
  - PROTOCOL=SHTTP

# Server-Sent Events
environment:
  - PROTOCOL=SSE

# WebSocket
environment:
  - PROTOCOL=WS
```

### CORS Configuration

```yaml
# Development - Allow all origins
environment:
  - CORS=*

# Production - Specific domains
environment:
  - CORS=https://example.com,https://app.example.com

# Mixed domains and IPs
environment:
  - CORS=https://example.com,192.168.1.100:3000,/.*\.myapp\.com$/

# Regex patterns
environment:
  - CORS=/^https:\/\/.*\.example\.com$/
```

> ⚠️ **Security:** Never use `CORS=*` in production environments

### Size Limit Examples

```yaml
# Unlimited (default)
environment:
  - DEFAULT_LIMIT=0

# 1 MB limit
environment:
  - DEFAULT_LIMIT=1048576

# 5 MB limit
environment:
  - DEFAULT_LIMIT=5242880

# 10 MB limit
environment:
  - DEFAULT_LIMIT=10485760
```

### Timeout Examples

```yaml
# Quick responses (10 seconds)
environment:
  - FETCH_TIMEOUT=10000

# Default (30 seconds)
environment:
  - FETCH_TIMEOUT=30000

# Long-running requests (2 minutes)
environment:
  - FETCH_TIMEOUT=120000
```

### Custom User Agent

```yaml
environment:
  - USER_AGENT=MyBot/1.0 (+https://example.com/bot)
```

---

## MCP Client Setup

### Transport Compatibility

| Client | HTTP | SSE | WebSocket | Recommended |
|:-------|:----:|:---:|:---------:|:------------|
| **VS Code (Cline/Roo-Cline)** | ✅ | ✅ | ❌ | HTTP |
| **Claude Desktop** | ✅ | ✅ | ⚠️* | HTTP |
| **Cursor** | ✅ | ✅ | ⚠️* | HTTP |
| **Windsurf** | ✅ | ✅ | ⚠️* | HTTP |

> ⚠️ *WebSocket support is experimental

### VS Code (Cline/Roo-Cline)

Add to `.vscode/settings.json`:

```json
{
  "mcp.servers": {
    "fetch": {
      "url": "http://host-ip:8060/mcp",
      "transport": "http",
      "autoApprove": [
        "fetch_html",
        "fetch_json",
        "fetch_txt",
        "fetch_markdown"
      ]
    }
  }
}
```

### Claude Desktop

**Config Locations:**
- **Linux:** `~/.config/Claude/claude_desktop_config.json`
- **macOS:** `~/Library/Application Support/Claude/claude_desktop_config.json`
- **Windows:** `%APPDATA%\Claude\claude_desktop_config.json`

```json
{
  "mcpServers": {
    "fetch": {
      "transport": "http",
      "url": "http://localhost:8060/mcp"
    }
  }
}
```

### Cursor

Add to `~/.cursor/mcp.json`:

```json
{
  "mcpServers": {
    "fetch": {
      "transport": "http",
      "url": "http://host-ip:8060/mcp"
    }
  }
}
```

### Windsurf (Codeium)

Add to `.codeium/mcp_settings.json`:

```json
{
  "mcpServers": {
    "fetch": {
      "transport": "http",
      "url": "http://host-ip:8060/mcp"
    }
  }
}
```

### Claude Code

Add to `~/.config/claude-code/mcp_config.json`:

```json
{
  "mcpServers": {
    "fetch": {
      "transport": "http",
      "url": "http://localhost:8060/mcp"
    }
  }
}
```

Or configure via CLI:

```bash
claude-code config mcp add fetch \
  --transport http \
  --url http://localhost:8060/mcp
```

### GitHub Copilot CLI

Add to `~/.github-copilot/mcp.json`:

```json
{
  "mcpServers": {
    "fetch": {
      "transport": "http",
      "url": "http://host-ip:8060/mcp"
    }
  }
}
```

Or use environment variable:

```bash
export GITHUB_COPILOT_MCP_SERVERS='{"fetch":{"transport":"http","url":"http://localhost:8060/mcp"}}'
```

---

## Available Tools

### 🌐 fetch_html
Fetch a website and return raw HTML content.

**Parameters:**
- `url` (string, required): URL of the website to fetch
- `headers` (object, optional): Custom headers for the request

**Use Cases:**
- Scraping structured web data
- Analyzing page structure
- Testing web applications
- Extracting specific HTML elements

**Example Prompts:**
- "Fetch the HTML from https://example.com"
- "Get the HTML of https://news.ycombinator.com with custom headers"
- "Download the raw HTML from this page"

---

### 📦 fetch_json
Fetch and parse JSON data from a URL.

**Parameters:**
- `url` (string, required): URL of the JSON resource
- `headers` (object, optional): Custom headers for the request

**Use Cases:**
- Consuming REST APIs
- Reading configuration files
- Processing structured data
- API testing and debugging

**Example Prompts:**
- "Fetch the JSON from https://api.example.com/data"
- "Get JSON data from this API endpoint"
- "Download and parse JSON from https://example.com/config.json"

---

### 📄 fetch_txt
Fetch a website and return clean plain text (HTML tags removed).

**Parameters:**
- `url` (string, required): URL of the website to fetch
- `headers` (object, optional): Custom headers for the request

**Use Cases:**
- Reading articles and blog posts
- Text analysis and processing
- Content extraction without markup
- Accessibility-focused content retrieval

**Example Prompts:**
- "Get the text content from https://blog.example.com/post"
- "Fetch plain text from this article"
- "Extract text from https://example.com without HTML"

---

### 📝 fetch_markdown
Fetch a website and convert HTML to Markdown format.

**Parameters:**
- `url` (string, required): URL of the website to fetch
- `headers` (object, optional): Custom headers for the request

**Use Cases:**
- Converting web content to Markdown
- Creating documentation from web pages
- Archiving web content in readable format
- Content migration to Markdown-based systems

**Example Prompts:**
- "Convert https://example.com to Markdown"
- "Get this webpage in Markdown format"
- "Fetch and convert this article to Markdown"

---

## Advanced Usage

### Custom Headers Example

```json
{
  "url": "https://api.example.com/data",
  "headers": {
    "Authorization": "Bearer YOUR_TOKEN",
    "Accept": "application/json",
    "User-Agent": "MyApp/1.0"
  }
}
```

### Production Configuration

```yaml
services:
  fetch-mcp:
    image: mekayelanik/fetch-mcp:stable
    container_name: fetch-mcp
    restart: unless-stopped
    ports:
      - "8060:8060"
    environment:
      # Core settings
      - PORT=8060
      - PUID=1000
      - PGID=1000
      - TZ=UTC
      - PROTOCOL=SHTTP
      
      # Security
      - CORS=https://app.example.com,https://admin.example.com
      - VERIFY_SSL=true
      
      # Performance
      - DEFAULT_LIMIT=5242880  # 5 MB limit
      - FETCH_TIMEOUT=30000    # 30 seconds
      - MAX_REDIRECTS=5
      - FOLLOW_REDIRECTS=true
      
      # Custom identification
      - USER_AGENT=MyCompany-Bot/1.0 (+https://example.com/bot)
    
    # Resource limits
    deploy:
      resources:
        limits:
          cpus: '1.0'
          memory: 512M
        reservations:
          cpus: '0.5'
          memory: 256M
    
    # Health check
    healthcheck:
      test: ["CMD", "nc", "-z", "localhost", "8060"]
      interval: 30s
      timeout: 10s
      retries: 3
      start_period: 10s
```

### Reverse Proxy Setup

#### Nginx

```nginx
server {
    listen 80;
    server_name fetch.example.com;
    
    location / {
        proxy_pass http://localhost:8060;
        proxy_http_version 1.1;
        proxy_set_header Upgrade $http_upgrade;
        proxy_set_header Connection "upgrade";
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;
        
        # Timeouts for long-running requests
        proxy_connect_timeout 300;
        proxy_send_timeout 300;
        proxy_read_timeout 300;
    }
}
```

#### Traefik

```yaml
services:
  fetch-mcp:
    image: mekayelanik/fetch-mcp:stable
    labels:
      - "traefik.enable=true"
      - "traefik.http.routers.fetch-mcp.rule=Host(`fetch.example.com`)"
      - "traefik.http.routers.fetch-mcp.entrypoints=websecure"
      - "traefik.http.routers.fetch-mcp.tls.certresolver=myresolver"
      - "traefik.http.services.fetch-mcp.loadbalancer.server.port=8060"
```

### Docker Network Setup

```yaml
services:
  fetch-mcp:
    image: mekayelanik/fetch-mcp:stable
    container_name: fetch-mcp
    networks:
      - mcp-network
    environment:
      - PORT=8060
      - PROTOCOL=SHTTP
    
  other-service:
    image: other-service:latest
    networks:
      - mcp-network
    environment:
      - FETCH_MCP_URL=http://fetch-mcp:8060/mcp

networks:
  mcp-network:
    driver: bridge
```

### Multiple Instances

```yaml
services:
  fetch-mcp-primary:
    image: mekayelanik/fetch-mcp:stable
    container_name: fetch-mcp-primary
    ports:
      - "8060:8060"
    environment:
      - PORT=8060
      - FETCH_TIMEOUT=30000
  
  fetch-mcp-fast:
    image: mekayelanik/fetch-mcp:stable
    container_name: fetch-mcp-fast
    ports:
      - "8061:8060"
    environment:
      - PORT=8060
      - FETCH_TIMEOUT=10000
      - DEFAULT_LIMIT=1048576  # 1 MB for quick fetches
  
  fetch-mcp-large:
    image: mekayelanik/fetch-mcp:stable
    container_name: fetch-mcp-large
    ports:
      - "8062:8060"
    environment:
      - PORT=8060
      - FETCH_TIMEOUT=120000
      - DEFAULT_LIMIT=52428800  # 50 MB for large content
```

---

## Troubleshooting

### Pre-Flight Checklist

- ✅ Docker 23.0+
- ✅ Port 8060 available
- ✅ Network connectivity
- ✅ Latest stable image
- ✅ Correct environment variables

### Common Issues

**Container Won't Start**
```bash
# Check logs
docker logs fetch-mcp

# Pull latest image
docker pull mekayelanik/fetch-mcp:stable

# Restart container
docker restart fetch-mcp
```

**Connection Refused**
```bash
# Verify container is running
docker ps | grep fetch-mcp

# Check port binding
docker port fetch-mcp

# Test health endpoint
curl http://localhost:8060/healthz
```

**Timeout Errors**
```yaml
# Increase timeout for slow websites
environment:
  - FETCH_TIMEOUT=60000  # 60 seconds

# Adjust redirect limit
environment:
  - MAX_REDIRECTS=10
```

**SSL Certificate Errors**
```yaml
# Disable SSL verification (not recommended for production)
environment:
  - VERIFY_SSL=false

# Or update CA certificates in container
docker exec fetch-mcp apk add --update ca-certificates
```

**CORS Errors**
```yaml
# Development - allow all
environment:
  - CORS=*

# Production - specific origins
environment:
  - CORS=https://yourdomain.com,https://app.yourdomain.com
```

**Permission Errors**
```bash
# Check your user ID
id $USER

# Update PUID/PGID
environment:
  - PUID=1001  # Your actual UID
  - PGID=1001  # Your actual GID
```

**Size Limit Exceeded**
```yaml
# Increase or remove size limit
environment:
  - DEFAULT_LIMIT=0  # Unlimited
  # or
  - DEFAULT_LIMIT=10485760  # 10 MB
```

**Debug Mode**
```yaml
# Enable verbose debugging
environment:
  - DEBUG_MODE=verbose

# Then check logs
docker logs -f fetch-mcp
```

### Health Check Testing

```bash
# Basic health check
curl http://localhost:8060/healthz

# Test MCP endpoint
curl http://localhost:8060/mcp

# Test with tool invocation
curl -X POST http://localhost:8060/mcp \
  -H "Content-Type: application/json" \
  -d '{"method":"tools/list"}'
```

---

## Resources & Support

### Documentation
- 📦 [NPM Package](https://www.npmjs.com/package/fetch-mcp)
- 🔧 [GitHub Repository](https://github.com/mekayelanik/fetch-mcp-docker)
- 🐳 [Docker Hub](https://hub.docker.com/r/mekayelanik/fetch-mcp)

### MCP Resources
- 📘 [MCP Protocol Specification](https://modelcontextprotocol.io)
- 🎓 [MCP Documentation](https://modelcontextprotocol.io/docs)
- 💬 [MCP Community](https://discord.gg/mcp)

### Getting Help

**Docker Image Issues:**
- [GitHub Issues](https://github.com/mekayelanik/fetch-mcp-docker/issues)
- [Discussions](https://github.com/mekayelanik/fetch-mcp-docker/discussions)

**General Questions:**
- Check logs: `docker logs fetch-mcp`
- Test health: `curl http://localhost:8060/healthz`
- Review configuration in this README

### Updating

```bash
# Docker Compose
docker compose pull
docker compose up -d

# Docker CLI
docker pull mekayelanik/fetch-mcp:stable
docker stop fetch-mcp
docker rm fetch-mcp
# Re-run your docker run command
```

### Version Pinning

```yaml
# Use specific version
services:
  fetch-mcp:
    image: mekayelanik/fetch-mcp:1.0.0

# Or use stable tag (recommended)
services:
  fetch-mcp:
    image: mekayelanik/fetch-mcp:stable
```

---

## Performance Tips

### Optimize for Speed

```yaml
environment:
  - FETCH_TIMEOUT=10000      # Faster timeout
  - DEFAULT_LIMIT=1048576    # 1 MB limit
  - MAX_REDIRECTS=3          # Fewer redirects
  - FOLLOW_REDIRECTS=true
```

### Optimize for Large Content

```yaml
environment:
  - FETCH_TIMEOUT=120000     # 2 minutes
  - DEFAULT_LIMIT=0          # No limit
  - MAX_REDIRECTS=10
```

### Resource Limits

```yaml
deploy:
  resources:
    limits:
      cpus: '2.0'
      memory: 1G
    reservations:
      cpus: '1.0'
      memory: 512M
```

---

## Security Best Practices

1. **Never use `CORS=*` in production**
2. **Always use `VERIFY_SSL=true`** except for development
3. **Set appropriate size limits** to prevent abuse
4. **Use reverse proxy** with rate limiting
5. **Run as non-root** (default PUID/PGID)
6. **Monitor logs** for suspicious activity
7. **Keep Docker image updated**
8. **Use specific version tags** for production

---

## License

Docker Image: GPL License - See [LICENSE](https://raw.githubusercontent.com/MekayelAnik/fetch-mcp-docker/refs/heads/main/LICENSE) for details.

**Disclaimer:** Unofficial Docker image for [fetch-mcp](https://www.npmjs.com/package/fetch-mcp). Users are responsible for compliance with terms of service of fetched websites and applicable laws.

---

<div align="center">

[Report docker image related Bug](https://github.com/mekayelanik/fetch-mcp-docker/issues) • [Request Feature](https://github.com/mekayelanik/fetch-mcp-docker/issues) • [Contribute](https://github.com/mekayelanik/fetch-mcp-docker/pulls)

</div>
