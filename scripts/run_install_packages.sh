#!/usr/bin/env bash
set -euo pipefail

SMARTCRAN_NET="${SMARTCRAN_NET:-smartcran}"
SMARTCRAN_URL="${SMARTCRAN_URL:-http://smartcran-logger:8080}"
IMAGE="${IMAGE:-rocker/r-ver:4.4.1}"
RUN_ID="${RUN_ID:-scl-$(date +%s)-$RANDOM}"

echo "Network: $SMARTCRAN_NET"
echo "Logger URL: $SMARTCRAN_URL"
echo "R image: $IMAGE"
echo "RUN_ID: $RUN_ID"

# Ensure network exists
docker network create "$SMARTCRAN_NET" >/dev/null 2>&1 || true

# Remember start time to slice logs
SINCE="$(date -Iseconds)"

# Run scenario inside an R container
docker run --rm \
  --network "$SMARTCRAN_NET" \
  -e CRAN_BASE="$SMARTCRAN_URL" \
  -e RUN_ID="$RUN_ID" \
  -v "$(pwd)/scenarios:/scenarios:ro" \
  "$IMAGE" \
  Rscript /scenarios/install_packages.R

echo
echo "=== Matching proxy logs for RUN_ID=$RUN_ID ==="
# Prefer jq if available; fall back to grep
if command -v jq >/dev/null 2>&1; then
  docker logs smartcran-logger --since "$SINCE" 2>&1 \
    | jq -r --arg id "$RUN_ID" '
        select(.fields? != null)
        | select(
            (.fields.ua // "" | contains($id)) or
            (.fields.path // "" | contains($id))
          )'
else
  echo "(jq not found; using grep)"
  docker logs smartcran-logger --since "$SINCE" 2>&1 | grep -F "$RUN_ID" || true
fi
