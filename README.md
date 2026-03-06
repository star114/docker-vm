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
2. Edit `.env` and replace all placeholder secrets.
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
Persistent data is stored in local directories mounted from this repo (for example `./vaultwarden`, `./teslamate`, `./portainer`, etc.).

## Operations
Start or recreate containers:
```bash
docker compose up -d
```

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
1. Pull updated images:
   ```bash
   docker compose pull
   ```
2. Recreate containers in detached mode:
   ```bash
   docker compose up -d
   ```
3. Remove unused images:
   ```bash
   docker image prune -f
   ```

## Backup Scope
Back up these directories regularly:
- `./nginx-proxy-manager/data`
- `./nginx-proxy-manager/letsencrypt`
- `./vaultwarden`
- `./teslamate`
- `./portainer`
- `./diun/data`

Also back up `.env` securely (outside this repository).

## Stop / Remove
Stop:
```bash
docker compose stop
```

Stop and remove containers/network:
```bash
docker compose down
```
