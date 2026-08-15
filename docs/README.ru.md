# n8n на VPS: документация на русском

Этот репозиторий автоматически разворачивает n8n на одной Ubuntu VPS. Ansible настраивает сервер, Docker, firewall, HTTPS, systemd timers и Compose; GitHub Actions запускает Ansible; Infisical выдаёт секреты по короткоживущему GitHub OIDC-токену.

## Порядок настройки

1. [Подготовить VPS, DNS и доступ](01-prerequisites.ru.md).
2. [Настроить Infisical и GitHub OIDC](02-infisical-and-github.ru.md).
3. [Запустить деплой, проверить сервис и выполнить recovery](03-deploy-and-recovery.ru.md).

После первого запуска обычное обновление — это push в ветку `main` или ручной запуск workflow **Deploy n8n with Ansible**.

## Что не хранится в GitHub и Git

Значения `VPS_SSH_KEY`, пароли PostgreSQL/R2, `N8N_ENCRYPTION_KEY` и `RESTIC_PASSWORD` находятся только в Infisical. GitHub хранит только публичные идентификаторы Infisical в Actions variables. На VPS Ansible создаёт рабочий `.env` с правами `0600`; Docker Compose использует его для запуска контейнеров.

## Архитектура

```text
Интернет
  │ HTTPS :443 / ACME :80
  ▼
nginx ──► n8n ──► PostgreSQL 16
                │
                └──► restic (зашифрованный backup) ──► Cloudflare R2
```

PostgreSQL и n8n не имеют опубликованных портов. Внешне доступны только TCP 80 и 443 через nginx.
