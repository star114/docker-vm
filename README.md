# docker-vm

Docker Compose stack for self-hosted services:
- Nginx Proxy Manager
- Vaultwarden
- TeslaMate + PostgreSQL + Grafana
- Portainer
- Diun (Docker image update notifier)

## Prerequisites
- Docker Engine
- Docker Compose plugin (`docker compose`)

## Quick Start
1. Copy environment template:
   ```bash
   cp .env.example .env
   ```
2. Edit `.env`, replace all placeholder secrets, and set `DATA_ROOT` to the host path that should hold persistent runtime data.
3. Start services:
   ```bash
   docker compose up -d
   ```
4. Check status:
   ```bash
   docker compose ps
   ```
5. View logs:
   ```bash
   docker compose logs -f
   ```

## Exposed Ports
- `80` / `443`: Nginx Proxy Manager (HTTP/HTTPS)
- `81`: Nginx Proxy Manager admin UI
- `3389`: RDP passthrough port
- `8080`: Vaultwarden
- `4000`: TeslaMate web UI
- `5000`: TeslaMate Grafana
- `9000`: Portainer

## Initial Access URLs
- Nginx Proxy Manager: `http://<SERVER_IP>:81`
- Vaultwarden: `http://<SERVER_IP>:8080`
- TeslaMate: `http://<SERVER_IP>:4000`
- Grafana (TeslaMate): `http://<SERVER_IP>:5000`
- Portainer: `http://<SERVER_IP>:9000`

## Data Persistence
Persistent data is mounted from `DATA_ROOT`. If `DATA_ROOT` is unset, Compose falls back to the previous repo-relative paths for compatibility.

Recommended:

- Set `DATA_ROOT` to an absolute host path such as `/srv/docker-data`
- Keep runtime data outside this repository
- Keep backup files outside both the repository and `DATA_ROOT`

Examples under `DATA_ROOT`:

- `${DATA_ROOT}/nginx-proxy-manager/data`
- `${DATA_ROOT}/vaultwarden`
- `${DATA_ROOT}/teslamate/db`
- `${DATA_ROOT}/teslamate/grafana`
- `${DATA_ROOT}/portainer`

For TeslaMate PostgreSQL, do not treat `${DATA_ROOT}/teslamate/db` as the primary backup artifact while the database is running. Use the logical backup workflow below instead.

## Operations
Start or recreate containers:
```bash
docker compose up -d
```

`teslamate` and `teslamate-grafana` now wait for `teslamate-db` to become healthy before startup. PostgreSQL also gets a longer shutdown grace period to reduce abrupt-stop risk.

Image tags are pinned through variables in `.env`. Update those variables deliberately instead of relying on `latest`.

Check container status:
```bash
docker compose ps
```

Tail logs for all services:
```bash
docker compose logs -f
```

Restart one service:
```bash
docker compose restart teslamate
```

## Security Notes
- Keep `.env` out of version control.
- Use strong unique passwords for DB, MQTT, and Grafana credentials.
- Restrict public access to admin endpoints (`:81`, `:9000`, `:5000`) through firewall or reverse proxy rules.

## Update Procedure
1. Review the release notes for the image tag you want to move to.
2. Run a fresh TeslaMate PostgreSQL backup before changing stateful images.
3. Update the relevant `*_IMAGE_TAG` values in `.env`.
4. Pull updated images:
   ```bash
   docker compose pull
   ```
5. Recreate containers in detached mode:
   ```bash
   docker compose up -d
   ```
6. Verify service health and logs:
   ```bash
   docker compose ps
   docker compose logs --tail=100 teslamate-db teslamate teslamate-grafana
   ```
7. Remove unused images:
   ```bash
   docker image prune -f
   ```

See `VERSION_POLICY.md` for the tag sources, cadence, and rollback guidance.

`diun/diun.yml` is configured for routine Telegram notifications and `diun/diun-major.yml` is configured for major-version review notifications. Set `DIUN_TELEGRAM_BOT_TOKEN` and `DIUN_TELEGRAM_CHAT_IDS` in `.env` before starting either watcher.

## Backup Scope
Back up these directories regularly:
- `${DATA_ROOT}/nginx-proxy-manager/data`
- `${DATA_ROOT}/nginx-proxy-manager/letsencrypt`
- `${DATA_ROOT}/vaultwarden`
- `${DATA_ROOT}/teslamate/grafana`
- `${DATA_ROOT}/portainer`
- `${DATA_ROOT}/diun/data`

Also back up `.env` securely (outside this repository).

## Data Migration To DATA_ROOT

If you already have data in repo-relative directories, migrate it before enabling `DATA_ROOT` in production.

1. Stop the stack:
   ```bash
   docker compose down
   ```
2. Create the target directory tree:
   ```bash
   mkdir -p /srv/docker-data
   ```
3. Copy existing data to the new root:
   ```bash
   rsync -a ./nginx-proxy-manager/ /srv/docker-data/nginx-proxy-manager/
   rsync -a ./vaultwarden/ /srv/docker-data/vaultwarden/
   rsync -a ./teslamate/ /srv/docker-data/teslamate/
   rsync -a ./portainer/ /srv/docker-data/portainer/
   rsync -a ./diun/data/ /srv/docker-data/diun/data/
   ```
4. Set `DATA_ROOT=/srv/docker-data` in `.env`.
5. Start the stack and verify service health:
   ```bash
   docker compose up -d
   docker compose ps
   ```

After verification, keep the old repo-relative directories only until you no longer need rollback.

## TeslaMate PostgreSQL Backup

The repository includes helper scripts for logical PostgreSQL backup and restore:

```bash
./scripts/backup-teslamate-db.sh
```

By default the script writes to `${BACKUP_ROOT}/teslamate-db`. Set `BACKUP_ROOT` in `.env` and prefer an absolute host path outside the repository for operational backups.

Example:

```bash
BACKUP_ROOT=/srv/docker-backups ./scripts/backup-teslamate-db.sh
```

The backup script:

- Loads database credentials from `.env`
- Verifies the `teslamate-db` container is running
- Writes a timestamped PostgreSQL custom-format dump

## TeslaMate PostgreSQL Restore

Restore requires a backup created by `backup-teslamate-db.sh`.

```bash
./scripts/restore-teslamate-db.sh /path/to/teslamate_YYYYmmdd_HHMMSS.dump
```

The restore script:

- Stops `teslamate` and `teslamate-grafana`
- Recreates the TeslaMate database
- Restores the selected dump
- Starts `teslamate` and `teslamate-grafana` again

Warning: restore is destructive for the current TeslaMate database contents.

## Diun Notification Modes

The stack now uses two Diun watchers:

- `diun`: routine updates for the currently approved release line
- `diun-major`: major-version review alerts using the file provider

Start or restart both watchers:

```bash
docker compose up -d diun diun-major
```

The major watcher reads [major-images.yml](/Users/star114/workspace/docker-vm/diun/major-images.yml) and intentionally watches broader stable tag patterns so you can review major upgrades without mixing them into routine operational alerts.

## Stop / Remove
Stop:
```bash
docker compose stop
```

Stop and remove containers/network:
```bash
docker compose down
```
