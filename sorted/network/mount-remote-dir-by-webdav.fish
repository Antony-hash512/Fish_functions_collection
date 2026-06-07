function mount-remote-dir-by-webdav --description "Mount remote WebDAV directories (davfs2) (up/down/list/forget)"

    # Ошибка Resource temporarily unavailable при работе с davfs2 — это классическая проблема, особенно в связке с Synology NAS.
    # Причина: davfs2 по умолчанию пытается заблокировать (lock) файл на сервере перед тем, как открыть его, чтобы предотвратить одновременное редактирование. Synology WebDAV часто некорректно обрабатывает эти блокировки или конфликтует с ними, из-за чего файловая система говорит "ресурс занят/недоступен".
    # Решение: Отключить блокировки
    # Вам нужно сказать драйверу davfs2: "Не пытайся блокировать файлы, просто читай их".
    # Выполните следующие шаги в терминале:

    #Создайте папку для пользовательского конфига (если её нет):
    #Code snippet

    #mkdir -p ~/.davfs2

    #Создайте (или дополните) файл конфигурации одной строкой: В Fish это можно сделать так:
    #Code snippet

    #echo "use_locks 0" >> ~/.davfs2/davfs2.conf

    #(Если файл уже был и там есть другие настройки — эта команда просто добавит строку в конец. Если файла не было — она его создаст).

    #Перемонтируйте папку: Настройки davfs2 считываются только в момент подключения.

    # Зависимость: пакет davfs2
    if not type -q mount.davfs
        echo "Ошибка: Не найдена утилита 'mount.davfs'. Установите пакет 'davfs2' (sudo pacman -S davfs2)."
        return 1
    end

    # --- 0. Настройки и Права ---
    set -l global_var "mount_remote_dir_configs"
    # Для davfs часто нужен root, так как монтирование происходит в системные папки, 
    # либо пользователь должен быть в группе davfs2
    set -l root_cmd (functions -q get_root_cmd; and get_root_cmd; or echo "sudo")

    if not set -q argv[1]
        echo "Использование: mount-remote-dir-by-webdav [up|down|list|forget]"
        return 1
    end

    set -l command $argv[1]

    # --- 1. Вспомогательные функции ---

    # Фильтруем конфиги только для WebDAV (префикс dav::)
    function _get_webdav_configs --inherit-variable global_var
        if not set -q $global_var
            return
        end
        for entry in $$global_var
            if string match -q "dav::*" -- $entry
                echo $entry
            end
        end
    end

    function _print_list_nicely
        set -l content $argv
        if test (count $content) -eq 0
            echo "Список пуст."
            return
        end
        
        set -l text_to_show
        set -l idx 1
        for line in $content
            # Format: dav::Host::RemotePath::LocalPath::Opts
            set -l parts (string split "::" -- $line)
            set -a text_to_show "$idx. $parts[2]$parts[3] -> $parts[4]"
            set idx (math $idx + 1)
        end
        
        if type -q bat
            string join \n $text_to_show | bat --plain --language=txt --paging=auto
        else
            string join \n $text_to_show | less -F -X
        end
    end

    # --- 2. Логика команд ---

    switch $command
        # === UP ===
        case "up"
            set -l configs (_get_webdav_configs)
            set -l selection ""
            
            if test (count $configs) -eq 0
                echo "Конфигураций WebDAV не найдено."
                set selection "new"
            else
                _print_list_nicely $configs
                echo "------------------------------------------------"
                echo "Введите номера (можно диапазоны '1-3', список '1 5', 'all'),"
                echo "'new' для создания нового или 'none' для отмены:"
                read -P "> " selection
            end

            if test "$selection" = "none"; or test -z "$selection"
                return 0
            end

            set -l targets
            set -l is_new_entry 0

            if test "$selection" = "new"
                set is_new_entry 1
                set targets 1
            else if test "$selection" = "all"
                set targets (seq (count $configs))
            else
                for item in (string split " " -- $selection)
                    if string match -r '^\d+-\d+$' -- $item
                        set -l range (string split "-" -- $item)
                        set -a targets (seq $range[1] $range[2])
                    else if string match -r '^\d+$' -- $item
                        set -a targets $item
                    end
                end
            end

            # Кэш паролей
            set -l cache_keys
            set -l cache_vals

            for idx in $targets
                set -l host ""
                set -l rpath ""
                set -l lpath ""
                set -l opts ""
                set -l username ""
                set -l password ""

                if test $is_new_entry -eq 1
                    # --- Режим WIZARD ---
                    echo \n"--- Добавление нового WebDAV подключения ---"
                    echo "Пример хоста: https://webdav.yandex.ru или nextcloud.mydomain.com"
                    read -P "Хост (URL): " host
                    read -P "Порт введите цифрами (5005=http, 5006=https): " port
                    if test -n "$port"
                        set host "$host:$port"
                    end
                    read -P "Удаленный путь (напр. / или /remote.php/webdav): " rpath
                    read -P "Локальный путь (/mnt/...): " lpath
                    read -P "Имя пользователя: " username
                    read -P "Доп. опции (обычно пусто, но можно указать conf=...): " extra_opts
                    
                    # Формируем строку опций, сохраняя username для кэша
                    set opts "username=$username"
                    if test -n "$extra_opts"
                        set opts "$opts,$extra_opts"
                    end
                else
                    # --- Режим из конфига ---
                    set -l config_str $configs[$idx]
                    set -l parts (string split "::" -- $config_str)
                    
                    set host $parts[2]
                    set rpath $parts[3]
                    set lpath $parts[4]
                    set opts $parts[5]
                    
                    set username (string match -r "username=([^,]+)" $opts)[2]
                end

                if mountpoint -q $lpath
                    echo "[$host] Папка $lpath уже примонтирована. Пропуск."
                    continue
                end

                # --- Логика Пароля ---
                set -l cache_key "$username@$host"
                set -l cached_idx (contains -i -- $cache_key $cache_keys)

                if test -n "$cached_idx"
                    set password $cache_vals[$cached_idx]
                    echo "Используем сохраненный пароль для $username@$host"
                else
                    echo "Введите пароль для $username@$host (не отображается):"
                    read -sP "> " password
                    set -a cache_keys $cache_key
                    set -a cache_vals $password
                end

                # --- Подготовка URL ---
                # Если протокол не указан:
                set -l full_url "$host"
                if not string match -q "http*" -- $host
                    # Если порт 5005 (Synology HTTP) -> http, иначе по умолчанию https
                    if string match -q "*:5005" -- $host
                        set full_url "http://$host"
                    else
                        set full_url "https://$host"
                    end
                end
                
                # Убираем лишние слеши при склейке
                set full_url (string trim -r -c / -- $full_url)
                set -l clean_rpath (string trim -l -c / -- $rpath)
                
                # Если rpath пустой, слеш не добавляем, иначе добавляем
                if test -n "$clean_rpath"
                    set full_url "$full_url/$clean_rpath"
                end

                # --- Монтирование ---
                echo "Монтируем $full_url в $lpath..."
                
                if not test -d $lpath
                    $root_cmd mkdir -p $lpath
                    $root_cmd chown (id -u):(id -g) $lpath
                end

                set -l uid (id -u)
                set -l gid (id -g)
                # Опции uid/gid важны, чтобы пользователь мог писать в папку davfs
                set -l mount_opts "uid=$uid,gid=$gid,$opts"

                # ВАЖНО: Обновляем sudo-токен заранее
                $root_cmd -v

                # ВАЖНО: davfs2 берет пароль из stdin.
                # Посылаем: Пароль + перевод строки + "y" (на случай запроса сертификата)
                printf "%s\ny\n" "$password" | $root_cmd mount -t davfs -o "$mount_opts" "$full_url" "$lpath"

                if test $status -eq 0
                    echo "✅ Успешно!"
                    if test $is_new_entry -eq 1
                        # Сохраняем с префиксом dav::
                        set -l new_record "dav::$host::$rpath::$lpath::$opts"
                        set -Ua $global_var $new_record
                        echo "📝 Запись сохранена."
                    end
                else
                    echo "❌ Ошибка монтирования!"
                    if test -n "$cached_idx"
                        set -e cache_keys[$cached_idx]
                        set -e cache_vals[$cached_idx]
                    end
                end
            end

        # === DOWN ===
        case "down"
            set -l configs (_get_webdav_configs)
            set -l active_mounts
            set -l display_list
            
            for entry in $configs
                set -l parts (string split "::" -- $entry)
                set -l lpath $parts[4]
                if mountpoint -q $lpath
                    set -a active_mounts $entry
                    set -a display_list "$parts[2] -> $lpath"
                end
            end

            if test (count $active_mounts) -eq 0
                echo "Нет активных WebDAV-монтирований из вашего списка."
                return 0
            end

            set -l list_idx 1
            for item in $display_list
                echo "$list_idx. $item"
                set list_idx (math $list_idx + 1)
            end

            echo "Введите номера для размонтирования (all, ranges):"
            read -P "> " selection

            if test "$selection" = "none"; or test -z "$selection"
                return
            end

            set -l targets
            if test "$selection" = "all"
                set targets (seq (count $active_mounts))
            else
                for item in (string split " " -- $selection)
                    if string match -r '^\d+-\d+$' -- $item
                        set -l range (string split "-" -- $item)
                        set -a targets (seq $range[1] $range[2])
                    else
                        set -a targets $item
                    end
                end
            end

            for t in $targets
                set -l raw_entry $active_mounts[$t]
                set -l parts (string split "::" -- $raw_entry)
                set -l lpath $parts[4]
                
                echo "Размонтирование $lpath..."
                $root_cmd umount $lpath
                
                if test $status -eq 0
                     rmdir $lpath 2>/dev/null
                     echo "✅ Готово"
                else
                     echo "❌ Ошибка размонтирования"
                end
            end

        # === LIST ===
        case "list"
             set -l configs (_get_webdav_configs)
             _print_list_nicely $configs

        case "list-all"
             if set -q $global_var
                 _print_list_nicely $$global_var
             else
                 echo "Переменная пуста."
             end

        # === FORGET ===
        case "forget"
            set -l configs (_get_webdav_configs)
            if test (count $configs) -eq 0
                echo "Список пуст."
                return
            end

            _print_list_nicely $configs
            echo "Введите номера для УДАЛЕНИЯ (или all):"
            read -P "> " selection
            
            if test -z "$selection"; or test "$selection" = "none"
                return
            end

            echo "⚠️  ВНИМАНИЕ: Выбранные записи WebDAV будут удалены."
            echo "Введите 'DELETE' для подтверждения:"
            read -P "> " confirm
            
            if test "$confirm" != "DELETE"
                echo "Отмена."
                return
            end

            set -l targets
            if test "$selection" = "all"
                set targets (seq (count $configs))
            else
                for item in (string split " " -- $selection)
                    if string match -r '^\d+-\d+$' -- $item
                        set -l range (string split "-" -- $item)
                        set -a targets (seq $range[1] $range[2])
                    else
                        set -a targets $item
                    end
                end
            end

            set -l strings_to_remove
            for t in $targets
                set -a strings_to_remove $configs[$t]
            end

            set -l new_global_list
            for entry in $$global_var
                if not contains -- $entry $strings_to_remove
                    set -a new_global_list $entry
                end
            end
            
            set -U $global_var $new_global_list
            echo "Записи удалены."

        case "*"
            echo "Неизвестная команда. Используйте: up, down, list, forget"
            return 1
    end
end
