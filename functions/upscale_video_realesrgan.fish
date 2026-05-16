function upscale_video_realesrgan --description 'Upscale video using realesrgan-ncnn-vulkan'
    argparse 'r/res=' 's/style=' 't/tmpdir=' k/keep-tmp h/help 'start=' 'end=' 'frames-dir=' 'fps=' 'audio=' -- $argv
    or return 1

    if set -ql _flag_help
        echo "Использование: upscale_video_realesrgan [опции] <входящее_видео> <исходящее_видео>"
        echo "Опции:"
        echo "  -r, --res        Разрешение: 1080p, 2k, 4k, 5k (по умолчанию: 2k)"
        echo "  -s, --style      Стиль: anime, photo (по умолчанию: anime)"
        echo "  -t, --tmpdir     Кастомная временная директория"
        echo "  --start          Номер начального кадра (например: 240)"
        echo "  --end            Номер конечного кадра (например: 600)"
        echo "  -k, --keep-tmp   Не удалять временные файлы после работы"
        echo "  -h, --help       Показать эту справку"
        echo ""
        echo "Режим сборки из кадров (без извлечения из видео):"
        echo "  --frames-dir     Каталог с PNG-кадрами (формат: frame_XXXXXXXX.png)"
        echo "  --fps            Частота кадров (по умолчанию: 24)"
        echo "  --audio          Аудиофайл для подмешивания (опционально)"
        echo "  --start/--end    Диапазон номеров кадров для сборки"
        echo ""
        echo "Пример: upscale_video_realesrgan --frames-dir ./frames --fps 30 --audio orig.mp4 -r 2k output.mp4"
        return 0
    end

    # Определяем режим работы: из видео или из каталога с кадрами
    set -l frames_mode false
    if set -ql _flag_frames_dir
        set frames_mode true
    end

    set -l input_video
    set -l output_video

    if test $frames_mode = true
        # В режиме кадров нужен только выходной файл
        if test (count $argv) -lt 1
            echo "Ошибка: Не указано исходящее видео."
            echo "Использование: upscale_video_realesrgan --frames-dir <каталог> [опции] <исходящее_видео>"
            return 1
        end
        set output_video $argv[1]
    else
        if test (count $argv) -lt 2
            echo "Ошибка: Не указаны входящее и исходящее видео."
            echo "Использование: upscale_video_realesrgan [опции] <входящее_видео> <исходящее_видео>"
            return 1
        end
        set input_video $argv[1]
        set output_video $argv[2]
    end

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
    if not type -q realesrgan-ncnn-vulkan; or not type -q ffmpeg; or not type -q ffprobe
        echo "Ошибка: Установите realesrgan-ncnn-vulkan, ffmpeg и ffprobe"
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
        case 5k
            set scale_factor 4
            set tile_size 256
            set thread_configuration "1:2:2"
            set ffmpeg_scale_filter -vf "scale=-2:5120"
        case '*'
            echo "Ошибка: Неизвестное разрешение '$resolution'. Доступные разрешения: 1080p, 2k, 4k, 5k."
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

    if test $frames_mode = true
        # === РЕЖИМ СБОРКИ ИЗ КАТАЛОГА С КАДРАМИ ===
        set -l source_frames_dir $_flag_frames_dir

        if not test -d $source_frames_dir
            echo "Ошибка: Каталог '$source_frames_dir' не найден."
            return 1
        end

        # Определяем FPS (по умолчанию 24)
        set -l fps 24
        if set -ql _flag_fps
            set fps $_flag_fps
        end

        # Определяем каталог для входных кадров апскейлера
        set -l upscale_input_dir
        set -l range_mode false
        set -l moved_frames # Список перемещённых файлов для возврата

        if set -ql _flag_start; or set -ql _flag_end
            # Режим диапазона: перемещаем выбранные кадры во временный подкаталог
            set range_mode true
            set upscale_input_dir "$source_frames_dir/input"
            mkdir -p $upscale_input_dir

            set -l start_frame 0
            set -l end_frame 99999999
            if set -ql _flag_start
                set start_frame $_flag_start
            end
            if set -ql _flag_end
                set end_frame $_flag_end
            end

            echo "[1/3] Выбираем кадры из $source_frames_dir..."
            echo "       FPS: $fps | Диапазон: $start_frame — $end_frame"

            for frame in (find $source_frames_dir -maxdepth 1 -name '*.png' -type f | sort)
                set -l frame_basename (basename $frame)
                # Извлекаем номер кадра из имени файла (frame_00000270.png -> 270)
                set -l frame_num (string replace -r '^frame_0*' '' (string replace -r '\.png$' '' $frame_basename))
                # Если номер пустой (все нули), значит кадр 0
                if test -z "$frame_num"
                    set frame_num 0
                end

                if test $frame_num -ge $start_frame; and test $frame_num -le $end_frame
                    mv $frame $upscale_input_dir/
                    set -a moved_frames "$upscale_input_dir/$frame_basename"
                end
            end

            if test (count $moved_frames) -eq 0
                echo "Ошибка: Не найдено кадров в диапазоне $start_frame — $end_frame"
                rmdir $upscale_input_dir
                return 1
            end
            echo "       Выбрано кадров: "(count $moved_frames)
        else
            # Без диапазона: подаём каталог напрямую
            set upscale_input_dir $source_frames_dir

            echo "[1/3] Подготавливаем кадры из $source_frames_dir..."
            echo "       FPS: $fps"
        end

        # Считаем количество входных кадров
        set -l total_frames (find $upscale_input_dir -maxdepth 1 -name '*.png' -type f | wc -l | string trim)
        if test $total_frames -eq 0
            echo "Ошибка: Кадры не найдены в $upscale_input_dir"
            return 1
        end

        echo "[2/3] Апскейлим кадры через Vulkan..."
        echo "       Всего кадров: $total_frames"

        # Запускаем апскейлер в фоне
        realesrgan-ncnn-vulkan -i $upscale_input_dir -o $frames_output_directory -n $model_name -s $scale_factor -t $tile_size -j $thread_configuration -f png &>/dev/null &
        set -l esrgan_pid $last_pid

        # Мониторим прогресс
        while kill -0 $esrgan_pid 2>/dev/null
            set -l done_frames (find $frames_output_directory -maxdepth 1 -name '*.png' -type f 2>/dev/null | wc -l | string trim)
            set -l percent (math -s1 "$done_frames * 100 / $total_frames")
            printf "\r       Прогресс: %s%% (Кадр %s из %s)  " $percent $done_frames $total_frames
            sleep 2
        end

        set -l done_frames (find $frames_output_directory -maxdepth 1 -name '*.png' -type f 2>/dev/null | wc -l | string trim)
        set -l percent (math -s1 "$done_frames * 100 / $total_frames")
        printf "\r       Прогресс: %s%% (Кадр %s из %s)  \n" $percent $done_frames $total_frames

        wait $esrgan_pid
        set -l esrgan_status $status

        # Возвращаем перемещённые кадры на место
        if test $range_mode = true
            for frame in $moved_frames
                mv $frame $source_frames_dir/
            end
            rmdir $upscale_input_dir 2>/dev/null
        end

        if test $esrgan_status -ne 0
            echo "Ошибка: realesrgan-ncnn-vulkan завершился с ошибкой."
            return 1
        end

        echo "[3/3] Собираем видео..."
        # Проверяем и исправляем нумерацию кадров перед сборкой (чтобы не было пропусков)
        set -l upscaled_frames (ls -v $frames_output_directory/frame_*.png 2>/dev/null)
        set -l frame_counter 1
        for frame in $upscaled_frames
            set -l new_name (printf "frame_%08d.png" $frame_counter)
            set -l target_path "$frames_output_directory/$new_name"
            if test "$frame" != "$target_path"
                mv -n "$frame" "$target_path"
            end
            set frame_counter (math $frame_counter + 1)
        end

        # Формируем команду ffmpeg в зависимости от наличия аудио
        if set -ql _flag_audio
            ffmpeg -loglevel error -stats -framerate $fps -i "$frames_output_directory/frame_%08d.png" -i $_flag_audio -map 0:v:0 -map 1:a:0 -c:v hevc_nvenc -cq 18 -preset slow -g 48 -bf 3 -pix_fmt yuv420p -c:a copy $ffmpeg_scale_filter -fps_mode cfr $output_video
        else
            ffmpeg -loglevel error -stats -framerate $fps -i "$frames_output_directory/frame_%08d.png" -c:v hevc_nvenc -cq 18 -preset slow -g 48 -bf 3 -pix_fmt yuv420p $ffmpeg_scale_filter -fps_mode cfr $output_video
        end

    else
        # === СТАНДАРТНЫЙ РЕЖИМ: ИЗВЛЕЧЕНИЕ КАДРОВ ИЗ ВИДЕО ===
        echo "[1/4] Извлекаем кадры из $input_video..."
        # Конфигурация диапазона кадров
        set -l select_args
        if set -ql _flag_start; and set -ql _flag_end
            set -a select_args -vf "select='between(n,$_flag_start,$_flag_end)'" -vsync vfr
            echo "Диапазон кадров: с $_flag_start по $_flag_end"
        else if set -ql _flag_start
            set -a select_args -vf "select='gte(n,$_flag_start)'" -vsync vfr
            echo "Диапазон кадров: с $_flag_start и до конца"
        else if set -ql _flag_end
            set -a select_args -vf "select='lte(n,$_flag_end)'" -vsync vfr
            echo "Диапазон кадров: с начала и по $_flag_end"
        end
        ffmpeg -loglevel error -stats -i $input_video $select_args "$frames_input_directory/frame_%08d.png"

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
        # Проверяем и исправляем нумерацию кадров перед сборкой (чтобы не было пропусков)
        set -l upscaled_frames (ls -v $frames_output_directory/frame_*.png 2>/dev/null)
        set -l frame_counter 1
        for frame in $upscaled_frames
            set -l new_name (printf "frame_%08d.png" $frame_counter)
            set -l target_path "$frames_output_directory/$new_name"
            if test "$frame" != "$target_path"
                mv -n "$frame" "$target_path"
            end
            set frame_counter (math $frame_counter + 1)
        end

        # Определяем частоту кадров: приоритет флагу --fps, иначе автоопределение
        set -l fps
        if set -ql _flag_fps
            set fps $_flag_fps
            echo "       Используется принудительный FPS: $fps"
        else
            set fps (ffprobe -v error -select_streams v:0 -show_entries stream=avg_frame_rate -of default=noprint_wrappers=1:nokey=1 $input_video)
        end

        ffmpeg -loglevel error -stats -framerate $fps -i "$frames_output_directory/frame_%08d.png" -i $input_video -map 0:v:0 -map 1:a:0? -c:v hevc_nvenc -cq 18 -preset slow -g 48 -bf 3 -pix_fmt yuv420p -c:a copy $ffmpeg_scale_filter -fps_mode cfr $output_video
    end

    if set -ql _flag_keep_tmp
        echo "[4/4] Временные файлы сохранены в $temporary_directory"
    else
        echo "[4/4] Очищаем временные файлы..."
        rm -rf $temporary_directory
    end

    echo "Успешно! Видео сохранено в $output_video"
end
