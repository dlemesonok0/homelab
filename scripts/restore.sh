#!/usr/bin/env bash
set -Eeuo pipefail

SNAPSHOT="${1:-latest}"
ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT_DIR"
[[ -f .env ]] || { echo "Missing .env" >&2; exit 1; }
set -a
# shellcheck disable=SC1091
source .env
set +a

stage="$(mktemp -d)"
trap 'docker compose --env-file .env --profile backup stop rclone >/dev/null 2>&1 || true; rm -rf "$stage"' EXIT
docker compose --env-file .env --profile backup up -d rclone
restic=(docker run --rm --network n8n_backup --env-file "$ROOT_DIR/.env" -v "$stage:/restore" restic/restic:0.17.3)
"${restic[@]}" restore "$SNAPSHOT" --target /restore
archive="$stage/payload/n8n-backup.tar.gz"
[[ -f "$archive" ]] || { echo "Snapshot does not contain an n8n backup payload." >&2; exit 1; }
mkdir "$stage/extracted"
tar -xzf "$archive" -C "$stage/extracted"
[[ -f "$stage/extracted/postgres.dump" && -f "$stage/extracted/n8n-data.tar.gz" && -f "$stage/extracted/.env" && -f "$stage/extracted/rclone.conf" ]] || { echo "Invalid backup payload." >&2; exit 1; }

backup_key="$(sed -n 's/^N8N_ENCRYPTION_KEY=//p' "$stage/extracted/.env" | tail -n 1)"
[[ "$backup_key" == "$N8N_ENCRYPTION_KEY" ]] || { echo "N8N_ENCRYPTION_KEY differs from the backup; refusing restore." >&2; exit 1; }

read -r -p "This REPLACES the current n8n database and data. Type RESTORE to continue: " confirmation
[[ "$confirmation" == "RESTORE" ]] || { echo "Cancelled."; exit 0; }

docker compose --env-file .env up -d postgres
docker compose --env-file .env stop n8n
docker compose --env-file .env exec -T postgres dropdb -U "$POSTGRES_USER" --if-exists "$POSTGRES_DB"
docker compose --env-file .env exec -T postgres createdb -U "$POSTGRES_USER" "$POSTGRES_DB"
docker compose --env-file .env exec -T postgres pg_restore -U "$POSTGRES_USER" -d "$POSTGRES_DB" --clean --if-exists --no-owner < "$stage/extracted/postgres.dump"
docker run --rm -v n8n_n8n_data:/data -v "$stage/extracted:/backup" alpine:3.20 sh -c 'rm -rf /data/* /data/.[!.]* /data/..?*; tar -C /data -xzf /backup/n8n-data.tar.gz'
docker compose --env-file .env up -d --wait --wait-timeout 180 n8n
echo "Restore completed."
