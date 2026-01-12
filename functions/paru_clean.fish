function paru_clean --description "Очистка кэша paru (оставляет 2 последние версии)"
    # Проверка зависимостей
    if not type -q paccache
        set_color red
        echo "Ошибка: утилита 'paccache' не найдена."
        set_color normal
        echo "Пожалуйста, установите её командой: paru -S pacman-contrib"
        return 1
    end

    set -l cache_dir $HOME/.cache/paru/clone
    
    if not test -d $cache_dir
        echo "Директория кэша $cache_dir не найдена."
        return 0
    end

    echo "🧹 Начинаю очистку кэша AUR в $cache_dir..."
    echo "📦 Оставляю только 2 последние версии для каждого пакета."
    echo ""

    # Проходим по всем подпапкам (каждая папка — это отдельный пакет git)
    for pkg_dir in $cache_dir/*
        if test -d $pkg_dir
            # Запускаем paccache для конкретной папки
            # -r: удалить (remove)
            # -k 2: оставить 2 (keep)
            # -c: указать путь к кэшу
            # grep -v: скрывает сообщения, если удалять было нечего
            /usr/bin/paccache -r -k 2 -c $pkg_dir | grep -v "no candidate packages"
        end
    end

    echo ""
    set_color green
    echo "✅ Очистка завершена."
    set_color normal
end
