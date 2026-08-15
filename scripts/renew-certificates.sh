#!/usr/bin/env bash
set -Eeuo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT_DIR"

[[ -f .env ]] || { echo "Missing .env" >&2; exit 1; }
docker compose --env-file .env run --rm --no-deps certbot renew --webroot --webroot-path /var/www/certbot
docker compose --env-file .env exec -T nginx nginx -s reload
