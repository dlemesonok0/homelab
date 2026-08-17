# Self-hosted n8n with Ansible

This repository uses Ansible to configure and deploy n8n, ntfy, PostgreSQL 16, nginx, Let's Encrypt, Netdata monitoring and encrypted restic backups to one existing Ubuntu VPS.

Русская документация: [оглавление](docs/README.ru.md), [быстрый запуск](docs/03-deploy-and-recovery.ru.md).

```text
Internet -> nginx (80/443) -> n8n -> PostgreSQL 16
                           -> ntfy (push notifications)
                           -> restic-encrypted backup -> Yandex Disk
```

Only nginx publishes public host ports. n8n, ntfy and PostgreSQL are private Docker services; PostgreSQL also uses an internal-only Docker network. Netdata listens only on `127.0.0.1:19999`, so it is reachable through an SSH tunnel rather than the Internet.

## One-time external setup

Create an Ubuntu VPS and DNS `A`/`AAAA` records for the n8n hostname and `NTFY_DOMAIN` (for example `push.example.com`). The SSH deployment user must have passwordless `sudo`. Create a Yandex Disk account and configure an rclone remote named `yadisk` as described in the Russian setup guide.

Create a GitHub Environment named `production` and use it for deployment approvals. Put all secrets in Infisical, not GitHub; follow [the Infisical OIDC setup guide](docs/infisical.md).

The GitHub workflow needs these **Actions variables** only (they are identifiers, not credentials):

| Variable | Purpose |
| --- | --- |
| `INFISICAL_IDENTITY_ID` | OIDC Machine Identity ID |
| `INFISICAL_PROJECT_SLUG` | Infisical project identifier |
| `INFISICAL_ENV_SLUG` | Infisical environment identifier, e.g. `prod` |

`N8N_ENCRYPTION_KEY` and `RESTIC_PASSWORD` must be preserved in an access-controlled break-glass record. Do not rotate either after data exists.

## Deployment

Push to `main` or run **Deploy n8n with Ansible**. The workflow transfers the current release, then executes [deploy.yml](C:/Users/dleme/utils/homelab/ansible/playbooks/deploy.yml) over SSH. Its roles idempotently:

- install Docker Engine, Docker Compose v2 and UFW;
- allow the configured SSH port and ports 80/443, then enable UFW;
- render VPS-only `.env` from GitHub Environment secrets with mode `0600`;
- install and enable renewal and backup systemd timers;
- start the Compose stack, obtain Let's Encrypt TLS, and wait for n8n's health check.

## Monitoring

Netdata provides a lightweight local dashboard for VPS metrics (CPU, memory, disk, network and processes). It is deliberately not exposed through nginx or UFW. From a trusted computer, open a tunnel and then visit `http://localhost:19999`:

```bash
ssh -N -L 19999:127.0.0.1:19999 deploy@YOUR_VPS_IP
```

Check its container status on the VPS with `sudo docker compose --env-file .env ps netdata`. Netdata has read-only access to host telemetry and no access to the n8n database, application data or Docker socket.

The Git repository never contains the runtime `.env`. The first deploy requires the DNS record to have propagated and port 80 to be externally reachable for the HTTP-01 challenge.

## Inventory and local runs

[production.example.yml](C:/Users/dleme/utils/homelab/ansible/inventory/production.example.yml) is an example only—do not add real hosts or secrets to Git. For a local run, export the same secret environment variables and use:

```bash
ansible-playbook -i 'YOUR_VPS_IP,' -u deploy --ask-become-pass \
  -e app_dir=/home/deploy/n8n ansible/playbooks/deploy.yml
```

## Backups and recovery

The `n8n-backup.timer` executes daily around 03:17 UTC. It snapshots a PostgreSQL dump, the n8n and ntfy volumes, and runtime configuration through restic to Yandex Disk via rclone. Retention is 7 daily, 4 weekly and 6 monthly snapshots. Certificate renewal runs separately every day.

## Notifications

ntfy is available at `https://NTFY_DOMAIN` and accepts the private topics `backups`, `netdata` and `n8n-errors` only with the `NTFY_TOKEN` bearer token. Subscribe in the ntfy mobile app using that server URL and token. Backup failures/successes and Netdata alerts are sent automatically. Deployment also provisions an `Infrastructure Error Notifications` workflow; select it in **Settings → Error Workflow** for each n8n workflow that should notify you.

```bash
sudo systemctl list-timers n8n-backup.timer n8n-certbot-renew.timer
sudo journalctl -u n8n-backup.service
```

To recover to a new VPS, create it, point DNS, configure the same GitHub secrets and run the workflow. Then, on the VPS:

```bash
cd /home/deploy/n8n
sudo ./scripts/restore.sh latest
```

The restore verifies `N8N_ENCRYPTION_KEY` and asks for literal `RESTORE` before replacing data.

## Images and availability

Image tags are pinned in `docker-compose.yml` and the Ansible runtime template. Update n8n deliberately, check upstream release notes and retain a known-good restic snapshot. This is a single-VPS deployment: backups enable recovery, not high availability.

