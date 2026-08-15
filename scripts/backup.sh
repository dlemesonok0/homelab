#!/usr/bin/env bash
set -Eeuo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT_DIR"
[[ -f .env ]] || { echo "Missing .env" >&2; exit 1; }
set -a
# shellcheck disable=SC1091
source .env
set +a

stage="$(mktemp -d)"
payload="$(mktemp -d)"
trap 'docker compose --env-file .env --profile backup stop rclone >/dev/null 2>&1 || true; rm -rf "$stage" "$payload"' EXIT
umask 077

docker compose --env-file .env exec -T postgres pg_dump -U "$POSTGRES_USER" -d "$POSTGRES_DB" --format=custom > "$stage/postgres.dump"
docker run --rm -v n8n_n8n_data:/data:ro -v "$stage:/backup" alpine:3.20 tar -C /data -czf /backup/n8n-data.tar.gz .
cp .env "$stage/.env"
cp rclone.conf "$stage/rclone.conf"
tar -C "$stage" -czf "$payload/n8n-backup.tar.gz" postgres.dump n8n-data.tar.gz .env rclone.conf

docker compose --env-file .env --profile backup up -d rclone
restic=(docker run --rm --network n8n_backup --env-file "$ROOT_DIR/.env" -v "$payload:/payload:ro" restic/restic:0.17.3)
repo_exists=false
for _ in {1..10}; do
  if "${restic[@]}" snapshots >/dev/null 2>&1; then
    repo_exists=true
    break
  fi
  sleep 2
done
if [[ "$repo_exists" != true ]]; then
  "${restic[@]}" init
fi
"${restic[@]}" backup /payload/n8n-backup.tar.gz --tag n8n
"${restic[@]}" forget --prune --keep-daily 7 --keep-weekly 4 --keep-monthly 6
