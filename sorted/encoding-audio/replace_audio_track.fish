function replace_audio_track --description "Замена звуковой дорожки с плавным затуханием (fade out)"
    set -l options (fish_opt -s v -l video --required-val)
    set options $options (fish_opt -s a -l audio --required-val)
    set options $options (fish_opt -s f -l fade --optional-val)
    
    argparse $options -- $argv
    or return 1

    if not set -q _flag_video[1]; or not set -q _flag_audio[1]
        echo (set_color red)"Ошибка: Укажите пути к видео и аудио файлам."(set_color normal)
        echo "Использование: replace_audio_track -v <видео.mp4> -a <аудио.mp3> [-f секунды_затухания]"
        return 1
    end

    set -l video_file $_flag_video[1]
    set -l audio_file $_flag_audio[1]
    
    # По умолчанию затухание длится 3 секунды, но это можно изменить флагом -f
    set -l fade_duration 3
    if set -q _flag_fade[1]
        set fade_duration $_flag_fade[1]
    end

    # Получаем точную длительность видео в секундах с помощью ffprobe
    set -l duration (ffprobe -v error -show_entries format=duration -of default=noprint_wrappers=1:nokey=1 "$video_file")
    
    if test -z "$duration"
        echo (set_color red)"Ошибка: Не удалось определить длительность видео. Проверьте файл."(set_color normal)
        return 1
    end

    # Вычисляем время старта эффекта (длительность минус время затухания)
    set -l fade_start (math "$duration - $fade_duration")

    set -l filename (basename "$video_file" | sed 's/\.[^.]*$//')
    set -l output_file "$filename-with_new_audio.mp4"

    echo (set_color cyan)"====================="(set_color normal)
    echo (set_color bold)"Замена аудио с плавным затуханием ($fade_duration сек)..."(set_color normal)
    echo (set_color green)"Видео: "(set_color normal)"$video_file"
    echo (set_color green)"Аудио: "(set_color normal)"$audio_file"
    echo (set_color cyan)"====================="(set_color normal)

    # Добавлен аудиофильтр -af "afade=..."
    ffmpeg -y -i "$video_file" -i "$audio_file" \
    -c:v copy \
    -c:a aac -b:a 160k \
    -af "afade=t=out:st=$fade_start:d=$fade_duration" \
    -map 0:v:0 -map 1:a:0 \
    -shortest \
    "$output_file"

    if test $status -eq 0
        echo (set_color green)"√ Готово! Файл сохранен как: $output_file"(set_color normal)
    else
        echo (set_color red)"X Произошла ошибка."(set_color normal)
        return 1
    end
end
