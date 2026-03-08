# Data Management Improvement Plan

## Goal

Current persistence works, but backup consistency and operational separation are weak in a few places. This plan improves data safety for Docker Compose services without changing application behavior first.

## Current State Summary

- Persistent data is stored with repo-relative bind mounts.
- TeslaMate uses PostgreSQL with its data directory mounted directly to the host.
- Backup guidance currently treats service directories as generic filesystem backup targets.
- Stateful services mostly use `latest` tags, which increases upgrade and rollback risk.

## Main Risks

### 1. PostgreSQL backup consistency

`teslamate-db` stores live PostgreSQL files under `./teslamate/db`. Copying that directory while the database is running is not a reliable backup strategy.

Impact:

- Incomplete or non-restorable backups
- Harder disaster recovery for TeslaMate history

### 2. Code and runtime data are coupled

Most service data lives under the repository tree. That is convenient, but it increases the chance of accidental deletion, migration mistakes, or operational cleanup affecting persistent state.

Impact:

- Higher risk during repo moves or cleanup
- More fragile host migration process

### 3. No structured backup workflow

There is backup scope documentation, but no repeatable backup execution model by service type.

Impact:

- Manual backups are easy to skip
- Restore procedure is undefined

### 4. Upgrade risk for stateful services

Several services use `latest` image tags. Stateful upgrades can introduce schema or storage changes unexpectedly.

Impact:

- Less predictable updates
- Harder rollback planning

## Plan

## Phase 1. Make backup policy explicit

Objective:
Define which services use logical backups, filesystem backups, or both.

Actions:

- Classify backups by service.
- Use logical backups for PostgreSQL.
- Use filesystem backups for file-based services such as Nginx Proxy Manager, Portainer, Diun, and Vaultwarden data.
- Document a restore path for each service.

Deliverables:

- Service-by-service backup matrix
- Restore notes for each stateful service

Success criteria:

- Each persistent service has one approved backup method.
- Restore prerequisites are documented.

## Phase 2. Fix TeslaMate database backup strategy

Objective:
Replace raw directory-copy guidance with a consistent PostgreSQL backup workflow.

Actions:

- Stop treating `./teslamate/db` as the primary backup artifact.
- Add a documented `pg_dump` workflow for `teslamate-db`.
- Store backups in a dedicated backup path outside the live database directory.
- Optionally add a backup helper service or script for repeatable execution.

Deliverables:

- Standard backup command or helper script
- Backup destination convention
- Restore command for PostgreSQL

Success criteria:

- TeslaMate database backup can be created without stopping the stack.
- A restore can be tested into a disposable PostgreSQL container.

## Phase 3. Separate runtime data from the repository

Objective:
Reduce coupling between source files and persistent service state.

Actions:

- Introduce a configurable root such as `DATA_ROOT`.
- Move bind mounts from `./service-dir/...` to `${DATA_ROOT}/service-dir/...`.
- Keep the repo focused on compose/config files, not mutable runtime data.
- Preserve the current directory layout only as a migration source.

Recommended default:

- `DATA_ROOT=/srv/docker-data` on Linux hosts
- Keep `.env` in the repo, but store backups outside the repo

Deliverables:

- Updated mount strategy design
- Migration checklist for existing host data

Success criteria:

- Persistent data can survive repo relocation or replacement.
- Data paths are explicit and centralized.

## Phase 4. Add operational safeguards for stateful services

Objective:
Reduce restart and upgrade risk around stored data.

Actions:

- Add `healthcheck` to `teslamate-db`.
- Gate dependent services on database readiness where practical.
- Add `stop_grace_period` for PostgreSQL.
- Mark config-only mounts as read-only where possible.

Deliverables:

- Compose hardening checklist
- Updated readiness and shutdown behavior

Success criteria:

- Restart behavior is more predictable.
- Database shutdown has time to flush cleanly.

## Phase 5. Pin versions for stateful services

Objective:
Make upgrades deliberate and reversible.

Actions:

- Replace `latest` with pinned major/minor tags for PostgreSQL, Vaultwarden, TeslaMate, Grafana, Portainer, and Nginx Proxy Manager where appropriate.
- Document upgrade cadence and rollback expectations.
- Upgrade one stateful service at a time.

Deliverables:

- Version pinning policy
- Upgrade checklist

Success criteria:

- Image updates are reviewed intentionally.
- Rollback target versions are known before upgrade.

## Rollout Order

1. Document backup policy and restore expectations.
2. Implement PostgreSQL logical backup workflow.
3. Validate PostgreSQL restore in a disposable environment.
4. Introduce `DATA_ROOT` and migrate persistent directories.
5. Harden compose healthchecks and shutdown behavior.
6. Pin image versions and adopt controlled upgrade procedure.

## Validation Checklist

- Confirm `pg_dump` backup completes successfully.
- Confirm PostgreSQL restore works with a test container.
- Confirm TeslaMate reconnects after restore rehearsal.
- Confirm moved bind mounts still preserve permissions and ownership.
- Confirm Vaultwarden, Portainer, and Nginx Proxy Manager start correctly after data path migration.
- Confirm backup paths are excluded from accidental repo operations.

## Suggested File Changes For The Next Implementation Step

- Update `docker-compose.yaml` to support `DATA_ROOT`, healthchecks, and safer mount flags.
- Update `.env.example` to include data-root and backup-path variables.
- Update `README.md` to replace generic backup guidance with service-specific backup and restore instructions.
- Optionally add `scripts/backup-teslamate-db.sh` and a restore companion script.

## Non-Goals For This Planning Step

- No live data migration yet
- No immediate switch from Vaultwarden SQLite to PostgreSQL
- No backup scheduler selection yet
- No production image upgrades yet

## Recommended Next Action

Implement Phase 2 first: add a repeatable TeslaMate PostgreSQL backup and restore workflow. That is the highest-value change with the lowest operational disruption.
