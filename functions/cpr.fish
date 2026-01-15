function cpr --description 'Copy with reflink=always'
    # 1. Парсим аргументы (h/help - флаг справки)
    argparse --ignore-unknown 'h/help' -- $argv
    or return

    # 2. Если нажали --help, выводим инструкцию и выходим
    if set -q _flag_help
        echo "ИСПОЛЬЗОВАНИЕ:"
        echo "  cpr [SOURCE] [DEST]"
        echo ""
        echo "ОПИСАНИЕ:"
        echo "  Копирует файлы, используя reflink (CoW) всегда."
        echo "  Работает мгновенно на Btrfs/XFS/ZFS."
        echo "можно использовать стандартные опции cp, например -r для рекурсивного копирования."
        return 0
    end

    # 3. Сама команда
    cp --reflink=always $argv
end
