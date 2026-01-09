function my_fish_functions --description "Список моих функций с описаниями"
	# TODO: 
	# - сделать подсветку в шахматном порядке(чтобы легче читалось)
	# - при переносе строк в описаниях оставлять в секции описания с помощью отступов
    # Режим --all (системный)
    if contains -- --all $argv
        printf "%-30s %s\n" "ФУНКЦИЯ" "ОПИСАНИЕ"
        set_color 666; printf "%-30s %s\n" "-------" "---------"; set_color normal
        for f in (functions -n)
            set -l d (functions -D $f | string split \t)[3]
            printf "%-30s %s\n" $f "$d"
        end
        return
    end

    # Основной режим: Чтение файлов
    printf "%-30s %s\n" "ФУНКЦИЯ" "ОПИСАНИЕ"
    set_color 666; printf "%-30s %s\n" "-------" "---------"; set_color normal

    for f_file in ~/.config/fish/functions/*.fish
        set -l f_name (basename $f_file .fish)

        # 1. Основной поиск: ищем строку, начинающуюся с function ... --description
        # ^ *function означает: начало строки, возможны пробелы, слово function
        set -l desc (grep -E "^ *function .*--description" "$f_file" | sed -E "s/.*--description ['\"](.*)['\"].*/\1/" | head -n 1)

        # 2. Запасной поиск: если описание перенесено на следующую строку
        if test -z "$desc"
             # grep -- "--description" говорит грепу, что дальше идет текст, а не опция
             set desc (grep -A 1 -E "^ *function" "$f_file" | grep -- "--description" | sed -E "s/.*--description ['\"](.*)['\"].*/\1/" | head -n 1)
        end

        if test -n "$desc"
            printf "%-30s %s\n" $f_name $desc
        else
            set_color 555
            printf "%-30s %s\n" $f_name "(нет описания)"
            set_color normal
        end
    end
end
