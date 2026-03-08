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

: "${DB_NAME:?DB_NAME must be set in .env}"
: "${DB_USER:?DB_USER must be set in .env}"
: "${BACKUP_ROOT:=./backups}"

if [[ "$BACKUP_ROOT" != /* ]]; then
  BACKUP_ROOT="$ROOT_DIR/$BACKUP_ROOT"
fi

BACKUP_DIR="${BACKUP_ROOT%/}/teslamate-db"
TIMESTAMP="$(date +%Y%m%d_%H%M%S)"
BACKUP_FILE="$BACKUP_DIR/teslamate_${TIMESTAMP}.dump"

mkdir -p "$BACKUP_DIR"

if ! docker compose -f "$ROOT_DIR/docker-compose.yaml" ps --services --status running | grep -qx "teslamate-db"; then
  echo "teslamate-db service is not running." >&2
  exit 1
fi

if ! docker compose -f "$ROOT_DIR/docker-compose.yaml" exec -T teslamate-db \
  pg_isready -U "$DB_USER" -d "$DB_NAME" >/dev/null; then
  echo "teslamate-db is running but not ready for connections." >&2
  exit 1
fi

echo "Creating TeslaMate PostgreSQL backup at $BACKUP_FILE"

docker compose -f "$ROOT_DIR/docker-compose.yaml" exec -T teslamate-db \
  pg_dump \
    --format=custom \
    --clean \
    --if-exists \
    --no-owner \
    --no-privileges \
    -U "$DB_USER" \
    -d "$DB_NAME" >"$BACKUP_FILE"

echo "Backup complete: $BACKUP_FILE"
