function srt2wav --description "Генерирует wav-файлы из SRT и склеивает их по таймингам" -a input_srt out_dir
    if test -z "$out_dir"
        set_color yellow
        echo "Использование: srt2wav <input.srt> <output_dir>"
        set_color normal
        return 1
    end

    if not test -f "$input_srt"
        set_color red
        echo "Ошибка: Файл '$input_srt' не найден!"
        set_color normal
        return 1
    end

    set_color cyan
    echo "[1/4] Подготовка и исправление SRT..."
    set_color normal
    # Используем /tmp/ чтобы не мусорить в рабочей директории
    set fixed_srt "/tmp/fixed_"(basename "$input_srt")
    fix_srt_numbers "$input_srt" "$fixed_srt" 
    
    set_color cyan
    echo "[2/4] Создаем каталог..."
    set_color normal
    mkdir -p "$out_dir"

    set_color cyan
    echo "[3/4] Парсинг SRT и генерация аудио (Kokoro)..."
    set_color normal
    
    # Инициализируем переменные для сборки графа ffmpeg
    set filter_complex ""
    set mix_inputs ""
    set ffmpeg_args -v warning -y
    set count 0

    # Используем awk для надежного извлечения таймингов и текста.
    # RS="" заставляет awk разбивать текст целыми блоками, разделенными пустой строкой.
    set parsed_lines (awk 'BEGIN { RS = ""; FS = "\n" }
    {
        id = $1
        split($2, times, " --> ")
        split(times[1], t, /[:,]/)
        # Переводим часы, минуты, секунды в миллисекунды для фильтра adelay
        ms = (t[1]*3600 + t[2]*60 + t[3]) * 1000 + t[4]
        
        # Склеиваем многострочный текст в одну строку
        text = ""
        for(i=3; i<=NF; i++) text = text " " $i
        gsub(/^ +| +$/, "", text)
        
        # Выводим данные через табуляцию (ID, миллисекунды, текст)
        printf "%s\t%d\t%s\n", id, ms, text
    }' "$fixed_srt")

    for line in $parsed_lines
        # Элегантно распаковываем переменные
        set id (string split -f1 \t "$line")
        set delay_ms (string split -f2 \t "$line")
        set text (string split -f3 \t "$line")

        set wav_file "$out_dir/$id.wav"
        
        set_color yellow
        echo "Озвучиваю блок [$id]: $text"
        set_color normal
        
        # Запуск твоей функции в тихом режиме с прямым сохранением в файл [cite: 52, 58, 74]
        say-en-kokoro -f -s "$wav_file" "$text"
        
        # Если файл успешно создан, добавляем его в граф ffmpeg
        if test -f "$wav_file"
            # Собираем массив аргументов для надежности (без использования eval)
            set -a ffmpeg_args -i "$wav_file"
            
            # all=1 гарантирует задержку всех каналов аудио (даже если Kokoro сгенерирует моно) [cite: 57]
            set filter_complex "$filter_complex""[$count]adelay=$delay_ms:all=1[a$count];"
            set mix_inputs "$mix_inputs""[a$count]"
            
            set count (math $count + 1)
        end
    end

    set_color cyan
    echo "[4/4] Сборка финального result.wav через ffmpeg..."
    set_color normal
    
    # Завершаем граф фильтров вызовом amix. 
    # normalize=0 жизненно важен: без него ffmpeg будет тихо снижать общую громкость с каждым новым добавленным аудио
    set filter_complex "$filter_complex$mix_inputs""amix=inputs=$count:normalize=0[out]"
    set result_file "$out_dir/result.wav"

    # Вызываем ffmpeg, передавая ему собранный массив аргументов
    set -a ffmpeg_args -filter_complex "$filter_complex" -map "[out]" "$result_file"
    ffmpeg $ffmpeg_args

    if test $status -eq 0
        set_color green
        echo "✅ Успех! Финальный файл готов: $result_file"
        set_color normal
    else
        set_color red
        echo "❌ Ошибка при сборке графа аудио в ffmpeg"
        set_color normal
    end
    
    # Подчищаем за собой временный файл
    rm -f "$fixed_srt"
end
