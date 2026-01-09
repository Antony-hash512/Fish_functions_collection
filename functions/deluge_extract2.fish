function deluge_extract2 --description 'Extract .torrent files by Path OR by Name (-n)'
    # 1. Парсинг аргументов
    # -n или --name включает режим поиска по имени
    # $argv останется содержать только позиционные аргументы (строка поиска и путь назначения)
    argparse 'n/name' -- $argv
    or return

    # Проверка обязательного аргумента
    if test (count $argv) -lt 1
        set_color red
        echo "Ошибка: Не указана строка поиска."
        set_color normal
        echo "Использование:"
        echo "  По пути:  deluge_extract2 '/mnt/data/linux_isos' [куда]"
        echo "  По имени: deluge_extract2 --name 'Ubuntu' [куда]"
        return 1
    end

    set search_term $argv[1]
    
    # Папка назначения (по умолчанию - текущая)
    if set -q argv[2]
        set dest_dir $argv[2]
    else
        set dest_dir "."
    end

    mkdir -p $dest_dir

    # 2. Выбор логики AWK в зависимости от флага
    if set -q _flag_name
        echo "🔍 Режим: Поиск по ИМЕНИ (Name: $search_term)"
        # Логика для Имени: Сначала идет Name, потом ID.
        # Если строка начинается с Name: и содержит наш текст -> ставим флаг found=1
        # Если следующая строка ID: и флаг стоит -> печатаем ID и сбрасываем флаг.
        set awk_script '/^Name:/ { found = index($0, pat) } /^ID:/ { if (found) { print $2; found=0 } }'
    else
        echo "🔍 Режим: Поиск по ПУТИ (Path: $search_term)"
        # Логика для Пути: Сначала идет ID, потом где-то внизу Download Folder.
        # Если строка ID: -> запоминаем curr_id
        # Если строка содержит путь -> печатаем запомненный curr_id
        set awk_script '/^ID:/ { curr_id = $2 } index($0, pat) { if (curr_id) { print curr_id; curr_id="" } }'
    end

    echo "---------------------------------------------------"

    set count 0

    # 3. Выполнение
    for id in (deluge-console "info -v" | awk -v pat="$search_term" $awk_script)
        
        set torrent_file "$HOME/.config/deluge/state/$id.torrent"
        
        if test -f "$torrent_file"
            cp "$torrent_file" "$dest_dir/"
            echo "✅ Скопирован: $id.torrent"
            set count (math $count + 1)
        else
            set_color yellow
            echo "⚠️  ID найден ($id), но файл .torrent отсутствует!"
            set_color normal
        end
    end

    echo "---------------------------------------------------"
    if test $count -eq 0
        set_color red
        echo "❌ Ничего не найдено."
        set_color normal
    else
        set_color green
        echo "🎉 Готово! Скопировано файлов: $count в $dest_dir"
        set_color normal
    end
end
