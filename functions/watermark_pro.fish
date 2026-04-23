function watermark_pro --description "Наложение вотермарка на видео для YouTube (с перекодировкой)"
    set -l options (fish_opt -s i -l input --required-val)
    set options $options (fish_opt -s w -l text --required-val)
    
    argparse $options -- $argv
    or return 1

    if not set -q _flag_input[1]
        echo (set_color red)"Ошибка: Укажите путь к исходному файлу через флаг -i или --input."(set_color normal)
        echo "Пример: watermark_pro -i исходное_видео.mp4 -w '@Ваш_Ник'"
        return 1
    end

    set -l input_file $_flag_input[1]
    
    if not set -q _flag_text[1]
        # Если текст не указан, ставим значение по умолчанию. Можно поменять здесь.
        set -l _flag_text[1] "@My_Channel"
    end
    set -l watermark_text $_flag_text[1]

    set -l filename (basename "$input_file" | sed 's/\.[^.]*$//')
    set -l output_file "$filename-watermarked.mp4"
    set -l timestamp (date +%H%M%S)

    echo (set_color cyan)"====================="(set_color normal)
    echo (set_color bold)"Начинаем наложение вотермарка."(set_color normal)
    echo (set_color green)"Входной файл: "(set_color normal)"$input_file"
    echo (set_color green)"Текст вотермарка: "(set_color normal)"$watermark_text"
    echo (set_color green)"Промежуточный файл: "(set_color normal)"$output_file"
    echo (set_color cyan)"====================="(set_color normal)
    echo "Пожалуйста, подождите, процесс может занять время..."

    # КОМАНДА FFMPEG С ПОЯСНЕНИЯМИ:
    # 1. -vf: Включаем видеофильтр.
    # 2. drawtext=...: Модуль для рисования текста.
    #    - text='%s': Берем текст из переменной.
    #    - x=w-tw-30:y=h-th-20: Позиция. 'w-tw-30' — ширина видео минус ширина текста минус 30 пикселей отступ (справа). 
    #       'h-th-20' — высота видео минус высота текста минус 20 пикселей (снизу).
    #    - fontcolor=white@0.4: Цвет текста белый. Собачка и 0.4 — это прозрачность (40%).
    #    - fontsize=36: Размер шрифта. Подходит для 720p/1080p.
    #    - fontfile=/System/Library/Fonts/Cache/Menlo-Bold.ttf: ПУТЬ К ШРИФТУ. ОЧЕНЬ ВАЖНО. Это стандартный шрифт Menlo (моноширинный, красивый) на macOS.
    #      ЕСЛИ ВЫ НА LINUX/WINDOWS, ЭТОТ ПУТЬ НУЖНО ИЗМЕНИТЬ на реальный (например, Arial.ttf или LiberationSans.ttf).
    #
    # 3. ПАРАМЕТРЫ РЕКОДИНГА ДЛЯ YOUTUBE:
    #    - -c:v libx264: Используем самый совместимый кодек x264.
    #    - -crf 20: (Constant Rate Factor). Это качество. Диапазон от 0 (без сжатия) до 51. Значение 20 — это ОЧЕНЬ хорошее качество (для 720p). 23 — дефолт, 18 — визуально lossless.
    #    - -pix_fmt yuv420p: Стандартная цветовая субдискретизация 4:2:0. Это критично для совместимости.
    #    - -g 30: (Keyframe interval). YouTube рекомендует делать ключевой кадр каждые 1-2 секунды. При 30 fps это '-g 30'. Это ускорит обработку видео на их серверах.
    #    - -c:a aac -b:a 160k: Пережимаем аудио в хороший AAC (как в оригинале), чтобы YouTube точно "проглотил".

    ffmpeg -i "$input_file" \
    -vf "drawtext=text='$watermark_text':x=w-tw-30:y=h-th-20:fontcolor=white@0.4:fontsize=36:fontfile=/usr/share/fonts/liberation/LiberationSans-Bold.ttf" \
    -c:v libx264 -crf 20 -pix_fmt yuv420p -g 30 -profile:v high -level:v 3.1 \
    -c:a aac -b:a 160k \
    "$output_file"

    if test $status -eq 0
        echo (set_color green)"√ Видео успешно создано: $output_file"(set_color normal)
    else
        echo (set_color red)"X Произошла ошибка при обработке видео."(set_color normal)
        return 1
    end
end
