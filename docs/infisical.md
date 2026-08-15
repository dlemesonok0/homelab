# Infisical OIDC setup

The deployment workflow fetches every secret from Infisical at runtime. GitHub stores no long-lived n8n, Yandex Disk, VPS or SSH-key secrets. The only GitHub configuration values are public identifiers for the Infisical project and its OIDC machine identity.

## 1. Create the Infisical project

Create a project, then create an environment with slug `prod` (or choose another fixed slug). Add these secrets to that environment:

| Key | Description |
| --- | --- |
| `VPS_HOST` | VPS IP address or hostname |
| `VPS_USER` | SSH deployment user with passwordless sudo |
| `VPS_SSH_KEY` | Private key used only for deployment |
| `VPS_PORT` | SSH port; optional, defaults to `22` |
| `VPS_APP_DIR` | Absolute path without spaces, e.g. `/home/deploy/n8n` |
| `DOMAIN` | Bare public n8n hostname |
| `CERTBOT_EMAIL` | Let's Encrypt contact email |
| `POSTGRES_PASSWORD` | Long random database password |
| `N8N_ENCRYPTION_KEY` | Generate with `openssl rand -hex 32`; never rotate casually |
| `RCLONE_CONFIG_B64` | Base64-encoded `rclone.conf` with a `yadisk` remote |
| `RESTIC_PASSWORD` | Generate with `openssl rand -base64 48`; required to restore backups |

Keep the Yandex Disk OAuth config and the SSH key limited to this deployment; do not reuse them for unrelated services.

## 2. Configure GitHub OIDC authentication

Create an Infisical Machine Identity and grant it read access to the selected project environment only. Replace the default Universal Auth method with OIDC and configure:

| Field | Value |
| --- | --- |
| Discovery URL | `https://token.actions.githubusercontent.com` |
| Issuer | `https://token.actions.githubusercontent.com` |
| Subject | `repo:OWNER/REPOSITORY:environment:production` |
| Audience | `https://github.com/OWNER` |

Replace `OWNER` and `REPOSITORY` with their exact values. The subject deliberately permits only jobs approved for GitHub Environment `production`; do not use a broad `repo:OWNER/REPOSITORY:*` pattern.

Copy the Machine Identity ID. It is a public identifier, not a secret.

## 3. Configure GitHub variables

At repository or `production` environment level, create these **Actions variables** (not secrets):

| Variable | Value |
| --- | --- |
| `INFISICAL_IDENTITY_ID` | Machine Identity ID from step 2 |
| `INFISICAL_PROJECT_SLUG` | Infisical project slug |
| `INFISICAL_ENV_SLUG` | Environment slug, for example `prod` |

The workflow requires `id-token: write` and exchanges a GitHub-issued, short-lived OIDC token for a short-lived Infisical token. It injects approved values only as environment variables for that job. Do not print these variables in workflow steps or enable shell tracing.

## Rotation and recovery

Rotate regular credentials by changing the Infisical value and deploying again. Preserve historical values of `N8N_ENCRYPTION_KEY` and `RESTIC_PASSWORD` in a separate access-controlled break-glass record: old n8n credentials and restic snapshots cannot be decrypted without them. For a disaster recovery deployment, the new workflow run reads the same values from Infisical and recreates the VPS-only `.env` with mode `0600`.
