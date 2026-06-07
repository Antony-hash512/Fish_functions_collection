function last_pkgs --description "Показать последние установленные вручную пакеты с указанием репозитория"
    # Парсинг аргументов (-a/--all и -h/--help)
    argparse 'a/all' 'h/help' -- $argv
    or return 1

    if set -q _flag_help
        echo "Использование: last_pkgs [опции] [количество]"
        echo "Опции:"
        echo "  -a, --all    Показать все (включая обновленные и переустановленные)"
        echo "  -h, --help   Показать эту справку"
        return 0
    end

    # Значение по умолчанию
    set -l limit 20

    # Проверяем, передан ли аргумент
    if test (count $argv) -gt 0
        set limit $argv[1]
    else
        # Подсказки в зависимости от режима
        if set -q _flag_all
            echo "💡 Подсказка: используйте 'last_pkgs --all <число>', чтобы изменить количество (сейчас $limit)." >&2
        else
            echo "💡 Подсказка: показаны только новые установки. Добавьте '--all' для списка с обновлениями." >&2
        end
    end

    set -l pkgs_data
    
    if set -q _flag_all
        # --- РЕЖИМ --all (Старый алгоритм) ---
        # Смотрит на дату последнего изменения в базе pacman (включает обновления)
        set pkgs_data (expac --timefmt='%Y-%m-%d %T' '%l\t%n\t%w' | awk -F'\t' '/explicit/ {print $1 "\t" $2}' | sort | tail -n $limit)
    else
        # --- РЕЖИМ ПО УМОЛЧАНИЮ (Только новые установки) ---
        # Читаем pacman.log с конца, отбираем только 'installed' и сверяем с явно установленными пакетами
        set pkgs_data (tac /var/log/pacman.log 2>/dev/null | grep '\[ALPM\] installed' | awk -v limit=$limit '
            BEGIN { FS=" "; OFS="\t" }
            # Загружаем список явно установленных пакетов в память
            NR==FNR { explicit[$1]=1; next }
            {
                # Формат лога: [2024-04-24T13:50:50+0400] [ALPM] installed <pkg> (<version>)
                pkg = $4
                if (explicit[pkg] && !seen[pkg]) {
                    seen[pkg] = 1
                    # Приводим дату к формату expac (YYYY-MM-DD HH:MM:SS)
                    dt = substr($1, 2, 19)
                    gsub("T", " ", dt)
                    print dt, pkg
                    count++
                    if (count >= limit) exit
                }
            }
        ' (pacman -Qqe | psub) - | tac) # tac в конце возвращает привычную сортировку "свежие в самом низу"
    end

    # Если ничего не найдено (например, пустой лог)
    if test -z "$pkgs_data"
        echo "Ничего не найдено."
        return 0
    end

    # Форматированный вывод
    for line in $pkgs_data
        set -l parts (string split \t $line)
        set -l dt $parts[1]
        set -l name $parts[2]

        # Определяем репозиторий
        # expac -S ищет в sync базе. Если пусто -> значит пакет локальный/AUR
        set -l repo (expac -S '%r' $name 2>/dev/null)
        
        if test -z "$repo"
            set repo "aur"
            # Красим AUR в желтый (опционально)
            set_color yellow
        else
            # Красим официальные репы в голубой (опционально)
            set_color cyan
        end

        # Форматированный вывод: Дата | Название (выравнено) | Репозиторий
        printf "%s | %-25s | %s\n" "$dt" "$name" "$repo"
        
        # Сбрасываем цвет для следующей строки
        set_color normal
    end
end
