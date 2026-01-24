
**Context:** I am editing a Fish shell script located at `~/.config/fish/functions/mount-remote-dir-by-webdav.fish`. I need to fix a bug where `sudo` interrupts the `davfs` password pipe, and also auto-accept the server certificate.

**Task:** Locate the mounting execution logic inside the `case "up"` block (it should be near the end of the loop, around lines 130-150, after `set -l mount_opts`).

**1. Find this specific line (Code to Remove):**

```fish
printf "%s\n%s\n" "$username" "$password" | $root_cmd mount -t davfs -o "$mount_opts" "$full_url" "$lpath"

```

**2. Replace it with this block (New Code):**

```fish
# ВАЖНО: Обновляем sudo-токен заранее, чтобы запрос пароля root
# не сломал pipe с передачей пароля webdav
$root_cmd -v

# ВАЖНО: davfs2 берет пароль из stdin.
# Посылаем: Пароль + перевод строки + "y" (для сертификата) + перевод строки
printf "%s\ny\n" "$password" | $root_cmd mount -t davfs -o "$mount_opts" "$full_url" "$lpath"

```

**Action Required:** Please show me the final code snippet with 5 lines of context before and after the change, so I can verify the indentation and location in `nvim`.

---

Ошибки при попытке up'а были такие:

fireice@katana ~ 
🦀🐟 mount-remote-dir-by-webdav up
Конфигураций WebDAV не найдено.

--- Добавление нового WebDAV подключения ---
Пример хоста: https://webdav.yandex.ru или nextcloud.mydomain.com
Хост (URL): sysnas
Удаленный путь (напр. / или /remote.php/webdav): /deluge
Локальный путь (/mnt/...): /mnt/webdav/deluge
Имя пользователя: dema
Доп. опции (обычно пусто, но можно указать conf=...): 
Введите пароль для dema@sysnas (не отображается):
> ●●●●●●●●●●●●
Монтируем https://sysnas/deluge в /mnt/webdav/deluge...
[sudo: authenticate] Password: 
  Password:  Please enter the password to authenticate user dema with server
https://sysnas/deluge or hit enter for none.
  Password:  the server certificate does not match the server name
the server certificate is not trusted
  issuer:      Synology Inc., Taipel, TW
  subject:     Synology Inc., Taipel, TW
  identity:    synology
  fingerprint: 29:35:c4:53:62:30:36:b6:9b:ad:91:bb:4e:b4:a2:99:bd:23:24:01
You only should accept this certificate, if you can
verify the fingerprint! The server might be faked
or there might be a man-in-the-middle-attack.
Mounting failed.
Server certificate verification failed: certificate issued for a different hostname, issuer is not trusted
Accept certificate for this session? [y,N] ❌ Ошибка монтирования!
