function say-ru-betatest1-direct --description "Озвучить текст (Русский, Piper: Irina) с выбором устройства"
    argparse 'f/fast' -- $argv
    or return 1

    # Проверка Piper
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

    # Проверка модели Ирины
    set -l model_dir ~/.local/share/piper-voices
    set -l model_path "$model_dir/ru_RU-irina-medium.onnx"
    set -l conf_path "$model_path.json"

    if not test -f "$model_path"
        echo "⚠️ Голосовая модель 'Irina' не найдена."
        read -P "Скачать модель (около 60 МБ)? [y/N] > " confirm
        if contains -- $confirm y Y yes
            mkdir -p "$model_dir"
            echo "Скачиваю модель Irina..."
            curl -L -o "$model_path" "https://huggingface.co/rhasspy/piper-voices/resolve/v1.0.0/ru/ru_RU/irina/medium/ru_RU-irina-medium.onnx"
            curl -L -o "$conf_path" "https://huggingface.co/rhasspy/piper-voices/resolve/v1.0.0/ru/ru_RU/irina/medium/ru_RU-irina-medium.onnx.json"
        else
            echo "Отмена."
            return 1
        end
    end

    # Настройка плеера
    set -l play_cmd "paplay --raw --channels=1 --rate=22050 --format=s16le"

    if not set -q _flag_fast
        set -l sinks (pactl list short sinks | awk '{print $2}')
        if test -z "$sinks"
            echo "Ошибка: Не найдено устройств вывода звука."
            return 1
        end

        set -l selected_sink (printf "%s\n" $sinks | fzf --prompt="Куда выводить звук (Irina)? > " --height=10 --layout=reverse)
        if test -z "$selected_sink"
            echo "Отмена."
            return 0
        end
        set play_cmd "$play_cmd --device=$selected_sink"
        echo "▶ Устройство: $selected_sink"
    else
        echo "▶ Режим --fast: устройство по умолчанию"
    end

    # Получение текста
    set -l text_to_say "$argv"
    if test -z "$text_to_say"
        if set -q WAYLAND_DISPLAY
            set text_to_say (wl-paste)
        else
            set text_to_say (xclip -o -selection clipboard 2>/dev/null)
        end
    end

    if test -z "$text_to_say"
        set text_to_say "Буфер обмена пуст."
    end

    echo "▶ Читаю текст..."
    
    # Озвучка
    echo "$text_to_say" | piper-tts -m "$model_path" --output-raw 2>/dev/null | eval $play_cmd 2>/dev/null
end
