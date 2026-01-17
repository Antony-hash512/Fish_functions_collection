function mount-remote-dir-by-smb
	#TODO: ключ для автомонтирования через systemd (если есть) с предупреждением, что пароль будет висеть в оперативке.
	#в субкоманде "list" добавить отображение статуса (смонтировано/не смонтировано).
    #ключ или сабкоманда для "размонтировать всё"

	# --- 0. Настройки и Права ---
    # Переменная хранения (общая для всех протоколов)
    set -l global_var "mount_remote_dir_configs"
    # Определение команды суперпользователя
    set -l root_cmd (functions -q get_root_cmd; and get_root_cmd; or echo "sudo")

    if not set -q argv[1]
        echo "Использование: mount-remote-dir-by-smb [up|down|list|forget]"
        return 1
    end

    set -l command $argv[1]

    # --- 1. Вспомогательные функции ---

    # Функция получения конфигов ТОЛЬКО для SMB
    function _get_smb_configs --inherit-variable global_var
        if not set -q $global_var
            return
        end
        for entry in $$global_var
            if string match -q "smb::*" -- $entry
                echo $entry
            end
        end
    end

    # Функция вывода списка через bat или cat
    function _print_list_nicely
        set -l content $argv
        if test (count $content) -eq 0
            echo "Список пуст."
            return
        end
        
        # Собираем красивый текст для вывода
        set -l text_to_show
        set -l idx 1
        for line in $content
            # Парсим для красоты: smb::Host::Remote::Local::Opts
            set -l parts (string split "::" -- $line)
            set -a text_to_show "$idx. $parts[2] ($parts[3]) -> $parts[4]"
            set idx (math $idx + 1)
        end
        
        # Если есть bat, используем его
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
            set -l configs (_get_smb_configs)
            set -l selection ""
            
            # Если конфигов нет, сразу идем в ветку создания NEW
            if test (count $configs) -eq 0
                echo "Конфигураций SMB не найдено."
                set selection "new"
            else
                # Выводим список
                _print_list_nicely $configs
                echo "------------------------------------------------"
                echo "Введите номера (можно диапазоны '1-3', список '1 5', 'all'),"
                echo "'new' для создания нового или 'none' для отмены:"
                read -P "> " selection
            end
            #Пустой Enter = Отмена (none). Это стандартное поведение для CLI-утилит:
            # "ничего не выбрал — значит, передумал".
            if test "$selection" = "none"; or test -z "$selection"
                return 0
            end

            # Массив для обработки (индексы или спецслова)
            set -l targets
            set -l is_new_entry 0

            if test "$selection" = "new"
                set is_new_entry 1
                set targets 1 # Фиктивный таргет, чтобы войти в цикл один раз
            else if test "$selection" = "all"
                set targets (seq (count $configs))
            else
                # Парсинг диапазонов и списков (1-3 5)
                for item in (string split " " -- $selection)
                    if string match -r '^\d+-\d+$' -- $item
                        set -l range (string split "-" -- $item)
                        set -a targets (seq $range[1] $range[2])
                    else if string match -r '^\d+$' -- $item
                        set -a targets $item
                    end
                end
            end

            # Кэш паролей для сессии: ключ=user@host, значение=pass
            # Fish не имеет словарей, эмулируем через две переменные
            set -l cache_keys
            set -l cache_vals

            for idx in $targets
                set -l host ""
                set -l rpath ""
                set -l lpath ""
                set -l opts ""
                set -l username ""
                set -l workgroup ""
                set -l password ""

                if test $is_new_entry -eq 1
                    # --- Режим WIZARD ---
                    echo \n"--- Добавление нового SMB подключения ---"
                    read -P "Хост/IP: " host
                    read -P "Путь на сервере (шара): " rpath
                    read -P "Локальный путь (/mnt/...): " lpath
                    read -P "Имя пользователя: " username
                    read -P "Workgroup (Enter если не нужно): " workgroup
                    read -P "Доп. опции монтирования (uid, gid автоматически): " extra_opts
                    
                    # Собираем строку опций
                    set opts "username=$username"
                    if test -n "$workgroup"
                        set opts "$opts,workgroup=$workgroup"
                    end
                    if test -n "$extra_opts"
                        set opts "$opts,$extra_opts"
                    end
                else
                    # --- Режим из конфига ---
                    # Получаем строку по индексу из отфильтрованного списка
                    set -l config_str $configs[$idx]
                    set -l parts (string split "::" -- $config_str)
                    
                    set host $parts[2]
                    set rpath $parts[3]
                    set lpath $parts[4]
                    set opts $parts[5]
                    
                    # Извлекаем username из опций для кэша паролей
                    set username (string match -r "username=([^,]+)" $opts)[2]
                end

                # Проверка: уже смонтировано?
                if mountpoint -q $lpath
                    echo "[$host] Папка $lpath уже примонтирована. Пропуск."
                    continue
                end

                # --- Логика Пароля ---
                set -l cache_key "$username@$host"
                set -l cached_idx (contains -i -- $cache_key $cache_keys)

                if test -n "$cached_idx"
                    # Пароль уже есть в кэше
                    set password $cache_vals[$cached_idx]
                    echo "Используем сохраненный пароль для $username@$host"
                else
                    # Запрашиваем пароль
                    echo "Введите пароль для $username@$host (не отображается):"
                    read -sP "> " password
                    # Сохраняем в кэш
                    set -a cache_keys $cache_key
                    set -a cache_vals $password
                end

                # --- Монтирование ---
                echo "Монтируем $host/$rpath в $lpath..."
                
                if not test -d $lpath
                    $root_cmd mkdir -p $lpath
                    $root_cmd chown (id -u):(id -g) $lpath
                end

                # [FIX] Динамические UID/GID текущего пользователя
                set -l uid (id -u)
                set -l gid (id -g)
                
                # [FIX] Базовые параметры протокола (utf8, smb v3.0)
                set -l base_smb_opts "iocharset=utf8,vers=3.0"
                
                # Собираем итоговую строку. Порядок важен: специфичные перекрывают базовые.
                set -l final_opts "$base_smb_opts,uid=$uid,gid=$gid,$opts,password=$password"

                # Вызов команды
                $root_cmd mount -t cifs -o "$final_opts" "//$host/$rpath" $lpath

                # --- Обработка результата ---
                if test $status -eq 0
                    echo "✅ Успешно!"
                    # Если это NEW, сохраняем в глобальную переменную
                    if test $is_new_entry -eq 1
                        set -l new_record "smb::$host::$rpath::$lpath::$opts"
                        # Важно: добавляем именно в глобальную переменную
                        set -Ua $global_var $new_record
                        echo "📝 Запись сохранена."
                    end
                else
                    echo "❌ Ошибка монтирования!"
                    # При ошибке пароль из кэша лучше удалить (вдруг он неправильный)
                    if test -n "$cached_idx"
                        set -e cache_keys[$cached_idx]
                        set -e cache_vals[$cached_idx]
                    end
                end
            end

        # === DOWN ===
        case "down"
            set -l configs (_get_smb_configs)
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
                echo "Нет активных SMB-монтирований из вашего списка."
                return 0
            end

            # Вывод списка
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
                # Тот же парсер диапазонов
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
                # Берем путь из active_mounts по выбранному номеру
                set -l raw_entry $active_mounts[$t]
                set -l parts (string split "::" -- $raw_entry)
                set -l lpath $parts[4]
                
                echo "Размонтирование $lpath..."
                $root_cmd umount $lpath
                
                if test $status -eq 0
                     # Пробуем удалить пустую папку для чистоты (опционально)
                     rmdir $lpath 2>/dev/null
                     echo "✅ Готово"
                else
                     echo "❌ Ошибка размонтирования"
                end
            end

        # === LIST ===
        case "list"
             set -l configs (_get_smb_configs)
             _print_list_nicely $configs

        case "list-all"
             # Просто дампим всю переменную
             if set -q $global_var
                 _print_list_nicely $$global_var
             else
                 echo "Переменная пуста."
             end

        # === FORGET ===
        case "forget"
            set -l configs (_get_smb_configs)
            if test (count $configs) -eq 0
                echo "Список пуст."
                return
            end

            _print_list_nicely $configs
            echo "Введите номера для УДАЛЕНИЯ (или all/none):"
            read -P "> " selection
            
            if test -z "$selection"; or test "$selection" = "none"
                return
            end

            echo "⚠️  ВНИМАНИЕ: Выбранные записи будут удалены."
            echo "Введите 'DELETE' для подтверждения:"
            read -P "> " confirm
            
            if test "$confirm" != "DELETE"
                echo "Отмена."
                return
            end

            # Вычисляем, какие ИМЕННО строки из ГЛОБАЛЬНОЙ переменной надо удалить.
            # Это сложно, т.к. индексы smb-списка не совпадают с индексами глобального списка.
            # Проще собрать новый глобальный список.
            
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

            # Создаем список строк, которые нужно удалить
            set -l strings_to_remove
            for t in $targets
                set -a strings_to_remove $configs[$t]
            end

            # Пересобираем глобальную переменную
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
