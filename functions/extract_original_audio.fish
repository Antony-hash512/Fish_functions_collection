function extract_original_audio -d "Извлекает оригинальную или перекодированную звуковую дорожку"
    argparse 'e/encode=' -- $argv
    or return 1

    if test (count $argv) -eq 0
        echo "Использование: extract_original_audio [--encode <wav|mp3|ogg>] <входное_видео> [выходной_аудиофайл]"
        return 1
    end

    # Проверяем корректность флага --encode, если он передан
    if set -q _flag_encode
        switch $_flag_encode
            case wav mp3 ogg
                # Корректный формат
            case '*'
                echo "Ошибка: Неподдерживаемый формат для перекодирования '$_flag_encode'. Доступны: wav, mp3, ogg."
                return 1
        end
    end

    set input_file $argv[1]

    if not test -f "$input_file"
        echo "Ошибка: Файл '$input_file' не найден."
        return 1
    end

    # Определяем кодек аудио с помощью ffprobe
    set codec (ffprobe -v error -select_streams a:0 -show_entries stream=codec_name -of default=noprint_wrappers=1:nokey=1 "$input_file" | string trim)
    
    if test -z "$codec"
        echo "Ошибка: В файле '$input_file' не найдена аудиодорожка."
        return 1
    end

    if test (count $argv) -ge 2
        set output_file $argv[2]
    else
        if set -q _flag_encode
            set ext $_flag_encode
        else
            # Подбираем правильное расширение в зависимости от кодека
            set ext "mka" # Универсальный аудиоконтейнер Matroska на крайний случай
            switch "$codec"
                case aac
                    set ext "m4a"
                case mp3
                    set ext "mp3"
                case opus
                    set ext "opus"
                case vorbis
                    set ext "ogg"
                case flac
                    set ext "flac"
                case alac
                    set ext "m4a"
                case "pcm*"
                    set ext "wav"
                case ac3
                    set ext "ac3"
            end
        end
        
        # Меняем расширение видеофайла на подобранное
        set output_file (string replace -r '\.[^\.]+$' ".$ext" "$input_file")
    end

    if set -q _flag_encode
        echo "Перекодирование аудио (оригинальный кодек: $codec) из '$input_file' в '$output_file' (формат: $_flag_encode)..."
        
        # Подбираем подходящий аудиокодек для ffmpeg
        set codec_opt ""
        switch $_flag_encode
            case wav
                set codec_opt "pcm_s16le"
            case mp3
                set codec_opt "libmp3lame"
            case ogg
                set codec_opt "libvorbis"
        end

        ffmpeg -i "$input_file" -vn -c:a $codec_opt "$output_file"
    else
        echo "Извлечение оригинального аудио (кодек: $codec) из '$input_file' в '$output_file'..."
        ffmpeg -i "$input_file" -vn -c:a copy "$output_file"
    end
end
