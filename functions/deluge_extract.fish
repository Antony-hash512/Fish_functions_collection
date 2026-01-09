function deluge_extract --argument-names search_path dest_dir --description 'Extract .torrent files based on download path'
    # 1. Проверка обязательного аргумента (путь поиска)
    if test -z "$search_path"
        set_color red
        echo "Ошибка: Не указан путь поиска (откуда качались файлы)."
        set_color normal
        echo "Использование: deluge_extract <путь_в_deluge> [куда_сохранить]"
        return 1
    end

    # 2. Настройка папки назначения (по умолчанию - текущая)
    if test -z "$dest_dir"
        set dest_dir "."
        echo "📂 Папка назначения не задана, используем текущую: $PWD"
    else
        echo "📂 Папка назначения: $dest_dir"
    end

    # Создаем папку, если её нет
    mkdir -p $dest_dir

    echo "🔍 Поиск торрентов с путем: $search_path ..."
    echo "---------------------------------------------------"

    # Инициализируем счетчик
    set count 0

    # 3. Основная магия
    # deluge-console "info -v" выводит много текста.
    # awk -v pat="$search_path" передает переменную внутрь awk безопасно.
    # index($0, pat) ищет точное вхождение строки (лучше чем regex для путей).
    
    for id in (deluge-console "info -v" | awk -v pat="$search_path" '
        /^ID:/ { curr_id = $2 } 
        index($0, pat) { if (curr_id) { print curr_id; curr_id="" } }
    ')
        
        set torrent_file "$HOME/.config/deluge/state/$id.torrent"
        
        if test -f "$torrent_file"
            cp "$torrent_file" "$dest_dir/"
            echo "✅ Скопирован: $id.torrent"
            set count (math $count + 1)
        else
            set_color yellow
            echo "⚠️  ID найден ($id), но файл .torrent отсутствует в state!"
            set_color normal
        end
    end

    echo "---------------------------------------------------"
    if test $count -eq 0
        set_color red
        echo "❌ Ничего не найдено по этому пути."
        set_color normal
    else
        set_color green
        echo "🎉 Готово! Скопировано файлов: $count"
        set_color normal
        # 4. Показываем результат
        ls -lh "$dest_dir"
    end
end
