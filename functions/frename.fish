function frename --description "Переименовать функцию fish (файл + определение)"
    # Проверяем аргументы
    if test (count $argv) -ne 2
        echo "Использование: frename <старое_имя> <новое_имя>"
        return 1
    end

    set -l old_name $argv[1]
    set -l new_name $argv[2]
    set -l func_dir ~/.config/fish/functions

    set -l old_file "$func_dir/$old_name.fish"
    set -l new_file "$func_dir/$new_name.fish"

    # 1. Проверки безопасности
    if not test -f "$old_file"
        echo "Ошибка: Файл функции '$old_name.fish' не найден."
        return 1
    end

    if test -f "$new_file"
        echo "Ошибка: Файл '$new_name.fish' уже существует."
        return 1
    end

    # 2. Переименовываем файл
    mv "$old_file" "$new_file"
    if test $status -ne 0
        echo "Ошибка при переименовании файла."
        return 1
    end

    # 3. Меняем имя функции внутри файла
    # Ищем строку, начинающуюся с "function old_name" (с учетом пробелов)
    # Используем sed с разделителем |, чтобы не экранировать лишнее
    sed -i "s|^ *function  *$old_name|function $new_name|" "$new_file"

    # 4. Чистим память текущей сессии
    # Удаляем старую функцию из памяти, чтобы она не висела в автодополнении до перезагрузки
    if functions -q $old_name
        functions -e $old_name
    end

    # Опционально: загружаем новую (хотя fish сделает это сам при вызове)
    # source "$new_file"

    set_color green
    echo "Успешно: $old_name -> $new_name"
    set_color normal
    echo "Файл: $new_file"
end
