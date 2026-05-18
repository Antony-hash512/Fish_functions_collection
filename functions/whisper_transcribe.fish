function whisper_transcribe -d "Транскрипция аудио/видео в SRT через whisper.cpp"
    # Парсинг аргументов: флаг -l (или --language) требует значения (=)
    argparse 'l/language=' -- $argv
    or return 1 # Прерываем, если переданы неверные флаги

    # Устанавливаем язык по умолчанию
    set lang auto
    if set -q _flag_l
        set lang $_flag_l
    end

    # После argparse в $argv остаются только позиционные аргументы (путь к файлу)
    set input_file $argv[1]

    # 0. Проверка наличия входного файла
    if test -z "$input_file"
        set_color yellow
        echo "Использование: whisper_transcribe [-l язык] <путь_к_медиа_файлу>"
        echo "Примеры:"
        echo "  whisper_transcribe video.mp4          # Автоопределение языка (по умолчанию)"
        echo "  whisper_transcribe -l ru video.mp4    # Жестко задать русский"
        echo "  whisper_transcribe -l en video.mp4    # Перевести на английский"
        set_color normal
        return 1
    end

    if not test -f "$input_file"
        set_color red
        echo "Ошибка: Файл '$input_file' не найден!"
        set_color normal
        return 1
    end

    set whisper_dir ~/git/whisper.cpp
    set whisper_bin $whisper_dir/build/bin/whisper-cli
    set model_file $whisper_dir/models/ggml-large-v3.bin

    # 1. Проверка наличия собранного бинарника whisper.cpp
    if not test -f "$whisper_bin"
        set_color red
        echo "Сборка whisper.cpp не найдена: $whisper_bin"
        set_color normal
        echo "Пожалуйста, соберите проект. Вот быстрые инструкции для Arch Linux:"
        echo ""
        echo "--- Для сборки с CUDA (Рекомендуется при наличии GPU NVIDIA) ---"
        echo "  cd ~/git/whisper.cpp"
        echo "  rm -rf build"
        echo "  fish_add_path /opt/cuda/bin"
        echo "  cmake -B build -DGGML_CUDA=1"
        echo "  cmake --build build --config Release"
        echo ""
        echo "--- Для сборки только на CPU ---"
        echo "  cd ~/git/whisper.cpp"
        echo "  rm -rf build"
        echo "  cmake -B build"
        echo "  cmake --build build --config Release"
        return 1
    end

    # 2. Проверка и скачивание модели large-v3
    if not test -f "$model_file"
        set_color yellow
        echo "Модель large-v3 не найдена. Начинаю скачивание (около 3 ГБ)..."
        set_color normal
        pushd $whisper_dir
        bash ./models/download-ggml-model.sh large-v3
        popd
    end

    # 3. Подготовка аудио через ffmpeg (конвертация в 16kHz, 16-bit, Mono WAV)
    # Используем /tmp/ чтобы не мусорить в рабочей папке
    set base_name (basename "$input_file" | string replace -r '\.[^\.]+$' '')
    set input_dir (dirname "$input_file")
    set temp_wav "/tmp/whisper_temp_$base_name.wav"

    set_color cyan
    echo "Подготовка аудиодорожки через ffmpeg..."
    set_color normal

    # Флаги -y (перезапись), -v error (скрыть лишний лог), -stats (показать прогресс)
    if not ffmpeg -y -v error -stats -i "$input_file" -ar 16000 -ac 1 -c:a pcm_s16le "$temp_wav"
        set_color red
        echo "Ошибка при извлечении аудио через ffmpeg."
        set_color normal
        return 1
    end

    # 4. Транскрипция и создание SRT
    set_color green
    echo "Запуск транскрипции. Модель: large-v3. Язык: $lang"
    set_color normal

    # Запускаем whisper-cli с пробросом нужного языка
    $whisper_bin -m "$model_file" -f "$temp_wav" -osrt -l "$lang"

    # Проверяем успешность и переносим результат
    if test -f "$temp_wav.srt"
        mv "$temp_wav.srt" "$input_dir/$base_name.srt"
        set_color green
        echo ""
        echo "Успех! Субтитры сохранены как: $input_dir/$base_name.srt"
        set_color normal
    else
        set_color red
        echo "Критическая ошибка: файл субтитров не был сгенерирован."
        set_color normal
    end

    # Подчищаем временный файл
    rm -f "$temp_wav"
end
