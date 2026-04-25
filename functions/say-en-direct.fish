function say-en-direct --description "Озвучить английский текст из буфера (Piper + выбор устройства)"
    # Парсим аргументы (ищем флаг --fast)
    argparse 'f/fast' -- $argv
    or return 1

    # 1. Проверяем наличие движка piper-tts
    if not command -v piper-tts >/dev/null
        echo "⚠️ Утилита piper-tts не найдена."
        read -P "Установить piper-tts-bin через paru? [y/N] > " confirm
        if contains -- $confirm y Y yes
            paru -S piper-tts-bin
        else
            echo "Отмена."
            return 1
        end
    end

    # 2. Проверяем наличие нейромодели Lessac
    set -l model_dir ~/.local/share/piper-voices
    set -l model_path "$model_dir/en_US-lessac-medium.onnx"
    set -l conf_path "$model_path.json"

    if not test -f "$model_path"
        echo "⚠️ Голосовая модель 'Lessac' не найдена."
        read -P "Скачать модель (около 45 МБ)? [y/N] > " confirm
        if contains -- $confirm y Y yes
            mkdir -p "$model_dir"
            echo "Скачиваю модель..."
            curl -L -o "$model_path" "https://huggingface.co/rhasspy/piper-voices/resolve/v1.0.0/en/en_US/lessac/medium/en_US-lessac-medium.onnx"
            curl -L -o "$conf_path" "https://huggingface.co/rhasspy/piper-voices/resolve/v1.0.0/en/en_US/lessac/medium/en_US-lessac-medium.onnx.json"
        else
            echo "Отмена."
            return 1
        end
    end

    # 3. Выбор устройства или быстрый запуск
    # Формируем базовую команду плеера: raw-данные, моно (1 канал), 22050 Hz, 16-bit
    set -l play_cmd "paplay --raw --channels=1 --rate=22050 --format=s16le"

    if not set -q _flag_fast
        # Если нет ключа --fast, предлагаем выбрать устройство вывода (sink)
        set -l sinks (pactl list short sinks | awk '{print $2}')
        if test -z "$sinks"
            echo "Ошибка: Не найдено устройств вывода звука."
            return 1
        end

        set -l selected_sink (printf "%s\n" $sinks | fzf --prompt="Куда выводить звук? > " --height=10 --layout=reverse)
        
        if test -z "$selected_sink"
            echo "Отмена."
            return 0
        end
        
        # Добавляем выбранное устройство к команде плеера
        set play_cmd "$play_cmd --device=$selected_sink"
        echo "▶ Устройство: $selected_sink"
    else
        echo "▶ Режим --fast: аудио пойдет в устройство по умолчанию"
    end

    # 4. Получаем текст
    set -l text_to_say "$argv"
    if test -z "$text_to_say"
        if set -q WAYLAND_DISPLAY
            set text_to_say (wl-paste)
        else
            set text_to_say (xclip -o -selection clipboard 2>/dev/null)
        end
    end

    if test -z "$text_to_say"
        set text_to_say "Clipboard is empty, nothing to say."
    end

    echo "▶ Читаю текст..."
    echo "  (Нажми Ctrl+C для остановки)"

    # 5. Озвучка
    # Используем eval, чтобы shell правильно развернул команду play_cmd с нужными ключами
    echo "$text_to_say" | piper-tts -m "$model_path" --output-raw 2>/dev/null | eval $play_cmd 2>/dev/null
end
