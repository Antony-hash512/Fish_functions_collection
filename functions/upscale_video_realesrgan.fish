function upscale_video_realesrgan --description 'Upscale video using realesrgan-ncnn-vulkan'
    argparse 'r/res=' 's/style=' 't/tmpdir=' k/keep-tmp h/help -- $argv
    or return 1

    if set -ql _flag_help
        echo "Использование: upscale_video_realesrgan [опции] <входящее_видео> <исходящее_видео>"
        echo "Опции:"
        echo "  -r, --res        Разрешение: 1080p, 2k, 4k (по умолчанию: 2k)"
        echo "  -s, --style      Стиль: anime, photo (по умолчанию: anime)"
        echo "  -t, --tmpdir     Кастомная временная директория"
        echo "  -k, --keep-tmp   Не удалять временные файлы после работы"
        echo "  -h, --help       Показать эту справку"
        return 0
    end

    if test (count $argv) -lt 2
        echo "Ошибка: Не указаны входящее и исходящее видео."
        echo "Использование: upscale_video_realesrgan [опции] <входящее_видео> <исходящее_видео>"
        return 1
    end

    set -l input_video $argv[1]
    set -l output_video $argv[2]

    # Значения по умолчанию
    set -l resolution 2k
    if set -ql _flag_res
        set resolution $_flag_res
    end

    set -l style anime
    if set -ql _flag_style
        set style $_flag_style
    end

    # Проверяем зависимости
    if not type -q realesrgan-ncnn-vulkan; or not type -q ffmpeg
        echo "Ошибка: Установите realesrgan-ncnn-vulkan и ffmpeg"
        return 1
    end

    # Конфигурация стиля
    set -l model_name
    switch $style
        case anime
            set model_name realesrgan-x4plus-anime
        case photo
            set model_name realesrgan-x4plus
        case '*'
            echo "Ошибка: Неизвестный стиль '$style'. Доступные стили: anime, photo."
            return 1
    end

    # Конфигурация разрешения
    set -l scale_factor
    set -l tile_size
    set -l thread_configuration
    set -l ffmpeg_scale_filter

    switch $resolution
        case 1080p
            set scale_factor 2
            set tile_size 512
            set thread_configuration "2:2:2"
            set ffmpeg_scale_filter -vf "scale=-2:1920"
        case 2k
            set scale_factor 2
            set tile_size 512
            set thread_configuration "2:2:2"
            # Для 2k (вертикальное 1440x2560)
            set ffmpeg_scale_filter -vf "scale=-2:2560"
        case 4k
            set scale_factor 4
            set tile_size 256
            set thread_configuration "1:2:2"
            set ffmpeg_scale_filter -vf "scale=-2:3840"
        case '*'
            echo "Ошибка: Неизвестное разрешение '$resolution'. Доступные разрешения: 1080p, 2k, 4k."
            return 1
    end

    # Создаем временную директорию
    set -l temporary_directory
    if set -ql _flag_tmpdir
        set temporary_directory $_flag_tmpdir
        mkdir -p $temporary_directory
    else
        set temporary_directory (mktemp -d)
    end
    echo "Временная директория: $temporary_directory"
    set -l frames_input_directory "$temporary_directory/frames_in"
    set -l frames_output_directory "$temporary_directory/frames_out"
    mkdir -p $frames_input_directory $frames_output_directory

    echo "[1/4] Извлекаем кадры из $input_video..."
    ffmpeg -loglevel error -stats -i $input_video "$frames_input_directory/frame_%08d.png"

    echo "[2/4] Апскейлим кадры через Vulkan..."

    # Считаем количество входных кадров
    set -l total_frames (count $frames_input_directory/*.png)
    if test $total_frames -eq 0
        echo "Ошибка: Кадры не найдены в $frames_input_directory"
        return 1
    end
    echo "       Всего кадров: $total_frames"

    # Запускаем апскейлер в фоне
    realesrgan-ncnn-vulkan -i $frames_input_directory -o $frames_output_directory -n $model_name -s $scale_factor -t $tile_size -j $thread_configuration -f png &>/dev/null &
    set -l esrgan_pid $last_pid

    # Мониторим прогресс, подсчитывая готовые кадры в папке frames_out
    while kill -0 $esrgan_pid 2>/dev/null
        set -l done_frames (find $frames_output_directory -maxdepth 1 -name '*.png' -type f 2>/dev/null | wc -l | string trim)
        set -l percent (math -s1 "$done_frames * 100 / $total_frames")
        printf "\r       Прогресс: %s%% (Кадр %s из %s)  " $percent $done_frames $total_frames
        sleep 2
    end

    # Финальный вывод (после завершения могут быть ещё не подсчитанные файлы)
    set -l done_frames (find $frames_output_directory -maxdepth 1 -name '*.png' -type f 2>/dev/null | wc -l | string trim)
    set -l percent (math -s1 "$done_frames * 100 / $total_frames")
    printf "\r       Прогресс: %s%% (Кадр %s из %s)  \n" $percent $done_frames $total_frames

    # Ждём завершения и проверяем код возврата
    wait $esrgan_pid
    if test $status -ne 0
        echo "Ошибка: realesrgan-ncnn-vulkan завершился с ошибкой."
        return 1
    end

    echo "[3/4] Собираем видео и возвращаем звук..."
    ffmpeg -loglevel error -stats -framerate 24 -i "$frames_output_directory/frame_%08d.png" -i $input_video -map 0:v:0 -map 1:a:0? -c:v libx264 -crf 18 -pix_fmt yuv420p -c:a copy $ffmpeg_scale_filter $output_video

    if set -ql _flag_keep_tmp
        echo "[4/4] Временные файлы сохранены в $temporary_directory"
    else
        echo "[4/4] Очищаем временные файлы..."
        rm -rf $temporary_directory
    end

    echo "Успешно! Видео сохранено в $output_video"
end
