function separate_audio --description "Разделяет аудио на вокал и музыку (настроенная обертка для audio-separator)"
    # === ВАШ КОНФИГ ===
    # Дефолтная модель для лучшего качества
    set default_model "MDX23C-8KFFT-InstVoc_HQ.ckpt"
    
    # Формат вывода по умолчанию (чтобы не получать flac, если нужен wav)
    set out_format "wav"
    # ==================

    if test (count $argv) -eq 0
        echo "Ошибка: Укажите аудиофайл!"
        echo "Использование: separate_audio <файл.wav> [доп. аргументы]"
        return 1
    end

    # Запускаем через uvx с подстановкой наших дефолтных параметров
    uvx --from "audio-separator[gpu]" audio-separator $argv \
        -m $default_model \
        --output_format $out_format
end
