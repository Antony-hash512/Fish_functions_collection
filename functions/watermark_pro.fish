function watermark_pro --description "Наложение вотермарки на видео (с перекодировкой)"
    set -l options (fish_opt -s i -l input --required-val)
    set options $options (fish_opt -s w -l text --required-val)
    set options $options (fish_opt -l glow)
    set options $options (fish_opt -l glow-color --required-val)
    set options $options (fish_opt -l color --required-val)
    set options $options (fish_opt -l border-color --required-val)
    set options $options (fish_opt -l border-size --required-val)
    set options $options (fish_opt -l font --required-val)
    set options $options (fish_opt -s h -l hardsub)
    set options $options (fish_opt -l hardsub-filename --required-val)

    argparse $options -- $argv
    or return 1

    if not set -q _flag_input[1]
        echo (set_color red)"Ошибка: Укажите путь к исходному файлу через флаг -i или --input."(set_color normal)
        echo "Пример: watermark_pro -i исходное_видео.mp4 -w '@Ваш_Ник'"
        return 1
    end

    set -l input_file $_flag_input[1]

    if set -q _flag_hardsub_filename[1]; and not set -q _flag_hardsub
        echo (set_color red)"Ошибка: Флаг --hardsub-filename может использоваться только вместе с флагом -h или --hardsub."(set_color normal)
        return 1
    end

    set -l sub_in ""
    if set -q _flag_hardsub
        if set -q _flag_hardsub_filename[1]
            set sub_in $_flag_hardsub_filename[1]
        else
            set sub_in (string replace -r '\.[^.]+$' '.ass' -- "$input_file")
        end

        if not test -f "$sub_in"
            echo (set_color red)"❌ Ошибка: Файл субтитров '$sub_in' не найден."(set_color normal)
            return 1
        end
    end

    if not set -q _flag_text[1]
        set -l _flag_text[1] "@My_Channel"
    end
    set -l watermark_text $_flag_text[1]

    # --- БАЗОВЫЕ НАСТРОЙКИ ---
    set -l cq 18
    set -l fontfile "/usr/share/fonts/liberation/LiberationSans-Bold.ttf"
    if set -q _flag_font[1]
        switch (string lower $_flag_font[1])
            case orbitron
                set fontfile "/home/fireice/.local/share/fonts/Orbitron-VariableFont_wght.ttf"
            case michroma
                set fontfile "/home/fireice/.local/share/fonts/Michroma-Regular.ttf"
            case '*'
                set fontfile $_flag_font[1]
        end
    end

    set -l font_proportion 20

    set -l font_color "white@0.4"
    if set -q _flag_color[1]
        set font_color $_flag_color[1]
    end

    set -l border_color "black@0.4"
    if set -q _flag_border_color[1]
        set border_color $_flag_border_color[1]
    end

    set -l border_width 3
    if set -q _flag_border_size[1]
        set border_width $_flag_border_size[1]
    end

    # --- НАСТРОЙКИ СВЕЧЕНИЯ ---
    set -l glow_color 0xFF00FF # Неоново-розовый
    if set -q _flag_glow_color[1]
        set glow_color $_flag_glow_color[1]
    end

    set -l filename (basename "$input_file" | sed 's/\.[^.]*$//')
    set -l ext (string match -r '\.[^.]+$' -- "$input_file")
    if test -z "$ext"
        set ext ".mp4"
    end
    set -l output_file ""
    if set -q _flag_hardsub
        set output_file "$filename-hardsubbed$ext"
    else
        set output_file "$filename-watermarked$ext"
    end
    set -l timestamp (date +%H%M%S)

    echo (set_color cyan)"====================="(set_color normal)
    if set -q _flag_hardsub
        echo (set_color -o)"Начинаем наложение вотермарка и хардсаба."(set_color normal)
    else
        echo (set_color -o)"Начинаем наложение вотермарка."(set_color normal)
    end
    echo (set_color green)"Входной файл:     "(set_color normal)"$input_file"
    echo (set_color green)"Текст вотермарка: "(set_color normal)"$watermark_text"
    if set -q _flag_hardsub
        echo (set_color green)"Файл субтитров:   "(set_color normal)"$sub_in"
    end
    echo (set_color green)"Выходной файл:    "(set_color normal)"$output_file"
    echo (set_color cyan)"====================="(set_color normal)
    echo "Пожалуйста, подождите, процесс может занять время..."

    # Вычисляем размеры видео и параметры шрифта/отступов
    set -l vid_width (video_resolution -w "$input_file")
    set -l vid_height (video_resolution -h "$input_file")

    if test -z "$vid_width"; or not string match -qr '^[0-9]+$' "$vid_width"
        set vid_width 1280
        set vid_height 720
    end

    set -l font_size (math "round($vid_width / $font_proportion)")

    # Вычисляем отступы
    # y = высота / 64
    set -l offset_y (math "round($vid_height / 64)")

    # --- ФОРМИРУЕМ СЛОИ ТЕКСТА ---
    # Базовая позиция и шрифт, чтобы не дублировать код
    set -l text_base "text='$watermark_text':x=(w-tw)/2:y=h-th-$offset_y:fontsize=$font_size:fontfile=$fontfile"

    set -l vf_chain ""

    if set -q _flag_glow
        # --- НАСТРОЙКИ СВЕЧЕНИЯ ---
        set -l glow_width_1 14 # Широкий радиус
        set -l glow_opacity_1 0.15 # Слабая видимость
        set -l glow_width_2 6 # Узкий радиус ближе к тексту
        set -l glow_opacity_2 0.45 # Более плотный цвет

        # Слой 1 (Дальнее свечение): прозрачное тело текста (white@0), толстая обводка цвета glow
        set -l layer_glow_outer "drawtext=$text_base:fontcolor=white@0:borderw=$glow_width_1:bordercolor=$glow_color@$glow_opacity_1"

        # Слой 2 (Ближнее свечение): прозрачное тело текста, средняя обводка
        set -l layer_glow_inner "drawtext=$text_base:fontcolor=white@0:borderw=$glow_width_2:bordercolor=$glow_color@$glow_opacity_2"

        # Слой 3 (Сам текст): белый текст, обводка для читаемости
        set -l layer_main_text "drawtext=$text_base:fontcolor=$font_color:borderw=$border_width:bordercolor=$border_color"

        # Склеиваем слои
        set vf_chain "$layer_glow_outer, $layer_glow_inner, $layer_main_text"
    else
        # Обычный текст без свечения
        set vf_chain "drawtext=$text_base:fontcolor=$font_color:borderw=$border_width:bordercolor=$border_color"
    end

    if set -q _flag_hardsub
        set vf_chain "$vf_chain,ass='$sub_in'"
    end

    # КОМАНДА FFMPEG С ПОЯСНЕНИЯМИ:
    # 1. -vf: Включаем видеофильтр.
    # 3. ПАРАМЕТРЫ РЕКОДИНГА:
    #    - -c:v hevc_nvenc: HEVC кодирование через GPU NVIDIA (как у исходника).
    #    - -cq $cq: Качество (Constant Quality для nvenc, аналог CRF).
    #    - -pix_fmt yuv420p: Стандартная цветовая субдискретизация.
    #    - -g 30: Интервал ключевых кадров (GOP = 1 сек при 30fps).
    #    - -c:a aac -b:a 384k -ar 48000: Качественный стерео AAC 384k для YouTube.

    ffmpeg -i "$input_file" \
        -vf "$vf_chain" \
        -c:v hevc_nvenc -cq $cq -pix_fmt yuv420p -g 30 \
        -c:a aac -b:a 384k -ar 48000 \
        "$output_file"

    if test $status -eq 0
        echo (set_color green)"√ Видео успешно создано: $output_file"(set_color normal)
    else
        echo (set_color red)"X Произошла ошибка при обработке видео."(set_color normal)
        return 1
    end
end
