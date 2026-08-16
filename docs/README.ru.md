# n8n на VPS: документация на русском

Этот репозиторий автоматически разворачивает n8n на одной Ubuntu VPS. Ansible настраивает сервер, Docker, firewall, HTTPS, systemd timers, лёгкий мониторинг Netdata и Compose; GitHub Actions запускает Ansible; Infisical выдаёт секреты по короткоживущему GitHub OIDC-токену.

## Порядок настройки

1. [Подготовить VPS, DNS и доступ](01-prerequisites.ru.md).
2. [Настроить Infisical и GitHub OIDC](02-infisical-and-github.ru.md).
3. [Запустить деплой, проверить сервис и выполнить recovery](03-deploy-and-recovery.ru.md).

После первого запуска обычное обновление — это push в ветку `main` или ручной запуск workflow **Deploy n8n with Ansible**.

## Что не хранится в GitHub и Git

Значения `VPS_SSH_KEY`, пароль PostgreSQL, OAuth-конфигурация Яндекс Диска, `N8N_ENCRYPTION_KEY` и `RESTIC_PASSWORD` находятся только в Infisical. GitHub хранит только публичные идентификаторы Infisical в Actions variables. На VPS Ansible создаёт рабочий `.env` с правами `0600`; Docker Compose использует его для запуска контейнеров.

## Архитектура

```text
Интернет
  │ HTTPS :443 / ACME :80
  ▼
nginx ──► n8n ──► PostgreSQL 16
                │
                └──► restic (зашифрованный backup) ──► rclone ──► Яндекс Диск

Netdata (только 127.0.0.1:19999) ──► метрики VPS
```

PostgreSQL и n8n не имеют опубликованных портов. Внешне доступны только TCP 80 и 443 через nginx. Netdata слушает только `127.0.0.1:19999`; подключайтесь к нему через SSH-туннель:

```bash
ssh -N -L 19999:127.0.0.1:19999 deploy@VPS_IP
```

После этого откройте `http://localhost:19999`. Dashboard показывает CPU, память, диск, сеть и процессы. У Netdata есть только read-only доступ к телеметрии хоста; у него нет доступа к Docker socket, данным n8n или PostgreSQL.
