function add_subtitle_hint
    if test (count $argv) -lt 2
        echo "Usage: add_subtitle_hint input.mp4 output.mp4"
        return 1
    end

    set -l input $argv[1]
    set -l output $argv[2]
    set -l hint_img "/tmp/hint_overlay.png"

    # Константы (настройки)
    set -l hint_start_time 0.1
    set -l hint_end_time 6

    set -l cq 18  # Constant Quality для hevc_nvenc (аналог CRF)

    # Вычисляем ширину видео
    set -l vid_width (video_resolution -w "$input")
    # Проверка на случай ошибки video_resolution
    if test -z "$vid_width"; or not string match -qr '^[0-9]+$' "$vid_width"
        set vid_width 1920
    end

    # Вычисляем толщину обводки пропорционально 720p (для ширины 1280 -> 3)
    set -l stroke_thickness (math "round($vid_width / 1280 * 4)")
    if test $stroke_thickness -lt 1
        set stroke_thickness 1
    end

    # Вычисляем размер шрифта пропорционально 720p (для ширины 1280 -> 55)
    set -l font_size (math "round($vid_width / 1280 * 80)")

    # Вычисляем размер холста пропорционально (база: 1080x400 для 720p)
    set -l box_width (math "round($vid_width / 1280 * 1080)")
    set -l box_height (math "round($vid_width / 1280 * 400)")

    # 1. Генерируем PNG с двумя строками.
    # \n — это перенос строки. 
    magick -size {$box_width}x{$box_height} -background none \
        -gravity center \
        -fill white \
        pango:"<span font='Noto-Sans-Regular $font_size'>🇬🇧/🇺🇸 Turn on CC\n🇯🇵字幕をオンに</span>" \
        \( +clone -channel A -morphology EdgeOut Diamond:$stroke_thickness +channel -fill black -colorize 100% \) \
        -compose DstOver -composite \
        $hint_img

    # 2. Накладываем оверлей через ffmpeg.
    # Оставим отступ h*0.1 (10% сверху), так как строки теперь две, 
    # они будут занимать чуть больше места вниз.
    ffmpeg -i "$input" -i $hint_img -filter_complex \
        "[0:v][1:v] overlay=(W-w)/2:h*0.08:enable='between(t,$hint_start_time,$hint_end_time)'" \
        -c:v hevc_nvenc -cq $cq -pix_fmt yuv420p -c:a copy "$output"

    # Чистим временный файл
    if test -f "$hint_img"
        rm "$hint_img"
    end
end
