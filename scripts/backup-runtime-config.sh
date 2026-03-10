#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
ENV_FILE="${ENV_FILE:-$ROOT_DIR/.env}"

if [[ ! -f "$ENV_FILE" ]]; then
  echo "Missing env file: $ENV_FILE" >&2
  exit 1
fi

set -a
# shellcheck disable=SC1090
source "$ENV_FILE"
set +a

: "${DATA_ROOT:?DATA_ROOT must be set in .env}"
: "${BACKUP_ROOT:=./backups}"

if [[ "$DATA_ROOT" != /* ]]; then
  DATA_ROOT="$ROOT_DIR/$DATA_ROOT"
fi

if [[ "$BACKUP_ROOT" != /* ]]; then
  BACKUP_ROOT="$ROOT_DIR/$BACKUP_ROOT"
fi

declare -a REQUIRED_PATHS=(
  "$DATA_ROOT/nginx-proxy-manager/data"
  "$DATA_ROOT/nginx-proxy-manager/letsencrypt"
  "$DATA_ROOT/vaultwarden"
  "$ENV_FILE"
)

for path in "${REQUIRED_PATHS[@]}"; do
  if [[ ! -e "$path" ]]; then
    echo "Required backup path not found: $path" >&2
    exit 1
  fi
done

BACKUP_DIR="${BACKUP_ROOT%/}/runtime-config"
TIMESTAMP="$(date +%Y%m%d_%H%M%S)"
ARCHIVE_FILE="$BACKUP_DIR/runtime-config_${TIMESTAMP}.tar.gz"

mkdir -p "$BACKUP_DIR"

echo "Creating runtime config backup at $ARCHIVE_FILE"

tar \
  --create \
  --gzip \
  --file "$ARCHIVE_FILE" \
  --directory "$ROOT_DIR" \
  --transform "s|^$(basename "$ENV_FILE")$|env/.env|" \
  "$(basename "$ENV_FILE")" \
  --directory "$DATA_ROOT" \
  "nginx-proxy-manager/data" \
  "nginx-proxy-manager/letsencrypt" \
  "vaultwarden"

echo "Backup complete: $ARCHIVE_FILE"
