function mount-remote-dir-by-rclone
    # Зависимость: rclone
    if not type -q rclone
        echo "Ошибка: Не найден 'rclone'. Установите: sudo pacman -S rclone"
        return 1
    end

    # --- 0. Настройки и Права ---
    set -l global_var "mount_remote_dir_configs"
    set -l root_cmd (functions -q get_root_cmd; and get_root_cmd; or echo "sudo")

    if not set -q argv[1]
        echo "Использование: mount-remote-dir-by-rclone [up|down|list|forget]"
        return 1
    end

    set -l command $argv[1]

    # --- 1. Вспомогательные функции ---

    function _get_rclone_configs --inherit-variable global_var
        if not set -q $global_var
            return
        end
        for entry in $$global_var
            if string match -q "rclone::*" -- $entry
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
            # Format: rclone::Host::RemotePath::LocalPath::Opts
            set -l parts (string split "::" -- $line)
            # Извлекаем тип и юзера из опций для красивого отображения
            set -l opts $parts[5]
            set -l type (string match -r "type=([^,]+)" $opts)[2]
            
            set -a text_to_show "$idx. [$type] $parts[2]:$parts[3] -> $parts[4]"
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
            set -l configs (_get_rclone_configs)
            set -l selection ""
            
            if test (count $configs) -eq 0
                echo "Конфигураций Rclone не найдено."
                set selection "new"
            else
                _print_list_nicely $configs
                echo "------------------------------------------------"
                echo "Введите номера (можно диапазоны, 'all'),"
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
                set -l type "webdav" # По умолчанию
                set -l password ""

                if test $is_new_entry -eq 1
                    # --- Режим WIZARD ---
                    echo \n"--- Добавление нового Rclone подключения (On-the-fly) ---"
                    
                    # 1. Тип подключения
                    read -P "Тип протокола (webdav, ftp, sftp, smb): [webdav] " input_type
                    if test -n "$input_type"
                        set type $input_type
                    end

                    # 2. Хост
                    read -P "Хост (IP или домен): " host
                    read -P "Порт (Enter для стандартного): " port
                    if test -n "$port"
                        set host "$host:$port"
                    end
                    
                    # Для WebDAV добавляем http/https если не указано (rclone требует url)
                    if test "$type" = "webdav"
                        if not string match -q "*://*" -- $host
                            # Эвристика: если порт 5005 - http, иначе https
                            if string match -q "*:5005" -- $host
                                set host "http://$host"
                            else
                                set host "https://$host"
                            end
                        end
                    end

                    # 3. Пути и Юзер
                    read -P "Путь на сервере (например /deluge): " rpath
                    read -P "Локальный путь (/mnt/...): " lpath
                    read -P "Имя пользователя: " username
                    
                    # Вендор (важно для Synology WebDAV)
                    set -l vendor_opt ""
                    if test "$type" = "webdav"
                        read -P "Vendor (synology, nextcloud, other): [synology] " vendor
                        if test -z "$vendor"
                            set vendor "synology"
                        end
                        set vendor_opt ",vendor=$vendor"
                    end

                    read -P "Доп. флаги rclone (Enter если пусто): " extra_opts
                    
                    # Сохраняем всё важное в opts
                    set opts "type=$type,user=$username$vendor_opt"
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
                    
                    set username (string match -r "user=([^,]+)" $opts)[2]
                    set type (string match -r "type=([^,]+)" $opts)[2]
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

                # --- Монтирование ---
                echo "Монтируем ($type) $host:$rpath в $lpath..."
                
                if not test -d $lpath
                    $root_cmd mkdir -p $lpath
                    $root_cmd chown (id -u):(id -g) $lpath
                end

                # 1. Генерируем "запутанный" пароль для rclone
                set -l obscured_pass (rclone obscure "$password")

                # 2. Формируем имя временного ремута
                set -l remote_name "TEMP_MOUNT_$idx"

                # 3. Устанавливаем переменные окружения для конфигурации "на лету"
                # Rclone читает переменные вида RCLONE_CONFIG_ИМЯ_ПАРАМЕТР
                
                # Базовые параметры
                set -x RCLONE_CONFIG_{$remote_name}_TYPE "$type"
                set -x RCLONE_CONFIG_{$remote_name}_USER "$username"
                # Rclone obscure pass
                set -x RCLONE_CONFIG_{$remote_name}_PASS "$obscured_pass"

                # Специфичные параметры URL/Host
                if test "$type" = "webdav"
                    set -x RCLONE_CONFIG_{$remote_name}_URL "$host"
                    # Достаем vendor из opts
                    set -l vendor (string match -r "vendor=([^,]+)" $opts)[2]
                    if test -n "$vendor"
                        set -x RCLONE_CONFIG_{$remote_name}_VENDOR "$vendor"
                    end
                else
                    # Для sftp, ftp и других host передается как host
                    set -x RCLONE_CONFIG_{$remote_name}_HOST "$host"
                end

                # 4. Параметры запуска
                set -l base_args "--daemon" "--vfs-cache-mode" "full"
                
                # Фильтруем opts, чтобы убрать наши служебные поля (type, user, vendor)
                # и оставить только реальные флаги rclone, если они там были
                # (в текущей реализации extra_opts попадает в хвост, можно просто добавить их)

                # Запуск
                # Используем временное имя ремута и путь
                rclone mount "$remote_name:$rpath" "$lpath" $base_args

                sleep 2 

                # Очищаем переменные (на всякий случай, хотя set -l и так локальные, 
                # но set -x делает их экспортируемыми для дочерних процессов)
                set -e RCLONE_CONFIG_{$remote_name}_TYPE
                set -e RCLONE_CONFIG_{$remote_name}_PASS
                # ... остальные очистятся сами при выходе из функции

                if mountpoint -q $lpath
                    echo "✅ Успешно!"
                    if test $is_new_entry -eq 1
                        # Сохраняем в нашем формате
                        set -l new_record "rclone::$host::$rpath::$lpath::$opts"
                        set -Ua $global_var $new_record
                        echo "📝 Запись сохранена."
                    end
                else
                    echo "❌ Ошибка монтирования!" 
                    # Для отладки можно раскомментировать:
                    # echo "Debug: Type=$type URL=$host User=$username"
                end
            end

        # === DOWN ===
        case "down"
            set -l configs (_get_rclone_configs)
            set -l active_mounts
            set -l display_list
            
            for entry in $configs
                set -l parts (string split "::" -- $entry)
                set -l lpath $parts[4]
                if mountpoint -q $lpath
                    set -a active_mounts $entry
                    set -l host $parts[2]
                    set -a display_list "$host -> $lpath"
                end
            end

            if test (count $active_mounts) -eq 0
                echo "Нет активных Rclone-монтирований из вашего списка."
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
                if type -q fusermount
                    fusermount -u $lpath
                else
                    $root_cmd umount $lpath
                end
                
                if test $status -eq 0
                     rmdir $lpath 2>/dev/null
                     echo "✅ Готово"
                else
                     echo "❌ Ошибка размонтирования"
                end
            end

        # === LIST / FORGET (Аналогично другим скриптам) ===
        case "list"
             set -l configs (_get_rclone_configs)
             _print_list_nicely $configs

        case "list-all"
             if set -q $global_var
                 _print_list_nicely $$global_var
             else
                 echo "Переменная пуста."
             end

        case "forget"
            set -l configs (_get_rclone_configs)
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

            echo "⚠️  ВНИМАНИЕ: Записи будут удалены."
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
