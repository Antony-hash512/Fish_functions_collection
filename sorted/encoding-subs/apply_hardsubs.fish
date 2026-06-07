function apply_hardsubs -d "Вшивает ASS-субтитры в видео через hevc_nvenc"
    # Парсим аргументы: флаг -s или --sub (ожидает значение), и флаг -h/--help
    argparse 's/sub=' 'h/help' -- $argv
    or return 1

    if set -q _flag_help; or test (count $argv) -eq 0
        echo "Использование: apply_hardsubs [ОПЦИИ] <видеофайл>"
        echo "Опции:"
        echo "  -s, --sub <файл>  Указать произвольный .ass файл (по умолчанию ищет одноименный)"
        return 0
    end

    set -l video_in $argv[1]

    # Проверяем наличие видеофайла
    if not test -f "$video_in"
        echo "❌ Ошибка: Видеофайл '$video_in' не найден."
        return 1
    end

    # Определяем файл субтитров
    set -l sub_in
    if set -q _flag_sub
        set sub_in $_flag_sub
    else
        # Меняем расширение видео на .ass
        set sub_in (string replace -r '\.[^.]+$' '.ass' -- "$video_in")
    end

    # Проверяем наличие файла субтитров
    if not test -f "$sub_in"
        echo "❌ Ошибка: Файл субтитров '$sub_in' не найден."
        echo "Убедитесь, что он лежит рядом с видео, или укажите путь вручную через флаг -s"
        return 1
    end

    # Формируем имя выходного файла
    set -l base_name (string replace -r '\.[^.]+$' '' -- "$video_in")
    set -l ext (string match -r '\.[^.]+$' -- "$video_in")
    set -l out_name

    # Проверяем, заканчивается ли базовое имя на -watermarked
    if string match -q "*-watermarked" -- "$base_name"
        set out_name (string replace -r '-watermarked$' '-hardsubbed' -- "$base_name")"$ext"
    else
        set out_name "$base_name-hardsubbed$ext"
    end

    echo "🎬 Входное видео: $video_in"
    echo "📝 Субтитры:      $sub_in"
    echo "💾 Выходной файл: $out_name"
    echo "⏳ Начинаю рендер через hevc_nvenc..."

    ffmpeg -i "$video_in" -vf "ass='$sub_in'" -c:v hevc_nvenc -cq 18 -c:a copy "$out_name"
end
