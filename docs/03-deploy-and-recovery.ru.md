# 3. Деплой, проверка и восстановление

## Первый деплой

Откройте GitHub Actions, выберите workflow **Deploy n8n with Ansible** и нажмите **Run workflow** для `main`, либо сделайте push в `main`.

Workflow выполняет следующее:

1. Запрашивает временный OIDC token и забирает secrets из Infisical.
2. Копирует текущую версию репозитория на VPS.
3. Устанавливает Docker Engine, Docker Compose v2, UFW и включает Docker.
4. Открывает SSH-порт, 80/tcp и 443/tcp в UFW.
5. Создаёт `/home/deploy/n8n/.env` с owner `root` и mode `0600`.
6. Устанавливает systemd timers для backup и renewal.
7. Запускает Compose (включая Netdata), получает сертификат Let's Encrypt и ожидает healthcheck n8n.

После успеха откройте `https://n8n.example.com`. На первом входе n8n предложит создать owner account.

## Проверка на VPS

Подключитесь к VPS и выполните:

```bash
cd /home/deploy/n8n
sudo docker compose --env-file .env ps
sudo docker compose --env-file .env logs --tail=100 n8n
sudo docker compose --env-file .env ps netdata
sudo systemctl list-timers n8n-backup.timer n8n-certbot-renew.timer
```

Ожидаются работающие `postgres`, `n8n`, `nginx` и `netdata`. Netdata доступен только с VPS через `127.0.0.1:19999`; с рабочего компьютера используйте `ssh -N -L 19999:127.0.0.1:19999 deploy@VPS_IP` и откройте `http://localhost:19999`. Не публикуйте и не копируйте содержимое `.env` в тикеты, логи или Git.

Alert `10min_cpu_usage` определён в `netdata/health.d/cpu.conf`: warning при среднем CPU выше 60% за 10 минут и critical при 70%.

## Обновление

Изменения в Compose, nginx и Ansible выкатываются push в `main`. Для обновления n8n измените зафиксированный `N8N_IMAGE` в `ansible/roles/n8n/templates/runtime.env.j2`, изучите upstream release notes и после деплоя проверьте критичные workflows/webhooks.

Перед крупным обновлением можно вручную запустить backup:

```bash
sudo /home/deploy/n8n/scripts/backup.sh
```

## Backup и retention

Timer `n8n-backup.timer` запускается каждый день около 03:17 UTC. Restic шифрует PostgreSQL dump, том n8n, `.env` и конфигурацию rclone, затем через rclone загружает данные на Яндекс Диск. Хранятся 7 daily, 4 weekly и 6 monthly snapshots.

Проверить последний результат:

```bash
sudo journalctl -u n8n-backup.service -n 100 --no-pager
```

## Полное восстановление после потери VPS

1. Создайте новую Ubuntu VPS и восстановите DNS запись.
2. Создайте пользователя `deploy`, его SSH access и passwordless sudo как в первом гайде.
3. Не меняйте secrets `N8N_ENCRYPTION_KEY`, `RESTIC_PASSWORD` и `RCLONE_CONFIG_B64` в Infisical.
4. Запустите workflow — Ansible создаст инфраструктуру и пустой стек.
5. На новой VPS выполните:

```bash
cd /home/deploy/n8n
sudo ./scripts/restore.sh latest
```

Чтобы выбрать конкретную точку, список snapshot можно получить так:

```bash
cd /home/deploy/n8n
sudo docker run --rm --env-file .env restic/restic:0.17.3 snapshots
```

Затем передайте ID вместо `latest`. Скрипт проверит encryption key и попросит ввести `RESTORE`; после подтверждения он заменит текущие PostgreSQL и n8n данные.

## Типовые ошибки

| Симптом | Что проверить |
| --- | --- |
| Certbot не выпускает сертификат | DNS, открытый TCP 80, отсутствие другого web server на 80/443 |
| Infisical OIDC error | Subject, audience, Project slug, Environment slug и `id-token: write` |
| Ansible не подключается | `VPS_HOST`, `VPS_USER`, private key, SSH-порт и `sudo -n true` |
| Backup не работает | корректность `RCLONE_CONFIG_B64`, доступ Яндекс Диска и `RESTIC_PASSWORD` |
