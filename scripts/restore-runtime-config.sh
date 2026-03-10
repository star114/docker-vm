#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
ENV_FILE="${ENV_FILE:-$ROOT_DIR/.env}"

if [[ $# -ne 1 ]]; then
  echo "Usage: $0 /path/to/runtime-config_YYYYmmdd_HHMMSS.tar.gz" >&2
  exit 1
fi

ARCHIVE_FILE="$1"

if [[ ! -f "$ARCHIVE_FILE" ]]; then
  echo "Backup archive not found: $ARCHIVE_FILE" >&2
  exit 1
fi

if [[ ! -f "$ENV_FILE" ]]; then
  echo "Missing env file: $ENV_FILE" >&2
  exit 1
fi

set -a
# shellcheck disable=SC1090
source "$ENV_FILE"
set +a

: "${DATA_ROOT:?DATA_ROOT must be set in .env}"

if [[ "$DATA_ROOT" != /* ]]; then
  DATA_ROOT="$ROOT_DIR/$DATA_ROOT"
fi

TMP_DIR="$(mktemp -d)"
cleanup() {
  rm -rf "$TMP_DIR"
}
trap cleanup EXIT

echo "Inspecting backup archive: $ARCHIVE_FILE"
tar --extract --gzip --file "$ARCHIVE_FILE" --directory "$TMP_DIR"

declare -a REQUIRED_EXTRACTS=(
  "$TMP_DIR/env/.env"
  "$TMP_DIR/nginx-proxy-manager/data"
  "$TMP_DIR/nginx-proxy-manager/letsencrypt"
  "$TMP_DIR/vaultwarden"
)

for path in "${REQUIRED_EXTRACTS[@]}"; do
  if [[ ! -e "$path" ]]; then
    echo "Backup archive is missing expected path: $path" >&2
    exit 1
  fi
done

mkdir -p "$DATA_ROOT/nginx-proxy-manager" "$DATA_ROOT/vaultwarden"

echo "Stopping services that write to the target paths"
docker compose -f "$ROOT_DIR/docker-compose.yaml" stop nginx-proxy-manager vaultwarden

restore_tree() {
  local src="$1"
  local dest="$2"

  rm -rf "$dest"
  mkdir -p "$(dirname "$dest")"
  cp -a "$src" "$dest"
}

echo "Restoring runtime data into $DATA_ROOT"
restore_tree "$TMP_DIR/nginx-proxy-manager/data" "$DATA_ROOT/nginx-proxy-manager/data"
restore_tree "$TMP_DIR/nginx-proxy-manager/letsencrypt" "$DATA_ROOT/nginx-proxy-manager/letsencrypt"
restore_tree "$TMP_DIR/vaultwarden" "$DATA_ROOT/vaultwarden"
cp "$TMP_DIR/env/.env" "$ENV_FILE"

echo "Starting restored services"
docker compose -f "$ROOT_DIR/docker-compose.yaml" up -d nginx-proxy-manager vaultwarden

echo "Restore complete."
