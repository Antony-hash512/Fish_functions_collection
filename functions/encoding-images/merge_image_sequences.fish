function merge_image_sequences --description 'Объединяет несколько папок с PNG кадрами в одну сквозную секвенцию с помощью жестких ссылок'
    argparse 'o/output=' h/help -- $argv
    or return 1

    if set -ql _flag_help
        echo "Использование: merge_image_sequences [опции] <папка1> <папка2> ..."
        echo "Опции:"
        echo "  -o, --output   Папка для сохранения итоговой секвенции (по умолчанию: all_frames_perfect)"
        echo "  -h, --help     Показать эту справку"
        return 0
    end

    if test (count $argv) -eq 0
        echo "Ошибка: Укажите хотя бы одну исходную папку с кадрами."
        echo "Пример: merge_image_sequences slavya_frames_1/frames_out slavya_frames_2/frames_out"
        return 1
    end

    # Папка назначения
    set -l out_dir all_frames_perfect
    if set -ql _flag_output
        set out_dir $_flag_output
    end

    echo "Подготовка директории '$out_dir'..."
    rm -rf $out_dir; and mkdir -p $out_dir

    set -l count 1

    # Проходим по всем переданным папкам
    for dir in $argv
        if not test -d "$dir"
            echo "Предупреждение: Папка '$dir' не найдена, пропускаем."
            continue
        end

        echo "Сборка кадров из: $dir..."

        # Перебираем все PNG файлы в папке
        for img in $dir/*.png
            # Проверка, что файл действительно существует (защита от пустых папок)
            if test -f "$img"
                set -l new_name (printf "%s/frame_%08d.png" $out_dir $count)
                # Создаем жесткую ссылку
                ln "$img" "$new_name"
                set count (math $count + 1)
            end
        end
    end

    set -l total (math $count - 1)
    if test $total -gt 0
        echo "========================================="
        echo "Успешно! Собрано файлов: $total"
        echo "Секвенция готова в папке '$out_dir'"
        echo "========================================="
    else
        echo "Ошибка: Не удалось найти PNG файлы в указанных папках."
        rm -rf $out_dir
        return 1
    end
end
