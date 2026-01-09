function find_hardlinks
    # Парсинг аргументов:
    # 'd/dir=' означает, что флаг -d (или --dir) требует значения
    argparse 'd/dir=' -- $argv
    or return

    # 1. Определение каталога поиска
    # Переменная будет локальной (-l)
    set -l search_path $HOME
    
    # Если флаг был задан, используем его значение
    if set -q _flag_d
        set search_path $_flag_d
    end

    # 2. Проверка, что имя файла передано (осталось в argv после argparse)
    if test (count $argv) -eq 0
        echo "Использование: find_hardlinks [-d /путь/к/каталогу] <файл>"
        return 1
    end

    set -l target_file $argv[1]

    # 3. Проверка существования файла
    if not test -e $target_file
        echo "Ошибка: Файл '$target_file' не найден."
        return 1
    end

    echo "Поиск жестких ссылок для '$target_file' в '$search_path'..."

    # 4. Сам поиск
    find $search_path -samefile $target_file 2>/dev/null
end
