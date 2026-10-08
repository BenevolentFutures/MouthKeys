#!/bin/sh
# Serve the app-signal prototype on http://localhost:8766 and open it. index.html is self-contained,
# so double-clicking it works too; this is for Safari, which renders SF Mono where Chrome falls back to Menlo.
cd "$(dirname "$0")"
PORT=${PORT:-8766}
if ! lsof -iTCP:$PORT -sTCP:LISTEN >/dev/null 2>&1; then
  nohup python3 -m http.server $PORT --bind 127.0.0.1 >/dev/null 2>&1 &
  sleep 1
fi
/usr/bin/open "http://localhost:$PORT/index.html"
echo "serving http://localhost:$PORT (pid $(lsof -tiTCP:$PORT -sTCP:LISTEN | head -1))"
