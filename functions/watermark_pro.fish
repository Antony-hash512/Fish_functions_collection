function watermark_pro --description "Наложение вотермарки на видео (с перекодировкой)"
    set -l options (fish_opt -s i -l input --required-val)
    set options $options (fish_opt -s w -l text --required-val)

    set -l cq 18 # Качество для hevc_nvenc (аналог CRF, 0=лучшее, 51=худшее)
    set -l fontfile "/usr/share/fonts/liberation/LiberationSans-Bold.ttf"
    set -l font_proportion 20 # 36 для 720p
    set -l font_color "white@0.7"
    set -l border_color "black@0.7"
    set -l border_width 3

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

    # --- Выравнивание по правому краю (закомментировано) ---
    # Считаем стандартную ширину для соотношения 16:9
    # set -l standard_width (math "round($vid_height * 16 / 9)")
    # set -l extra_x 0
    # if test $vid_width -gt $standard_width
    #     # Размер одной черной полосы сбоку (половина того, что превышает 16:9)
    #     set extra_x (math "round(($vid_width - $standard_width) / 2)")
    # end
    # # x = ширина / 24 + компенсация черной полосы
    # set -l offset_x (math "round(($vid_width / 24) + ($extra_x * 2))")

    # КОМАНДА FFMPEG С ПОЯСНЕНИЯМИ:
    # 1. -vf: Включаем видеофильтр.
    # 2. drawtext=...: Модуль для рисования текста.
    #    - text='%s': Берем текст из переменной.
    #    - x=(w-tw)/2:y=h-th-$offset_y: Позиция вотермарки (центр по горизонтали, отступ снизу).
    #    - fontcolor=$font_color: Цвет и прозрачность текста.
    #    - fontsize=$font_size: Размер шрифта (динамически вычислен пропорционально ширине).
    #    - fontfile=$fontfile: Путь к файлу шрифта.
    #    - borderw=$border_width:bordercolor=$border_color: Толщина и цвет обводки текста.
    #
    # 3. ПАРАМЕТРЫ РЕКОДИНГА:
    #    - -c:v hevc_nvenc: HEVC кодирование через GPU NVIDIA (как у исходника).
    #    - -cq $cq: Качество (Constant Quality для nvenc, аналог CRF).
    #    - -pix_fmt yuv420p: Стандартная цветовая субдискретизация.
    #    - -g 30: Интервал ключевых кадров (GOP = 1 сек при 30fps).
    #    - -c:a aac -b:a 160k: Пережимаем аудио в качественный AAC 160k.

    ffmpeg -i "$input_file" \
        # -vf "drawtext=text='$watermark_text':x=w-tw-$offset_x:y=h-th-$offset_y:fontcolor=$font_color:fontsize=$font_size:fontfile=$fontfile:borderw=$border_width:bordercolor=$border_color" \
        -vf "drawtext=text='$watermark_text':x=(w-tw)/2:y=h-th-$offset_y:fontcolor=$font_color:fontsize=$font_size:fontfile=$fontfile:borderw=$border_width:bordercolor=$border_color" \
        -c:v hevc_nvenc -cq $cq -pix_fmt yuv420p -g 30 \
        -c:a aac -b:a 160k \
        "$output_file"

    if test $status -eq 0
        echo (set_color green)"√ Видео успешно создано: $output_file"(set_color normal)
    else
        echo (set_color red)"X Произошла ошибка при обработке видео."(set_color normal)
        return 1
    end
end
