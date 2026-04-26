function paru_clean --description "Очистка кэша paru (оставляет N последних версий, по умолчанию 2)"
    # Проверка зависимостей
    if not type -q paccache
        set_color red
        echo "Ошибка: утилита 'paccache' не найдена."
        set_color normal
        echo "Пожалуйста, установите её командой: paru -S pacman-contrib"
        return 1
    end

    # Обработка аргументов
    argparse 'k/keep=' -- $argv
    or return 1

    set -l keep 2
    if set -q _flag_keep
        set keep $_flag_keep
    end

    set -l cache_dir $HOME/.cache/paru/clone
    
    if not test -d $cache_dir
        echo "Директория кэша $cache_dir не найдена."
        return 0
    end

    echo "🧹 Начинаю очистку кэша AUR в $cache_dir..."
    echo "📦 Оставляю только $keep последние версии для каждого пакета."
    echo ""

    # Проходим по всем подпапкам (каждая папка — это отдельный пакет git)
    for pkg_dir in $cache_dir/*
        if test -d $pkg_dir
            # Запускаем paccache для конкретной папки
            # -r: удалить (remove)
            # -k $keep: оставить $keep (keep)
            # -c: указать путь к кэшу
            # grep -v: скрывает сообщения, если удалять было нечего
            /usr/bin/paccache -r -k $keep -c $pkg_dir | grep -v "no candidate packages"
        end
    end

    echo ""
    set_color green
    echo "✅ Очистка завершена."
    set_color normal
end
