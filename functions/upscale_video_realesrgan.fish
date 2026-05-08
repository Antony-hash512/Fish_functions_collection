function upscale_video_realesrgan --description 'Upscale video to 1080x1920 using realesrgan-ncnn-vulkan'
    set input_video $argv[1]
    set output_video $argv[2]

    if test -z "$input_video"; or test -z "$output_video"
        echo "Использование: upscale_video_realesrgan <входящее_видео.mp4> <исходящее_видео.mp4>"
        return 1
    end

    # Проверяем зависимости
    if not type -q realesrgan-ncnn-vulkan; or not type -q ffmpeg
        echo "Ошибка: Установите realesrgan-ncnn-vulkan и ffmpeg"
        return 1
    end

    # Создаем временную директорию
    set tmp_dir (mktemp -d)
    set frames_in "$tmp_dir/frames_in"
    set frames_out "$tmp_dir/frames_out"
    mkdir -p $frames_in $frames_out

    echo "[1/4] Извлекаем кадры из $input_video..."
    ffmpeg -loglevel error -stats -i $input_video -qscale:v 1 -qmin 1 -qmax 1 "$frames_in/frame_%08d.jpg"

    echo "[2/4] Апскейлим кадры через Vulkan (x4)..."
    # -n: используем универсальную модель x4plus
    # -s: масштабируем в 4 раза
    realesrgan-ncnn-vulkan -i $frames_in -o $frames_out -n realesrgan-x4plus -s 4 -f jpg

    echo "[3/4] Собираем видео 1080x1920 и возвращаем звук..."
    ffmpeg -loglevel error -stats -framerate 24 -i "$frames_out/frame_%08d.jpg" -i $input_video -map 0:v:0 -map 1:a:0? -c:v libx264 -crf 18 -pix_fmt yuv420p -c:a copy -vf "scale=1080:1920" $output_video

    echo "[4/4] Очищаем временные файлы..."
    rm -rf $tmp_dir

    echo "Успешно! Идеальный Shorts сохранен в $output_video"
end
