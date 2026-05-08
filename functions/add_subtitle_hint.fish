function add_subtitle_hint
    if test (count $argv) -lt 2
        echo "Usage: add_subtitle_hint input.mp4 output.mp4"
        return 1
    end

    set -l input $argv[1]
    set -l output $argv[2]
    set -l hint_img "/tmp/hint_overlay.png"

    # 1. Генерируем PNG с двумя строками.
    # \n — это перенос строки. 
    # Размер шрифта 55 обычно хорошо подходит для такой композиции.
    magick -size 1080x400 -background none \
           -gravity center \
           -fill white \
           pango:"<span font='Noto-Sans-Regular 65'>🇬🇧/🇺🇸 Turn on CC\n🇯🇵字幕をオンに</span>" \
           \( +clone -channel A -morphology EdgeOut Diamond:3 +channel -fill black -colorize 100% \) \
           -compose DstOver -composite \
           $hint_img

    # 2. Накладываем оверлей через ffmpeg.
    # Оставим отступ h*0.1 (10% сверху), так как строки теперь две, 
    # они будут занимать чуть больше места вниз.
    ffmpeg -i "$input" -i $hint_img -filter_complex \
    "[0:v][1:v] overlay=(W-w)/2:h*0.08:enable='between(t,0,5)'" \
    -c:v libx264 -crf 18 -c:a copy "$output"

    # Чистим временный файл
    if test -f "$hint_img"
        rm "$hint_img"
    end
end
