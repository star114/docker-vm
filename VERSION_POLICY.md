# Version Policy

## Goal

Pin image tags for stateful services, review upstream changes before upgrades, and keep rollback targets explicit.

## Pinned Tags

The stack uses image tag variables in `.env`:

- `NPM_IMAGE_TAG`
- `VAULTWARDEN_IMAGE_TAG`
- `POSTGRES_IMAGE_TAG`
- `TESLAMATE_IMAGE_TAG`
- `TESLAMATE_GRAFANA_IMAGE_TAG`
- `PORTAINER_IMAGE_TAG`
- `DIUN_IMAGE_TAG`

## Current Recommended Values

- `NPM_IMAGE_TAG=2.13.5`
- `VAULTWARDEN_IMAGE_TAG=1.35.2`
- `POSTGRES_IMAGE_TAG=17.9-trixie`
- `TESLAMATE_IMAGE_TAG=2.2.0`
- `TESLAMATE_GRAFANA_IMAGE_TAG=2.2.0`
- `PORTAINER_IMAGE_TAG=2.33.6`
- `DIUN_IMAGE_TAG=4.30.0`

## Source Notes

- Nginx Proxy Manager version is based on the latest GitHub release page as of March 8, 2026.
- Vaultwarden version is based on the latest GitHub release page as of March 8, 2026.
- PostgreSQL version is based on the official PostgreSQL current-minor table as of March 8, 2026.
- TeslaMate version is based on the latest TeslaMate GitHub release as of March 8, 2026.
- TeslaMate Grafana uses the same application release line as TeslaMate. This is an inference from TeslaMate’s release packaging and image naming.
- Portainer version is pinned to the current LTS release line as of March 8, 2026.
- Diun version is based on the latest GitHub release page as of March 8, 2026.

## Upgrade Cadence

- Security or data-corruption fixes: upgrade as soon as practical.
- Normal application updates: review weekly, apply monthly or during a planned maintenance window.
- PostgreSQL major upgrades: treat as a separate migration task.
- TeslaMate upgrades: review release notes for database migration requirements before rollout.

## Upgrade Workflow

1. Check Diun notifications.
2. Read the upstream release notes for the candidate version.
3. Create or verify backups, especially TeslaMate PostgreSQL.
4. Change only the relevant `*_IMAGE_TAG` values in `.env`.
5. Pull and recreate the affected services.
6. Check `docker compose ps` and service logs.
7. Keep the previous image tag noted until validation is complete.

## Rollback Guidance

- Roll back by restoring the previous `*_IMAGE_TAG` values in `.env`.
- Run `docker compose up -d` after restoring the old tags.
- If a data migration has already been applied and the application no longer supports downgrade, restore from backup instead of forcing an image rollback.

## Diun Strategy

Diun is configured in two layers:

- `diun`: routine notifications for the current approved release line
- `diun-major`: review notifications for wider stable-version changes, including major updates

Routine label strategy:

- `diun.watch_repo=true` enables repository-wide tag checks.
- `diun.notify_on=new` reports newer matching tags.
- `diun.include_tags` constrains alerts to the intended release line.
- If `diun.include_tags` is omitted while `diun.watch_repo=true`, Diun evaluates all tags in the repository, only limited by `max_tags` and `exclude_tags`.

Examples:

- Nginx Proxy Manager: alerts on `2.x.y`
- Vaultwarden: alerts on `1.x.y`
- PostgreSQL: alerts on `17.x-trixie`
- TeslaMate and TeslaMate Grafana: alerts on `2.x.y`
- Portainer: alerts on `2.x.y`
- Diun: alerts on `4.x.y`

This means Diun can alert on tags newer than the currently pinned tag. It does not update containers automatically.

Major review strategy:

- `diun-major` uses the official file provider with a curated image list.
- Each image uses broader stable-tag regex so new major versions can be surfaced without changing the routine watcher.
- This keeps normal operations quiet while still surfacing migration candidates.
