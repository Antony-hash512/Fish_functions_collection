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
            case 6144x3456
                echo "$res (6K 16:9)"
            case 3456x6144
                echo "$res (6K 9:16)"
            case 6016x3384
                echo "$res (6K 16:9)"
            case 3384x6016
                echo "$res (6K 9:16)"
            case 5120x2880
                echo "$res (5K 16:9)"
            case 2880x5120
                echo "$res (5K 9:16)"
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
                set -l dims (string split "x" "$res")
                if test (count $dims) -eq 2
                    set -l w $dims[1]
                    set -l h $dims[2]
                    set -l max_dim $w
                    set -l min_dim $h
                    if test $h -gt $w
                        set max_dim $h
                        set min_dim $w
                    end

                    # Aspect ratio detection using integer-scaled math
                    set -l ratio_int (math -s0 "1000 * $max_dim / $min_dim")
                    set -l aspect ""
                    if test $ratio_int -ge 1750 -a $ratio_int -le 1800
                        set aspect "16:9"
                    else if test $ratio_int -ge 1300 -a $ratio_int -le 1360
                        set aspect "4:3"
                    else if test $ratio_int -ge 1580 -a $ratio_int -le 1620
                        set aspect "16:10"
                    else if test $ratio_int -ge 2300 -a $ratio_int -le 2420
                        set aspect "21:9"
                    else if test $ratio_int -ge 1480 -a $ratio_int -le 1520
                        set aspect "3:2"
                    else if test $ratio_int -ge 1220 -a $ratio_int -le 1280
                        set aspect "5:4"
                    else if test $ratio_int -ge 980 -a $ratio_int -le 1020
                        set aspect "1:1"
                    end

                    # Reverse aspect ratio for portrait videos
                    if test -n "$aspect" -a "$aspect" != "1:1" -a $h -gt $w
                        set -l aspect_dims (string split ":" "$aspect")
                        set aspect "$aspect_dims[2]:$aspect_dims[1]"
                    end

                    # Resolution standard label detection
                    set -l label ""
                    if test $max_dim -ge 15000
                        set label 16K
                    else if test $max_dim -ge 10000
                        set label 10K
                    else if test $max_dim -ge 7600
                        set label 8K
                    else if test $max_dim -ge 5800
                        set label 6K
                    else if test $max_dim -ge 5000
                        set label 5K
                    else if test $max_dim -ge 3800
                        if test $max_dim -eq 3840
                            set label "4K UHD"
                        else if test $max_dim -eq 4096
                            set label "4K DCI"
                        else
                            set label 4K
                        end
                    else if test $max_dim -ge 3400
                        if test $max_dim -eq 3440 -a $min_dim -eq 1440
                            set label UWQHD
                        else
                            set label 3K
                        end
                    else if test $max_dim -ge 2800
                        set label 3K
                    else if test $max_dim -ge 2000
                        if test $max_dim -eq 2560
                            if test "$aspect" = "21:9" -o "$aspect" = "9:21"
                                set label UWFHD
                            else if test "$aspect" = "16:9" -o "$aspect" = "9:16"
                                set label 2K
                            else if test "$aspect" = "16:10" -o "$aspect" = "10:16"
                                set label WQXGA
                            else
                                set label QHD
                            end
                        else if test $max_dim -eq 2048
                            set label "2K DCI"
                        else
                            set label 2K
                        end
                    else if test $max_dim -ge 1900
                        if test "$aspect" = "16:9" -o "$aspect" = "9:16"
                            set label FHD
                        else if test "$aspect" = "16:10" -o "$aspect" = "10:16"
                            set label WUXGA
                        else
                            set label 1080p
                        end
                    else if test $max_dim -ge 1600
                        if test $max_dim -eq 1680 -a $min_dim -eq 1050
                            set label "WSXGA+"
                        else if test $max_dim -eq 1600 -a $min_dim -eq 1200
                            set label UXGA
                        else
                            set label 900p
                        end
                    else if test $max_dim -ge 1360
                        if test $max_dim -eq 1440 -a $min_dim -eq 900
                            set label "WXGA+"
                        else
                            set label 768p
                        end
                    else if test $max_dim -ge 1280
                        if test "$aspect" = "16:9" -o "$aspect" = "9:16"
                            set label HD
                        else if test "$aspect" = "16:10" -o "$aspect" = "10:16"
                            set label WXGA
                        else
                            set label 720p
                        end
                    else if test $max_dim -ge 960
                        set label qHD
                    else if test $max_dim -ge 800
                        if test $max_dim -eq 800 -a $min_dim -eq 600
                            set label SVGA
                        else
                            set label 480p
                        end
                    else if test $max_dim -ge 640
                        if test $max_dim -eq 640 -a $min_dim -eq 480
                            set label VGA
                        else
                            set label 480p
                        end
                    else if test $min_dim -eq 480 -o $min_dim -eq 576
                        set label SD
                    end

                    # Format the output nicely
                    if test -n "$label" -a -n "$aspect"
                        echo "$res ($label $aspect)"
                    else if test -n "$label"
                        echo "$res ($label)"
                    else if test -n "$aspect"
                        echo "$res ($aspect)"
                    else
                        echo "$res"
                    end
                else
                    echo "$res"
                end
        end
    end
end
