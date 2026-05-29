function video_resolution --description "Выводит разрешение видео. Флаги: -w (ширина), -h (высота), -r (соотношение сторон)"
    # Парсим флаги. argparse удалит их из $argv, оставив только путь к файлу
    argparse w/width h/height r/ratio -- $argv
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
        if test -z "$dar"; or test "$dar" = N/A
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
        set -l res (ffprobe -v error -select_streams v:0 -show_entries stream=width,height -of csv=s=x:p=0 "$file")
        switch "$res"
            case 7680x4320
                echo "$res (8K 16:9)"
            case 4320x7680
                echo "$res (8K 9:16)"
            case 3840x2160
                echo "$res (4K UHD 16:9)"
            case 2160x3840
                echo "$res (4K UHD 9:16)"
            case 2560x1440
                echo "$res (2K 16:9)"
            case 1440x2560
                echo "$res (2K 9:16)"
            case 1920x1080
                echo "$res (FHD 16:9)"
            case 1080x1920
                echo "$res (FHD 9:16)"
            case 1280x720
                echo "$res (HD 16:9)"
            case 720x1280
                echo "$res (HD 9:16)"
            case '*'
                echo "$res"
        end
    end
end
