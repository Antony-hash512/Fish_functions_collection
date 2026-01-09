function which-versions --description "Показывает пути и версии программы"
    set -l cmd $argv[1]

    # 1. Получаем список всех путей через type -a -p
    set -l paths (type -a -p $cmd)

    if test -z "$paths"
        echo "Программа '$cmd' не найдена."
        return 1
    end

    # 2. Пробегаем по каждому найденному пути
    for bin_path in $paths
        # Красиво выводим путь (синим цветом)
        set_color -o blue
        echo -n "$bin_path "
        set_color normal

        # 3. Пытаемся запустить файл с флагом --version
        # 2>/dev/null скрывает ошибки, если программа не понимает флаг
        # head -n 1 берет только первую строку (чтобы не спамить)
        set -l version_str ($bin_path --version 2>/dev/null | head -n 1)

        echo -n "-> "

        if test -n "$version_str"
            set_color green
            echo "$version_str"
        else
            set_color red
            echo "(версия не определена или нет флага --version)"
        end
        set_color normal
    end
end
