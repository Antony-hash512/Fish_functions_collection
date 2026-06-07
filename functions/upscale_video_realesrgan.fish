function upscale_video_realesrgan --description 'Upscale video using realesrgan-ncnn-vulkan'
    argparse 'r/res=' 's/style=' 't/tmpdir=' k/keep-tmp h/help 'start=' 'end=' 'frames-dir=' 'fps=' 'audio=' 'gpu=' 2/2x -- $argv
    or return 1

    if set -ql _flag_help
        echo "Использование: upscale_video_realesrgan [опции] <входящее_видео> <исходящее_видео>"
        echo "Опции:"
        echo "  -r, --res        Разрешение: 720p, 1080p, 2k, 4k, 5k (по умолчанию: 2k)"
        echo "  -s, --style      Стиль: anime, photo (по умолчанию: anime)"
        echo "  -t, --tmpdir     Кастомная временная директория"
        echo "  --start          Номер начального кадра (например: 240)"
        echo "  --end            Номер конечного кадра (например: 600)"
        echo "  -k, --keep-tmp   Не удалять временные файлы после работы"
        echo "  --gpu            Выбор GPU: 0 — список, N — номер GPU (без флага — авто)"
        echo "  -2, --2x         Принудительно использовать scale_factor 2 (вместо 4)"
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

    # Определяем ориентацию (горизонтальная или вертикальная)
    set -l is_horizontal false
    set -l probe_target
    set -l width
    set -l height

    if test $frames_mode = true
        set -l source_frames_dir $_flag_frames_dir
        # Ищем первый попавшийся png кадр
        set probe_target (find $source_frames_dir -maxdepth 1 -name '*.png' -type f | head -n 1)
    else
        set probe_target $input_video
    end

    if test -n "$probe_target"; and test -f "$probe_target"
        set width (video_resolution -w "$probe_target" 2>/dev/null)
        set height (video_resolution -h "$probe_target" 2>/dev/null)
        if test -z "$width"; or test -z "$height"
            set width (ffprobe -v error -select_streams v:0 -show_entries stream=width -of csv=p=0 "$probe_target" 2>/dev/null)
            set height (ffprobe -v error -select_streams v:0 -show_entries stream=height -of csv=p=0 "$probe_target" 2>/dev/null)
        end

        if test -n "$width"; and test -n "$height"
            if test $width -gt $height
                set is_horizontal true
                echo "Определена ориентация: Горизонтальная (альбомная) [$width x $height]"
            else
                echo "Определена ориентация: Вертикальная (портретная) [$width x $height]"
            end
        else
            echo "Предупреждение: Не удалось определить разрешение, по умолчанию используем вертикальную ориентацию."
        end
    end

    # Конфигурация разрешения
    set -l target_dim
    set -l ffmpeg_scale_filter

    switch $resolution
        case 720p
            set target_dim 1280
            if test $is_horizontal = true
                set ffmpeg_scale_filter -vf "scale=1280:-2"
            else
                set ffmpeg_scale_filter -vf "scale=-2:1280"
            end
        case 1080p
            set target_dim 1920
            if test $is_horizontal = true
                set ffmpeg_scale_filter -vf "scale=1920:-2"
            else
                set ffmpeg_scale_filter -vf "scale=-2:1920"
            end
        case 2k
            set target_dim 2560
            if test $is_horizontal = true
                set ffmpeg_scale_filter -vf "scale=2560:-2"
            else
                set ffmpeg_scale_filter -vf "scale=-2:2560"
            end
        case 4k
            set target_dim 3840
            if test $is_horizontal = true
                set ffmpeg_scale_filter -vf "scale=3840:-2"
            else
                set ffmpeg_scale_filter -vf "scale=-2:3840"
            end
        case 5k
            set target_dim 5120
            if test $is_horizontal = true
                set ffmpeg_scale_filter -vf "scale=5120:-2"
            else
                set ffmpeg_scale_filter -vf "scale=-2:5120"
            end
        case '*'
            echo "Ошибка: Неизвестное разрешение '$resolution'. Доступные разрешения: 720p, 1080p, 2k, 4k, 5k."
            return 1
    end

    # Задаем параметры для нативного 4x-апскейла.
    # Модели realesrgan-x4plus и realesrgan-x4plus-anime спроектированы исключительно под масштаб 4x.
    set -l scale_factor 4
    set -l tile_size 256
    set -l thread_configuration "1:2:1"

    # Принудительный override масштаба через флаг --2x / -2
    if set -ql _flag_2x
        set scale_factor 2
        set thread_configuration "2:2:2"
        echo "Принудительно установлен масштаб scale_factor: 2 (флаг --2x)"
    end

    if test -n "$width"; and test -n "$height"; and test $width -gt 0; and test $height -gt 0
        set -l max_input_dim $width
        if test $height -gt $width
            set max_input_dim $height
        end

        # Вычисляем требуемый коэффициент масштабирования для информации
        set -l req_ratio (math -s2 "$target_dim / $max_input_dim")

        echo "Параметры апскейла:"
        echo "  Исходный макс. размер: $max_input_dim"
        echo "  Целевой макс. размер: $target_dim"
        echo "  Необходимый масштаб: $req_ratio"
        echo "  Выбранный scale_factor: $scale_factor"
    else
        echo "Предупреждение: Разрешение входящего файла не определено. Используем дефолтные параметры."
    end

    # Определяем GPU для Vulkan
    # Без --gpu: авто-режим (realesrgan сам выбирает GPU)
    # --gpu 0:  интерактивный выбор из списка
    # --gpu N:  использовать GPU с номером N из списка
    set -l gpu_args

    if set -ql _flag_gpu
        set -l gpu_names
        if type -q vulkaninfo
            for line in (vulkaninfo --summary 2>/dev/null | grep 'deviceName')
                set -a gpu_names (string replace -r '^\s*deviceName\s*=\s*' '' $line)
            end
        end

        if test (count $gpu_names) -eq 0
            echo "Предупреждение: vulkaninfo недоступен, невозможно определить список GPU."
            return 1
        end

        if test "$_flag_gpu" = 0
            # Интерактивный выбор
            echo "Доступные GPU:"
            for i in (seq (count $gpu_names))
                echo "  $i) $gpu_names[$i]"
            end
            read -P "Выберите GPU (1—"(count $gpu_names)"): " -l user_choice
            if not string match -qr '^\d+$' "$user_choice"; or test "$user_choice" -lt 1; or test "$user_choice" -gt (count $gpu_names)
                echo "Ошибка: Некорректный выбор."
                return 1
            end
            set -l gpu_index (math "$user_choice - 1")
            set gpu_args -g $gpu_index
            echo "GPU для апскейла: $gpu_names[$user_choice]"
        else
            # Прямой выбор по номеру
            set -l user_choice $_flag_gpu
            if not string match -qr '^\d+$' "$user_choice"; or test "$user_choice" -lt 1; or test "$user_choice" -gt (count $gpu_names)
                echo "Ошибка: Некорректный номер GPU '$user_choice'. Доступные: 1—"(count $gpu_names)"."
                return 1
            end
            set -l gpu_index (math "$user_choice - 1")
            set gpu_args -g $gpu_index
            echo "GPU для апскейла: $gpu_names[$user_choice] (device $gpu_index)"
        end
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

        # Запускаем апскейлер в фоне, логируя ошибки во временный файл
        set -l esrgan_log "$temporary_directory/realesrgan_stderr.log"
        realesrgan-ncnn-vulkan $gpu_args -i $upscale_input_dir -o $frames_output_directory -n $model_name -s $scale_factor -t $tile_size -j $thread_configuration -f png 2>$esrgan_log >/dev/null &
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
            echo "Ошибка: realesrgan-ncnn-vulkan завершился с ошибкой (код $esrgan_status)."
            if test -f $esrgan_log
                echo "--- ЛОГ ОШИБОК РАБОТЫ АПСКЕЙЛЕРА ---"
                cat $esrgan_log
                echo -------------------------------------
            end
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

        # Запускаем апскейлер в фоне, логируя ошибки во временный файл
        set -l esrgan_log "$temporary_directory/realesrgan_stderr.log"
        realesrgan-ncnn-vulkan $gpu_args -i $frames_input_directory -o $frames_output_directory -n $model_name -s $scale_factor -t $tile_size -j $thread_configuration -f png 2>$esrgan_log >/dev/null &
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
        set -l esrgan_status $status
        if test $esrgan_status -ne 0
            echo "Ошибка: realesrgan-ncnn-vulkan завершился с ошибкой (код $esrgan_status)."
            if test -f $esrgan_log
                echo "--- ЛОГ ОШИБОК РАБОТЫ АПСКЕЙЛЕРА ---"
                cat $esrgan_log
                echo -------------------------------------
            end
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
