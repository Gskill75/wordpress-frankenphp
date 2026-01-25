# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

WordPress container image based on FrankenPHP (Caddy + PHP 8.4) with automatic installation, rootless execution, and Kubernetes/OpenShift support. The image is stateless with persistent volumes for wp-content.

## Common Commands

### Local Development
```bash
docker-compose up -d
docker-compose logs -f wordpress
docker-compose down -v
```

### Build
```bash
docker build -t wordpress-frankenphp .

# Custom WordPress version or UID
docker build --build-arg WORDPRESS_VERSION=6.9 --build-arg UID=1000 -t wordpress-frankenphp .
```

### WP-CLI Access
```bash
docker-compose exec wordpress wp plugin list
docker-compose exec wordpress wp db export - > backup.sql
docker-compose exec -T wordpress wp db import - < backup.sql
```

### Testing
```bash
curl -I http://localhost:8080
docker-compose exec wordpress php -m
```

## Architecture

### Rootless Container
- **UID**: 1000 (configurable via build arg)
- **GID**: 0 (root group for OpenShift arbitrary UID compatibility)
- **Port**: 8080 (no capabilities required for high ports)
- **Home**: `/app` (WP-CLI cache at `/app/.wp-cli/cache`)

Permissions use `chmod g=u` pattern allowing any UID in the root group to write.

### Container Stack
- **Base image**: `dunglas/frankenphp:1.11-php8.4`
- **Web server**: Caddy (via FrankenPHP) on port 8080
- **PHP extensions**: bcmath, exif, gd, intl, mysqli, zip, imagick, opcache
- **Tools**: WP-CLI at `/usr/local/bin/wp`

### Key Files
- `Dockerfile` - Rootless image with WordPress 6.9 and WP-CLI
- `entrypoint.sh` - Idempotent WordPress auto-install
- `docker-compose.yml` - Local dev stack with MariaDB
- `renovate.json` - Automated dependency updates (Actions, Docker, WordPress)

### Entrypoint Flow (`entrypoint.sh`)
1. Generate `wp-config.php` with random salts
2. Wait for database (configurable via `WORDPRESS_DB_WAIT_TIMEOUT`)
3. Check installation with `wp core is-installed`
4. Run `wp core install` if needed
5. Apply configuration (timezone, permalinks)
6. Execute FrankenPHP

### Environment Variables

**Database (required):**
- `WORDPRESS_DB_HOST`, `WORDPRESS_DB_NAME`, `WORDPRESS_DB_USER`, `WORDPRESS_DB_PASSWORD`

**Auto-install:**
- `WORDPRESS_URL`, `WORDPRESS_TITLE`, `WORDPRESS_ADMIN_USER`, `WORDPRESS_ADMIN_PASSWORD`, `WORDPRESS_ADMIN_EMAIL`, `WORDPRESS_LOCALE`

**Tuning:**
- `WORDPRESS_DB_INITIAL_DELAY` (default: 5s), `WORDPRESS_DB_WAIT_TIMEOUT` (default: 180s)
- `WORDPRESS_TIMEZONE`, `WORDPRESS_PERMALINK_STRUCTURE`, `WORDPRESS_AUTO_UPDATE`

**Caddy:**
- `SERVER_NAME` (default: `:8080`)

### Volumes
- `/app/public/wp-content` - WordPress content
- `/config/caddy`, `/data/caddy` - Caddy config and certificates

## Dependency Management

Renovate bot manages updates for:
- GitHub Actions (grouped PRs)
- Docker base image (FrankenPHP)
- WordPress version (ARG in Dockerfile, auto-merge patches)

Config: `renovate.json`
