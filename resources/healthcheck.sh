#!/bin/sh
PORT="${PORT:-8060}"
SCHEME=$([ "$ENABLE_HTTPS" = "true" ] && echo https || echo http)
URL="${SCHEME}://127.0.0.1:${PORT}/healthz"

if command -v curl >/dev/null 2>&1; then
    exec curl --fail --silent --show-error --insecure --max-time 5 "$URL" >/dev/null
fi
if command -v wget >/dev/null 2>&1; then
    exec wget -q --spider --no-check-certificate --timeout=5 "$URL"
fi
echo "neither curl nor wget available" >&2
exit 1
