function say-ru-correct-stress --description "Озвучить текст (VITS+ruaccent) через uv (Portable)"
    # Парсим флаги: -f/--fast для быстрого запуска, -u/--update для перезаписи python-скрипта
    argparse 'f/fast' 'u/update' 's/save=' 'p/play-and-save=' -- $argv
    or return 1

    if not command -v uv >/dev/null
        echo "⚠️ Утилита uv не найдена."
        return 1
    end

    set -l vits_dir ~/.local/share/vits-ru
    set -l script_path "$vits_dir/tts_inference.py"

    # --- САМОРАСПАКОВКА / ОБНОВЛЕНИЕ PYTHON-СКРИПТА ---
    # Скрипт создается, если его нет, ИЛИ если передан флаг --update
    if set -q _flag_update; or not test -f "$script_path"
        echo "▶ Настраиваю окружение и записываю Python-скрипт в $script_path..."
        mkdir -p "$vits_dir"
        
        # Записываем Python-код через Fish-совместимый echo
        echo 'import sys
import os
import io
import warnings
import logging

os.environ["TRANSFORMERS_VERBOSITY"] = "error"
os.environ["PYTHONWARNINGS"] = "ignore"

original_stdout = sys.stdout
sys.stdout = sys.stderr

warnings.filterwarnings("ignore")
logging.getLogger("transformers").setLevel(logging.ERROR)

import torch
import scipy.io.wavfile
from transformers import VitsModel, AutoTokenizer
from ruaccent import RUAccent

text = sys.argv[1] if len(sys.argv) > 1 else "Текст не передан."
model_name = "utrobinmv/tts_ru_free_hf_vits_high_multispeaker"

original_words = text.split()
clean_text = text.replace("+", "")

accentizer = RUAccent()
accentizer.load(omograph_model_size="big_poetry", use_dictionary=True)
auto_text = accentizer.process_all(clean_text)

auto_words = auto_text.split()
final_words = []

if len(original_words) == len(auto_words):
    for orig, auto in zip(original_words, auto_words):
        if "+" in orig:
            final_words.append(orig)
        else:
            final_words.append(auto)
    text = " ".join(final_words)
else:
    text = auto_text

print(f"[Python] Текст с ударениями: {text}")

tokenizer = AutoTokenizer.from_pretrained(model_name)
model = VitsModel.from_pretrained(model_name)
model.eval()

inputs = tokenizer(text, return_tensors="pt")
speaker = 0 

with torch.no_grad():
    output = model(**inputs, speaker_id=speaker).waveform.detach().cpu().numpy()

wav_io = io.BytesIO()
scipy.io.wavfile.write(wav_io, model.config.sampling_rate, output[0])

sys.stdout = original_stdout
sys.stdout.buffer.write(wav_io.getvalue())
' > "$script_path"
        echo "✅ Скрипт успешно обновлен!"
        
        # Если вызвали ТОЛЬКО с флагом --update (без текста и --fast), выходим
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
            echo "▶ Режим: Сохранение в файл ($save_file)"
        else if test "$action" = "play_and_save"
            set -l sinks (pactl list short sinks | awk '{print $2}')
            set -l selected_sink (printf "%s\n" $sinks | fzf --prompt="Куда выводить звук? > " --height=10 --layout=reverse)
            if test -z "$selected_sink"
                echo "Отмена."
                return 0
            end
            set -a play_cmd --device=$selected_sink
            echo "▶ Устройство: $selected_sink"
            echo "▶ Файл для сохранения: $save_file"
        else
            set -l sinks (pactl list short sinks | awk '{print $2}')
            set -l menu_options
            for s in $sinks
                set -a menu_options "🔊 Озвучить: $s"
                set -a menu_options "💾🔊 Озвучить и сохранить: $s"
            end
            set -a menu_options "💾 Только сохранить в файл"

            set -l selected_option (printf "%s\n" $menu_options | fzf --prompt="Выберите действие > " --height=15 --layout=reverse)
            
            if test -z "$selected_option"
                echo "Отмена."
                return 0
            end

            if string match -q "💾 Только сохранить*" "$selected_option"
                set action "save"
                read -P "Введите имя файла (.wav): " save_file
                if test -z "$save_file"
                    echo "Отмена. Имя файла не задано."
                    return 0
                end
            else if string match -q "💾🔊 Озвучить и сохранить:*" "$selected_option"
                set action "play_and_save"
                set -l selected_sink (string replace "💾🔊 Озвучить и сохранить: " "" "$selected_option")
                set -a play_cmd --device=$selected_sink
                read -P "Введите имя файла (.wav): " save_file
                if test -z "$save_file"
                    echo "Отмена. Имя файла не задано."
                    return 0
                end
                echo "▶ Устройство: $selected_sink"
            else if string match -q "🔊 Озвучить:*" "$selected_option"
                set action "play"
                set -l selected_sink (string replace "🔊 Озвучить: " "" "$selected_option")
                set -a play_cmd --device=$selected_sink
                echo "▶ Устройство: $selected_sink"
            end
        end
    else
        if test "$action" = "play_and_save"
            echo "▶ Режим --fast: устройство по умолчанию, сохранение в $save_file"
        else if test "$action" = "save"
            echo "▶ Режим: Сохранение в файл ($save_file)"
        else
            echo "▶ Режим --fast: устройство по умолчанию"
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
        set text_to_say "Буфер пуст."
    end

    echo "▶ Читаю текст (VITS High)..."
    echo "  (Нажми Ctrl+C для остановки)"

    # Запуск Python 3.12 со старыми transformers
    if test "$action" = "save"
        uv run --python 3.12 --with "torch" --with "transformers<4.40" --with "ruaccent" --with "scipy" "$script_path" "$text_to_say" > "$save_file"
        echo "✅ Файл сохранен: $save_file"
    else if test "$action" = "play_and_save"
        uv run --python 3.12 --with "torch" --with "transformers<4.40" --with "ruaccent" --with "scipy" "$script_path" "$text_to_say" | tee "$save_file" | eval $play_cmd
        echo "✅ Файл сохранен: $save_file"
    else
        uv run --python 3.12 --with "torch" --with "transformers<4.40" --with "ruaccent" --with "scipy" "$script_path" "$text_to_say" | eval $play_cmd
    end
end
