# 1. Подготовка VPS, DNS и доступа

## Требования

- Ubuntu VPS с публичным IPv4 или IPv6.
- Домен или поддомен, например `n8n.example.com`.
- Учётная запись Яндекс Диска.
- Репозиторий GitHub с включёнными Actions.

Не устанавливайте Docker, nginx, Certbot или cron вручную: это сделает Ansible. До первого запуска 80 и 443 не должны быть заняты другим сервисом.

## DNS

Создайте запись DNS до запуска workflow:

| Тип | Имя | Значение |
| --- | --- | --- |
| `A` | `n8n` | публичный IPv4 VPS |
| `AAAA` | `n8n` | публичный IPv6 VPS, если он используется |

Проверьте с локального компьютера:

```bash
dig +short n8n.example.com A
dig +short n8n.example.com AAAA
```

Результат должен совпадать с адресом VPS. Let's Encrypt не выпустит сертификат, пока запись не распространилась и порт 80 не доступен извне.

## Пользователь для деплоя

Создайте на VPS отдельного пользователя, например `deploy`, добавьте его SSH public key и дайте только ему passwordless `sudo`:

```bash
sudo adduser --disabled-password --gecos '' deploy
sudo usermod -aG sudo deploy
sudo install -d -m 700 -o deploy -g deploy /home/deploy/.ssh
sudo install -m 600 -o deploy -g deploy /dev/null /home/deploy/.ssh/authorized_keys
sudo visudo -f /etc/sudoers.d/n8n-deploy
```

В открывшемся файле добавьте:

```sudoers
deploy ALL=(ALL) NOPASSWD: ALL
```

Добавьте public-часть выделенного deployment key в `/home/deploy/.ssh/authorized_keys`. Убедитесь, что подключение работает:

```bash
ssh -i ~/.ssh/n8n_deploy deploy@VPS_IP 'sudo -n true && echo OK'
```

Для безопасного доступа ограничьте SSH key только этим пользователем и, если возможно, настройте ограничения по IP GitHub Actions либо используйте VPN/bastion. При нестандартном SSH-порте сохраните его как `VPS_PORT` в Infisical.

## Яндекс Диск

Для первой OAuth-настройки установите `rclone` на локальный компьютер. На Windows:

```powershell
winget install Rclone.Rclone
```

Создайте remote с точным именем `yadisk`:

```powershell
rclone --config .\n8n-rclone.conf config
```

В мастере выберите `n` (new remote), имя `yadisk`, storage type `yandex`, оставьте Client ID/Secret пустыми и согласитесь на browser authorization. Войдите в Яндекс-аккаунт и разрешите доступ. Не делайте это на VPS: токен будет передан в Infisical, а rclone на сервере запустится автоматически.

После успешной настройки закодируйте весь файл конфигурации в одну строку:

```powershell
$config = Join-Path $PWD 'n8n-rclone.conf'
[Convert]::ToBase64String([IO.File]::ReadAllBytes($config))
```

Сохраните получившуюся строку как `RCLONE_CONFIG_B64` в Infisical. Не публикуйте её: внутри OAuth token Яндекс Диска. Backup-репозиторий будет храниться в папке `n8n-restic` на Диске.

Продолжайте с [настройкой Infisical и GitHub](02-infisical-and-github.ru.md).
