function smart-mv --description "Smart Move: умное перемещение файлов с обработкой дубликатов и конфликтов имен"
    # Настройки
    set -l MAX_NAME_LEN 250

    if test (count $argv) -lt 2
        echo "Использование: smart-mv файл1 [файл2 ...] каталог_назначения"
        return 1
    end

    set -l dest_dir "$argv[-1]"
    
    mkdir -p "$dest_dir"
    if not test -d "$dest_dir"
        echo "Ошибка: '$dest_dir' не является каталогом."
        return 1
    end
    
    # Получаем абсолютный путь назначения для точного сравнения
    set -l dest_abs (realpath "$dest_dir")

    for src in $argv[1..-2]
        if not test -e "$src"
            echo "Файл '$src' не найден."
            continue
        end
        
        # ЗАЩИТА ОТ РЕКУРСИИ
        # Если абсолютный путь источника совпадает с назначением -> пропускаем
        set -l src_abs (realpath "$src")
        if test "$src_abs" = "$dest_abs"
            echo "Пропуск: '$src' является папкой назначения."
            continue
        end

        set -l filename (basename "$src")
        set -l target "$dest_dir/$filename"

        # СЦЕНАРИЙ 1: Файла назначения нет
        if not test -e "$target"
            rsync -ah --remove-source-files "$src" "$dest_dir"
            continue
        end

        # СЦЕНАРИЙ 2: Файл есть, дубликат
        if cmp -s "$src" "$target"
            echo "[=] $filename дубликат. Удаляю исходник."
            rm "$src"
            continue
        end

        # СЦЕНАРИЙ 3: Файл есть, конфликт имен
        set -l ext (path extension "$target")
        set -l timestamp (date "+%Y-%m-%d-%H-%M-%S-%3N")
        set -l suffix "-$timestamp$ext"
        
        set -l suffix_len (string length -- "$suffix")
        set -l available_len (math $MAX_NAME_LEN - $suffix_len)
        set -l old_filename "$filename"
        
        set -l backup_name "" # Объявляем ДО условий
        
        if test (string length -- "$old_filename") -gt $available_len
            set -l trimmed_name (string sub --length $available_len -- "$old_filename")
            set backup_name "$trimmed_name$suffix"
            echo "[!] Имя длинное. Обрезано до: $backup_name"
        else
            set backup_name "$old_filename$suffix"
        end

        mv "$target" "$dest_dir/$backup_name"
        rsync -ah --remove-source-files "$src" "$dest_dir"
        echo "[+] $filename обновлен -> старый сохранен как $backup_name"
    end
end
