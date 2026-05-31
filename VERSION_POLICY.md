# Version Policy

## Goal

Use `latest` for application services while keeping PostgreSQL explicit and recoverable.

This stack prioritizes simple operational updates:

- Application services track their upstream `latest` tag.
- PostgreSQL stays on `POSTGRES_IMAGE_TAG` in `.env`.
- Diun notifies when a configured tag digest changes.
- Updates are still applied manually with `docker compose pull` and `docker compose up -d`.

## Image Tag Strategy

These services use `latest` directly in `docker-compose.yaml`:

- Nginx Proxy Manager
- Vaultwarden
- TeslaMate
- TeslaMate Grafana
- Portainer
- Diun

PostgreSQL uses:

```env
POSTGRES_IMAGE_TAG=17.9-trixie
```

Keep PostgreSQL on an explicit tag unless you are intentionally planning a database upgrade.

## Diun Strategy

Diun runs one watcher using the Docker provider. Watched services opt in with labels:

```yaml
- "diun.enable=true"
- "diun.notify_on=update"
```

This means Diun watches the configured image tag and notifies when that tag's digest changes.

The previous separate `diun-major` watcher is no longer needed because non-PostgreSQL services follow `latest` directly. PostgreSQL major upgrades should be reviewed manually, not discovered through automatic major-version alerts.

Diun does not update containers automatically.

## Update Workflow

1. Read Diun notifications.
2. For TeslaMate-related updates, create a fresh PostgreSQL backup:
   ```bash
   ./scripts/backup-teslamate-db.sh
   ```
3. Pull images:
   ```bash
   docker compose pull
   ```
4. Recreate containers:
   ```bash
   docker compose up -d
   ```
5. Check status and logs:
   ```bash
   docker compose ps
   docker compose logs --tail=100 teslamate-db teslamate teslamate-grafana
   ```
6. Remove unused images after validation:
   ```bash
   docker image prune -f
   ```

## PostgreSQL Upgrade Guidance

PostgreSQL is stateful and should not blindly follow `latest`.

For minor updates within the same major version:

1. Read the PostgreSQL image notes for the target tag.
2. Run `./scripts/backup-teslamate-db.sh`.
3. Change `POSTGRES_IMAGE_TAG` in `.env`.
4. Pull and recreate the stack.
5. Verify TeslaMate and Grafana.

For major upgrades, treat the work as a separate migration task. Confirm TeslaMate compatibility, read PostgreSQL migration notes, and keep a tested restore path before changing the tag.

## Rollback Guidance

For application images using `latest`, rollback depends on Docker's local image cache or a manually selected previous tag. If you need a reliable rollback target for a service, temporarily pin that service to a known-good tag before updating.

For PostgreSQL, restore the previous `POSTGRES_IMAGE_TAG` only if no incompatible data migration has occurred. If the database has been migrated and downgrade is not supported, restore from a backup instead.
