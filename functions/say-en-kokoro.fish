function say-en-kokoro --description "Text-to-Speech (Kokoro Smart Context) via uv (Portable)"
    argparse 'f/fast' 'u/update' 's/save=' 'p/play-and-save=' -- $argv
    or return 1

    if not command -v uv >/dev/null
        echo "⚠️ 'uv' utility not found."
        return 1
    end

    set -l kokoro_dir ~/.local/share/kokoro-en
    set -l script_path "$kokoro_dir/tts_inference.py"

    # --- САМОРАСПАКОВКА PYTHON-СКРИПТА ---
    if set -q _flag_update; or not test -f "$script_path"
        echo "▶ Setting up Kokoro environment in $kokoro_dir..."
        mkdir -p "$kokoro_dir"
        
        echo 'import sys
import os
import io
import warnings
import logging

# Глушим логи
os.environ["TRANSFORMERS_VERBOSITY"] = "error"
os.environ["PYTHONWARNINGS"] = "ignore"

original_stdout = sys.stdout
sys.stdout = sys.stderr

warnings.filterwarnings("ignore")
logging.getLogger("transformers").setLevel(logging.ERROR)

import torch
import scipy.io.wavfile
import numpy as np
from kokoro import KPipeline

text = sys.argv[1] if len(sys.argv) > 1 else "Text not provided."

# Инициализируем пайплайн для американского английского ("a")
# Модель скачается автоматически при первом запуске!
pipeline = KPipeline(lang_code="a")

# Используем качественный женский голос (af_heart)
generator = pipeline(text, voice="af_heart", speed=1.0)

all_audio = []
for _, _, audio in generator:
    all_audio.append(audio)

if all_audio:
    final_audio = np.concatenate(all_audio)
    # Конвертируем студийный float32 в стандартный 16-bit PCM (paplay его обожает)
    audio_int16 = (final_audio * 32767.0).astype(np.int16)

    wav_io = io.BytesIO()
    scipy.io.wavfile.write(wav_io, 24000, audio_int16)

    sys.stdout = original_stdout
    sys.stdout.buffer.write(wav_io.getvalue())' > "$script_path"
        echo "✅ Script successfully updated!"
        
        if not set -q _flag_fast; and test -z "$argv"
            return 0
        end
    end
    # --- КОНЕЦ САМОРАСПАКОВКИ ---

    # Логика выбора устройства и действия
    set -l play_cmd paplay
    set -l save_file ""
    set -l action "play"

    if set -q _flag_save
        set action "save"
        set save_file $_flag_save
    else if set -q _flag_play_and_save
        set action "play_and_save"
        set save_file $_flag_play_and_save
    end

    if not set -q _flag_fast
        if test "$action" = "save"
            echo "▶ Mode: Save to file ($save_file)"
        else if test "$action" = "play_and_save"
            set -l sinks (pactl list short sinks | awk '{print $2}')
            set -l selected_sink (printf "%s\n" $sinks | fzf --prompt="Select playback device > " --height=10 --layout=reverse)
            if test -z "$selected_sink"
                echo "Cancelled."
                return 0
            end
            set -a play_cmd --device=$selected_sink
            echo "▶ Device: $selected_sink"
            echo "▶ Save file: $save_file"
        else
            set -l sinks (pactl list short sinks | awk '{print $2}')
            set -l menu_options
            for s in $sinks
                set -a menu_options "🔊 Play: $s"
                set -a menu_options "💾🔊 Play and save: $s"
            end
            set -a menu_options "💾 Save to file only"

            set -l selected_option (printf "%s\n" $menu_options | fzf --prompt="Select action > " --height=15 --layout=reverse)
            
            if test -z "$selected_option"
                echo "Cancelled."
                return 0
            end

            if string match -q "💾 Save to file only*" "$selected_option"
                set action "save"
                read -P "Enter filename (.wav): " save_file
                if test -z "$save_file"
                    echo "Cancelled. Filename not provided."
                    return 0
                end
            else if string match -q "💾🔊 Play and save:*" "$selected_option"
                set action "play_and_save"
                set -l selected_sink (string replace "💾🔊 Play and save: " "" "$selected_option")
                set -a play_cmd --device=$selected_sink
                read -P "Enter filename (.wav): " save_file
                if test -z "$save_file"
                    echo "Cancelled. Filename not provided."
                    return 0
                end
                echo "▶ Device: $selected_sink"
            else if string match -q "🔊 Play:*" "$selected_option"
                set action "play"
                set -l selected_sink (string replace "🔊 Play: " "" "$selected_option")
                set -a play_cmd --device=$selected_sink
                echo "▶ Device: $selected_sink"
            end
        end
    else
        if test "$action" = "play_and_save"
            echo "▶ Mode --fast: default device, saving to $save_file"
        else if test "$action" = "save"
            echo "▶ Mode: Save to file ($save_file)"
        else
            echo "▶ Mode --fast: default device"
        end
    end

    # Текст из буфера
    set -l text_to_say "$argv"
    if test -z "$text_to_say"
        if set -q WAYLAND_DISPLAY
            set text_to_say (wl-paste)
        else
            set text_to_say (xclip -o -selection clipboard 2>/dev/null)
        end
    end

    if test -z "$text_to_say"
        set text_to_say "Clipboard is empty."
    end

    echo "▶ Reading text (Kokoro Smart Context)..."
    echo "  (Press Ctrl+C to stop. First run will download ~300MB model)"

    # Запускаем через uv со всеми нужными зависимостями
    if test "$action" = "save"
        uv run --python 3.12 --with "torch" --with "kokoro>=0.8.4" --with "scipy" --with "soundfile" "$script_path" "$text_to_say" > "$save_file"
        echo "✅ File saved: $save_file"
    else if test "$action" = "play_and_save"
        uv run --python 3.12 --with "torch" --with "kokoro>=0.8.4" --with "scipy" --with "soundfile" "$script_path" "$text_to_say" | tee "$save_file" | eval $play_cmd
        echo "✅ File saved: $save_file"
    else
        uv run --python 3.12 --with "torch" --with "kokoro>=0.8.4" --with "scipy" --with "soundfile" "$script_path" "$text_to_say" | eval $play_cmd
    end
end
