#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
ENV_FILE="${ENV_FILE:-$ROOT_DIR/.env}"

if [[ $# -ne 1 ]]; then
  echo "Usage: $0 /path/to/teslamate.dump" >&2
  exit 1
fi

BACKUP_FILE="$1"

if [[ ! -f "$BACKUP_FILE" ]]; then
  echo "Backup file not found: $BACKUP_FILE" >&2
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

: "${DB_NAME:?DB_NAME must be set in .env}"
: "${DB_USER:?DB_USER must be set in .env}"

echo "Restoring TeslaMate database from $BACKUP_FILE"
echo "This will replace the current database contents."

docker compose -f "$ROOT_DIR/docker-compose.yaml" stop teslamate teslamate-grafana

docker compose -f "$ROOT_DIR/docker-compose.yaml" up -d teslamate-db

for _ in {1..30}; do
  if docker compose -f "$ROOT_DIR/docker-compose.yaml" exec -T teslamate-db \
    pg_isready -U "$DB_USER" -d postgres >/dev/null 2>&1; then
    break
  fi
  sleep 1
done

if ! docker compose -f "$ROOT_DIR/docker-compose.yaml" exec -T teslamate-db \
  pg_isready -U "$DB_USER" -d postgres >/dev/null 2>&1; then
  echo "teslamate-db did not become ready in time." >&2
  exit 1
fi

docker compose -f "$ROOT_DIR/docker-compose.yaml" exec -T teslamate-db \
  psql -v ON_ERROR_STOP=1 -U "$DB_USER" -d postgres \
  -c "SELECT pg_terminate_backend(pid) FROM pg_stat_activity WHERE datname = '$DB_NAME' AND pid <> pg_backend_pid();"

docker compose -f "$ROOT_DIR/docker-compose.yaml" exec -T teslamate-db \
  psql -v ON_ERROR_STOP=1 -U "$DB_USER" -d postgres \
  -c "DROP DATABASE IF EXISTS \"$DB_NAME\";"

docker compose -f "$ROOT_DIR/docker-compose.yaml" exec -T teslamate-db \
  psql -v ON_ERROR_STOP=1 -U "$DB_USER" -d postgres \
  -c "CREATE DATABASE \"$DB_NAME\";"

cat "$BACKUP_FILE" | docker compose -f "$ROOT_DIR/docker-compose.yaml" exec -T teslamate-db \
  pg_restore \
    --clean \
    --if-exists \
    --no-owner \
    --no-privileges \
    -U "$DB_USER" \
    -d "$DB_NAME"

docker compose -f "$ROOT_DIR/docker-compose.yaml" up -d teslamate teslamate-grafana

echo "Restore complete."
