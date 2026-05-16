function rename_frames_sequentially --description "Переименовывает последовательность файлов без пропусков, начиная с 1"
    # Настройки для общего случая
    set -l prefix frame_
    set -l extension png
    set -l padding 8
    set -l counter 1

    # Собираем файлы и сортируем их натуральным образом с помощью ls -v, 
    # чтобы frame_10 шел после frame_9, а не после frame_1
    set -l files (ls -v {$prefix}*.{$extension} 2>/dev/null)

    if test (count $files) -eq 0
        echo "Файлы с паттерном {$prefix}*.{$extension} не найдены."
        return 1
    end

    for file in $files
        # Формируем новое имя: префикс + число с нулями + расширение
        set -l new_name (printf "%s%0*d.%s" $prefix $padding $counter $extension)

        # Переименовываем только если имя меняется (чтобы избежать лишних операций)
        if test "$file" != "$new_name"
            # Флаг -n предотвратит случайную перезапись, если файл с таким именем уже существует
            mv -n -v "$file" "$new_name"
        end

        set counter (math $counter + 1)
    end

    echo "Готово! Обработано файлов: "(math $counter - 1)
end
