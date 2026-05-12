function launch_cosyvoice_server --description "Устанавливает, настраивает и запускает CosyVoice 2"
    set cosyvoice_dir ~/git/CosyVoice
    set model_dir pretrained_models/FunAudioLLM/CosyVoice2-0.5B

    if not test -d $cosyvoice_dir
        echo "Клонируем репозиторий CosyVoice..."
        git clone --recursive https://github.com/FunAudioLLM/CosyVoice.git $cosyvoice_dir
    end

    cd $cosyvoice_dir

    if not test -d .venv
        echo "Создаем чистое окружение Python 3.10..."
        uv venv --python 3.10 .venv
    end

    echo "Проверяем зависимости (включен подробный вывод -v)..."
    # 1. Базовые инструменты сборки и pynini
    uv pip install -v setuptools wheel pynini==2.1.5

    # 2. Лечим капризный whisper (без изоляции сборки)
    uv pip install -v openai-whisper==20231117 --no-build-isolation

    # 3. Устанавливаем requirements.txt, разрешая брать пакеты из всех репозиториев
    if test -f requirements.txt
        uv pip install -v -r requirements.txt --index-strategy unsafe-best-match
    end

    # 4. Страхуем основные библиотеки
    uv pip install -v gradio huggingface_hub torch torchaudio librosa

    if not test -f $model_dir/CosyVoice-BlankEN/model.safetensors
        echo "Скачиваем веса модели (~2 ГБ)..."
        uv run hf download FunAudioLLM/CosyVoice2-0.5B --local-dir $model_dir
    end

    echo "Запускаем сервер на http://127.0.0.1:50000 ..."
    set -x PYTHONPATH third_party/Matcha-TTS
    uv run webui.py --port 50000 --model_dir $model_dir
end
