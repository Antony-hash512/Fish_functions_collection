function launch_cosyvoice_server --description "Устанавливает, настраивает и запускает CosyVoice 3"
    set cosyvoice_dir ~/git/CosyVoice
    # Изменен путь и название модели на свежую версию с поддержкой русского языка
    set model_dir pretrained_models/FunAudioLLM/Fun-CosyVoice3-0.5B-2512

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
    uv pip install -v setuptools wheel pynini==2.1.5
    uv pip install -v openai-whisper==20231117 --no-build-isolation
    
    if test -f requirements.txt
        uv pip install -v -r requirements.txt --index-strategy unsafe-best-match
    end
    
    uv pip install -v gradio huggingface_hub torch torchaudio librosa

    if not test -d $model_dir
        echo "Скачиваем веса модели CosyVoice 3 (~2 ГБ)..."
        uv run hf download FunAudioLLM/Fun-CosyVoice3-0.5B-2512 --local-dir $model_dir
    end

    echo "Запускаем сервер на http://127.0.0.1:50000 ..."
    set -x PYTHONPATH "third_party/Matcha-TTS"
    uv run webui.py --port 50000 --model_dir $model_dir
    if false
        cd ~/git/CosyVoice
        sed -i 's/输入合成文本/Input text to synthesize/g' webui.py
        sed -i 's/选择推理模式/Select inference mode/g' webui.py
        sed -i 's/预训练音色/Pre-trained voice/g' webui.py
        sed -i 's/3s极速复刻/3s Voice Clone/g' webui.py
        sed -i 's/跨语种复刻/Cross-lingual Clone/g' webui.py
        sed -i 's/自然语言控制/Instruct Mode/g' webui.py
        sed -i 's/操作步骤/Instructions/g' webui.py
        sed -i 's/选择预训练音色/Select voice/g' webui.py
        sed -i 's/是否流式推理/Streaming/g' webui.py
        sed -i 's/速度调节(仅支持非流式推理)/Speed control/g' webui.py
        sed -i 's/随机推理种子/Random seed/g' webui.py
        sed -i 's/选择prompt音频文件，注意采样率不低于16khz/Upload prompt audio/g' webui.py
        sed -i 's/录制prompt音频文件/Record audio/g' webui.py
        sed -i 's/输入prompt文本/Input prompt transcription/g' webui.py
        sed -i 's/输入instruct文本/Input instruct text/g' webui.py
        sed -i 's/生成音频/Generate Audio/g' webui.py
    end
end

