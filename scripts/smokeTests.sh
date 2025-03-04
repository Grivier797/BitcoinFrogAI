#!/bin/bash
set -euo pipefail

PNPM_PATH=$(command -v pnpm)
if [ -z "$PNPM_PATH" ]; then
    npm install -g pnpm
    PNPM_PATH=$(command -v pnpm)
fi

# Environment checks
echo "node version:"
node --version
echo "python version:"
python3 --version
echo "make version:"
make --version
echo "gcc version:"
gcc --version
echo "g++ version:"
g++ --version

PROJECT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$PROJECT_DIR"

cp .env.example .env

$(command -v pnpm) clean
$(command -v pnpm) install -r --no-frozen-lockfile 
$(command -v pnpm) build

# Test logic
OUTFILE="$(mktemp)"
trap 'rm -f "$OUTFILE"' EXIT

$PNPM_PATH start --character=characters/trump.character.json > "$OUTFILE" 2>&1 &
APP_PID=$!

TIMEOUT=600
INTERVAL=5
TIMER=0

(
  while true; do
    if (( TIMER >= TIMEOUT )); then
        >&2 echo "ERROR: Timeout waiting for application"
        kill $APP_PID
        exit 1
    fi

    if grep -q "REST API bound to 0.0.0.0" "$OUTFILE"; then
        >&2 echo "SUCCESS: API ready"
        break
    fi

    sleep 0.5
    TIMER=$((TIMER + INTERVAL))
  done
)

kill $APP_PID
wait $APP_PID 2>/dev/null || true

RESULT=$?

if [[ $RESULT -ne 0 ]]; then
    echo "Error: Start command failed (code: $RESULT)"
    exit 1
fi

if grep -q "Server closed successfully" "$OUTFILE"; then
    echo "Smoke Test completed successfully"
else
    echo "Error: Missing completion message"
fi