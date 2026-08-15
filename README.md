# Self-hosted n8n with Ansible

This repository uses Ansible to configure and deploy n8n, PostgreSQL 16, nginx, Let's Encrypt and encrypted restic backups to one existing Ubuntu VPS.

Русская документация: [оглавление](docs/README.ru.md), [быстрый запуск](docs/03-deploy-and-recovery.ru.md).

```text
Internet -> nginx (80/443) -> n8n -> PostgreSQL 16
                           -> restic-encrypted backup -> Yandex Disk
```

Only nginx publishes host ports. n8n and PostgreSQL are private Docker services; PostgreSQL also uses an internal-only Docker network.

## One-time external setup

Create an Ubuntu VPS and a DNS `A`/`AAAA` record for the n8n hostname. The SSH deployment user must have passwordless `sudo`. Create a Yandex Disk account and configure an rclone remote named `yadisk` as described in the Russian setup guide.

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

The Git repository never contains the runtime `.env`. The first deploy requires the DNS record to have propagated and port 80 to be externally reachable for the HTTP-01 challenge.

## Inventory and local runs

[production.example.yml](C:/Users/dleme/utils/homelab/ansible/inventory/production.example.yml) is an example only—do not add real hosts or secrets to Git. For a local run, export the same secret environment variables and use:

```bash
ansible-playbook -i 'YOUR_VPS_IP,' -u deploy --ask-become-pass \
  -e app_dir=/home/deploy/n8n ansible/playbooks/deploy.yml
```

## Backups and recovery

The `n8n-backup.timer` executes daily around 03:17 UTC. It snapshots a PostgreSQL dump, the n8n volume and runtime configuration through restic to Yandex Disk via rclone. Retention is 7 daily, 4 weekly and 6 monthly snapshots. Certificate renewal runs separately every day.

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
