function concatenate_videos --description 'Бесшовное объединение нескольких видеофайлов через ffmpeg'
    if test (count $argv) -lt 2
        echo "Использование: concatenate_videos <input1.mp4> <input2.mp4> ... <output.mp4>"
        return 1
    end

    # Последний аргумент — это выходной файл
    set -l output_file $argv[-1]
    # Все остальные аргументы — это входные файлы
    set -l input_files $argv[1..-2]

    # Создаем временный файл со списком
    set -l list_file (mktemp --suffix=".txt" concat_list_XXXXXX)

    for file in $input_files
        # Проверяем существование
        if not test -f "$file"
            echo "Ошибка: Файл '$file' не найден."
            rm -f "$list_file"
            return 1
        end
        # Записываем в формате, который понимает ffmpeg: file 'path/to/file'
        printf "file '%s'\n" (realpath "$file") >> "$list_file"
    end

    echo "Склеиваем файлы в $output_file..."
    
    # Флаг -c copy гарантирует, что мы не перекодируем 4K-видео, а просто склеиваем контейнеры
    if ffmpeg -v warning -y -f concat -safe 0 -i "$list_file" -c copy "$output_file"
        echo "Успех! Файлы объединены в $output_file"
    else
        echo "Сбой при объединении файлов."
    end

    rm -f "$list_file"
end
