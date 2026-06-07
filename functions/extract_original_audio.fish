function extract_original_audio -d "Извлекает оригинальную звуковую дорожку без перекодирования"
    if test (count $argv) -eq 0
        echo "Использование: extract_original_audio <входное_видео> [выходной_аудиофайл]"
        return 1
    end

    set input_file $argv[1]

    if not test -f "$input_file"
        echo "Ошибка: Файл '$input_file' не найден."
        return 1
    end

    if test (count $argv) -ge 2
        set output_file $argv[2]
    else
        # Определяем кодек аудио с помощью ffprobe
        set codec (ffprobe -v error -select_streams a:0 -show_entries stream=codec_name -of default=noprint_wrappers=1:nokey=1 "$input_file" | string trim)
        
        if test -z "$codec"
            echo "Ошибка: В файле '$input_file' не найдена аудиодорожка."
            return 1
        end

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
        
        # Меняем расширение видеофайла на подобранное
        set output_file (string replace -r '\.[^\.]+$' ".$ext" $input_file)
    end

    echo "Извлечение оригинального аудио (кодек: $codec) из '$input_file' в '$output_file'..."
    
    # -c:a copy означает прямое копирование потока без рендера
    ffmpeg -i "$input_file" -vn -c:a copy "$output_file"
end
