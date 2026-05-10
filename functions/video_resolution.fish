function video_resolution --description "Выводит разрешение видео. Флаги: -w (ширина), -h (высота), -r (соотношение сторон)"
    # Парсим флаги. argparse удалит их из $argv, оставив только путь к файлу
    argparse 'w/width' 'h/height' 'r/ratio' -- $argv
    or return 1

    if test (count $argv) -eq 0
        echo "Использование: video_resolution [-w] [-h] [-r] <видео_файл>"
        return 1
    end

    set file $argv[1]

    if not test -f "$file"
        echo "Ошибка: файл '$file' не найден."
        return 1
    end

    set -l output_something 0

    if set -q _flag_w
        ffprobe -v error -select_streams v:0 -show_entries stream=width -of csv=p=0 "$file"
        set output_something 1
    end

    if set -q _flag_h
        ffprobe -v error -select_streams v:0 -show_entries stream=height -of csv=p=0 "$file"
        set output_something 1
    end

    if set -q _flag_r
        set dar (ffprobe -v error -select_streams v:0 -show_entries stream=display_aspect_ratio -of csv=p=0 "$file")
        # Если DAR не прописан в метаданных, отдаем фактическое соотношение пикселей
        if test -z "$dar"; or test "$dar" = "N/A"
            set w (ffprobe -v error -select_streams v:0 -show_entries stream=width -of csv=p=0 "$file")
            set h (ffprobe -v error -select_streams v:0 -show_entries stream=height -of csv=p=0 "$file")
            echo "$w:$h"
        else
            echo $dar
        end
        set output_something 1
    end

    # Если не передан ни один флаг, выводим классическое ШxВ
    if test $output_something -eq 0
        ffprobe -v error -select_streams v:0 -show_entries stream=width,height -of csv=s=x:p=0 "$file"
    end
end
