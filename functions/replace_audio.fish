function replace_audio -d "Заменяет аудиодорожку в видео с перекодировкой в AAC (320 kbps)"
    if test (count $argv) -lt 2
        echo "Использование: replace_audio <видео_файл> <аудио_файл> [выходной_файл]"
        return 1
    end

    set video_file $argv[1]
    set audio_file $argv[2]

    if test (count $argv) -eq 3
        set output_file $argv[3]
    else
        # Если имя выходного файла не указано, генерируем его автоматически на основе имени видео
        set basename (string replace -r '\.[^.]+$' '' -- (basename $video_file))
        set output_file "{$basename}_aac320.mp4"
    end

    ffmpeg -i "$video_file" -i "$audio_file" -map 0:v -map 1:a -c:v copy -c:a aac -b:a 320k "$output_file"
end
