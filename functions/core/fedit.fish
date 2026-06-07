function fedit --description "Найти и открыть fish-функцию (используется $EDITOR)"
    set -l default_text_editor nvim
    set -l func_dir ~/.config/fish/functions
    
    # Временно переходим в папку функций, подавляя вывод ошибок
    pushd $func_dir 2>/dev/null

    # Получаем список файлов без расширения .fish
    # Если файлов нет, ls может вернуть ошибку, подавляем её, чтобы скрипт не падал
    set -l functions_list (string replace -r '\.fish$' '' (ls *.fish 2>/dev/null))

    if test -z "$functions_list"
        echo "Функции не найдены в $func_dir"
        popd 2>/dev/null
        return 1
    end

    # --- ЛОГИКА ВЫБОРА ПРОСМОТРЩИКА ---
    set -l preview_cmd ""
    
    # 1. Проверяем наличие 'bat' (лучший вариант)
    if command -v bat > /dev/null
        # --color=always: обязательно для fzf
        # --style=numbers: показывает номера строк
        set preview_cmd "bat --color=always --style=numbers {}.fish 2>/dev/null"
    
    # 2. Если нет bat, используем встроенный в fish инструмент
    else if command -v fish_indent > /dev/null
        # --ansi: включает раскраску
        set preview_cmd "fish_indent --ansi {}.fish 2>/dev/null"
    
    # 3. Запасной вариант (обычный текст)
    else
        set preview_cmd "command cat {}.fish 2>/dev/null"
    end
    # ----------------------------------

    # Запускаем fzf
    # Так как мы внутри папки, в preview достаточно написать {}.fish
    # command cat гарантирует, что используется системный cat (без алиасов)
    set -l selected (printf "%s\n" $functions_list | fzf \
        --prompt="Select Function > " \
        --header="use ⇅ keys, type to search or press Esc to exit" \
        --color="header:bold:yellow" \
        --height=80% \
        --layout=reverse \
        --border \
        --preview "$preview_cmd" \
        --preview-window=right:60%)

    # Возвращаемся обратно в исходную папку
    popd 2>/dev/null

    # Открываем файл, если выбор сделан (тут уже нужен полный путь, т.к. мы вернулись назад)
    if test -n "$selected"
        set -l file_path "$func_dir/$selected.fish"
        # Используем $EDITOR, или nvim как запасной вариант, если переменная пуста
        if set -q EDITOR
            $EDITOR "$file_path"
        else if command -v $default_text_editor > /dev/null
            $default_text_editor "$file_path"
        else
            echo "Выполните любое из следующих действий:"
            echo "    (Для того, чтобы скрипт знал какой текстовый редактор использовать)"
            echo "1) Установите переменную окружения EDITOR, указав предпочитаемый текстовый редактор."
            echo "2) Установите Neovim, с возможностью вызвать его командой 'nvim'"
            echo "   (Если запускается командой neovim, сделайте алиас или выполните пункт 1 или 3)"
            # Здесь экранируем $, чтобы вывести имя переменной, а не её значение (nvim)
            echo "3) Отредактируйте исходный код скрипта, указав ваш любимый текстовый редактор"
            echo "   в локальной переменной \$default_text_editor"
        end
    end
end
