function paru_clean --description "Очистка кэша paru (оставляет N последних версий, по умолчанию 2)"
    # Проверка зависимостей
    for cmd in paccache pacman git
        if not type -q $cmd
            set_color red
            echo "Ошибка: утилита '$cmd' не найдена."
            set_color normal
            return 1
        end
    end

    # Обработка аргументов
    argparse 'k/keep=' 'deep' 'deep-all' -- $argv
    or return 1

    set -l cache_dir $HOME/.cache/paru/clone
    
    if not test -d $cache_dir
        echo "Директория кэша $cache_dir не найдена."
        return 0
    end

    # Полная очистка
    if set -q _flag_deep_all
        echo "🔥 Начинаю ПОЛНУЮ очистку кэша AUR (удаление всех данных)..."
        rm -rf $cache_dir/*
        set_color green
        echo "✅ Кэш полностью очищен."
        set_color normal
        return 0
    end

    set -l keep 2
    if set -q _flag_keep
        set keep $_flag_keep
    end

    set -l installed_aur
    if set -q _flag_deep
        echo "🔍 Собираю список установленных AUR пакетов..."
        set installed_aur (pacman -Qm | string split -f1 " ")
    end

    echo "🧹 Начинаю очистку кэша AUR в $cache_dir..."
    echo "📦 Режим: (keep: $keep" (set -q _flag_deep; and echo ", deep: on"; or echo "")")"
    echo ""

    # Проходим по всем подпапкам (каждая папка — это отдельный пакет git)
    for pkg_dir in $cache_dir/*
        if test -d $pkg_dir
            set -l pkg_name (basename $pkg_dir)

            if set -q _flag_deep
                # Если пакета нет в системе — удаляем папку целиком
                if not contains $pkg_name $installed_aur
                    echo "🗑️  Удаляю папку неиспользуемого пакета: $pkg_name"
                    rm -rf $pkg_dir
                    continue
                else
                    # Если установлен — чистим исходники и мусор сборки, оставляя .git и сами пакеты
                    if test -d $pkg_dir/.git
                        echo "🧹 Очистка исходников (git clean) для $pkg_name"
                        git -C $pkg_dir clean -fdx -e "*.pkg.tar.*" > /dev/null 2>&1
                    end
                end
            end

            # Запускаем paccache для очистки старых версий .pkg.tar.zst
            /usr/bin/paccache -r -k $keep -c $pkg_dir | grep -v "no candidate packages"
        end
    end

    echo ""
    set_color green
    echo "✅ Очистка завершена."
    set_color normal
end
