function save_local_torrents --argument-names dest_dir --description 'Export loaded .torrents from local Deluge with human readable names'
    
    # 1. Проверяем аргумент (куда сохранять)
    if test -z "$dest_dir"
        set dest_dir "$HOME/Desktop/exported_torrents"
        echo "📂 Папка не указана, сохраняем в: $dest_dir"
    end

    mkdir -p "$dest_dir"

    # Путь к локальному хранилищу торрентов Deluge (стандартный для Arch)
    set source_state "$HOME/.config/deluge/state"

    echo "🔍 Сканируем локальный Deluge..."
    echo "---------------------------------------------------"

    # Инициализируем счетчик
    set count 0

    # 2. Магия AWK
    # Мы просим deluge-console вывести список. 
    # AWK ловит строку "Name: ..." запоминает имя.
    # Затем ловит строку "ID: ..." и печатает "ID|Имя".
    # Разделитель '|' нужен, чтобы fish мог легко разбить строку.
    
    deluge-console "info" | awk '/^Name:/ { name=substr($0, 7) } /^ID:/ { print $2 "|" name }' | while read -l line
        
        # Разбиваем строку на ID и Имя
        set parts (string split "|" $line)
        set id $parts[1]
        set raw_name $parts[2]

        # 3. Санитизация имени файла (очень важно!)
        # Заменяем слеши / на подчеркивания _, чтобы не сломать пути
        # Заменяем кавычки и прочий мусор
        set safe_name (string replace -a "/" "_" "$raw_name")
        set safe_name (string replace -a "'" "" "$safe_name")
        set safe_name (string replace -a '"' '' "$safe_name")

        # Путь к исходному файлу (хеш)
        set source_file "$source_state/$id.torrent"
        # Путь назначения (красивое имя)
        set dest_file "$dest_dir/$safe_name.torrent"

        if test -f "$source_file"
            cp "$source_file" "$dest_file"
            echo "✅ $safe_name.torrent"
            set count (math $count + 1)
        else
            set_color yellow
            echo "⚠️  Файл для '$safe_name' (ID: $id) не найден в state!"
            set_color normal
        end
    end

    echo "---------------------------------------------------"
    set_color green
    echo "🎉 Успешно экспортировано: $count файлов в $dest_dir"
    set_color normal
end
