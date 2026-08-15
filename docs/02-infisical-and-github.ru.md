# 2. Infisical и GitHub OIDC

## Создайте проект и окружение

В Infisical создайте проект, затем окружение `prod`. Добавьте в него следующие secrets:

| Ключ | Пример / назначение |
| --- | --- |
| `VPS_HOST` | `203.0.113.10` или имя VPS |
| `VPS_USER` | `deploy` |
| `VPS_SSH_KEY` | приватная часть deployment SSH key |
| `VPS_PORT` | `22`; можно не создавать |
| `VPS_APP_DIR` | `/home/deploy/n8n` |
| `DOMAIN` | `n8n.example.com`, без `https://` |
| `CERTBOT_EMAIL` | ваш email для Let's Encrypt |
| `POSTGRES_PASSWORD` | длинный случайный пароль |
| `N8N_ENCRYPTION_KEY` | `openssl rand -hex 32` |
| `RCLONE_CONFIG_B64` | Base64 всего `rclone.conf` с remote `yadisk` |
| `RESTIC_PASSWORD` | `openssl rand -base64 48` |

`N8N_ENCRYPTION_KEY` нельзя менять после появления credentials в n8n. `RESTIC_PASSWORD` нужен для чтения архивов restic. Сохраните оба значения и исходный `rclone.conf` в отдельном защищённом break-glass record, например в password manager с ограниченным доступом.

## Создайте Machine Identity

1. В проекте откройте **Access Control → Machine Identities** и создайте identity, например `github-n8n-deploy`.
2. Дайте ему только read-доступ к окружению `prod` этого проекта.
3. Удалите Universal Auth и добавьте **OIDC Auth**.
4. Заполните настройки:

| Поле | Значение |
| --- | --- |
| Discovery URL | `https://token.actions.githubusercontent.com` |
| Issuer | `https://token.actions.githubusercontent.com` |
| Subject | `repo:OWNER/REPOSITORY:environment:production` |
| Audience | `https://github.com/OWNER` |

Замените `OWNER` и `REPOSITORY` точными именами. Не используйте wildcard `*`: subject с `environment:production` разрешает запросы только workflow, прошедшим GitHub Environment `production`.

Скопируйте **Identity ID** и Project slug. Это публичные идентификаторы, их допустимо хранить в GitHub Variables.

## Настройте GitHub

1. В **Settings → Environments** создайте `production`.
2. Для защиты production включите required reviewers, если это соответствует вашему процессу.
3. В **Settings → Secrets and variables → Actions → Variables** добавьте:

| Variable | Значение |
| --- | --- |
| `INFISICAL_IDENTITY_ID` | Identity ID из Infisical |
| `INFISICAL_PROJECT_SLUG` | slug проекта |
| `INFISICAL_ENV_SLUG` | `prod` |

Переменные можно задать на уровне repository или environment `production`. Никаких GitHub Secrets для этого репозитория не требуется.

Workflow запрашивает GitHub OIDC token (`id-token: write`), Infisical проверяет subject/audience и предоставляет секреты только на период job. Не добавляйте команды `echo $SECRET` и не включайте `set -x` в workflow.

Перейдите к [первому деплою](03-deploy-and-recovery.ru.md).
