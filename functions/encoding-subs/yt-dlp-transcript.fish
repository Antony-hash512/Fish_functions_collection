function yt-dlp-transcript --description 'Скачать транскрипт. Опции: --lang, --vtt, --text'
    # 1. Парсим аргументы
    argparse 'lang=' 'vtt' 'text' -- $argv
    or return

    # --- НАСТРОЙКА ЯЗЫКА ---
    set -l target_lang "ru,en"
    if set -q _flag_lang
        set target_lang $_flag_lang
    end

    # --- НАСТРОЙКА ФОРМАТА ---
    # По умолчанию конвертируем в SRT
    set -l format_opts --convert-subs srt

    # Если выбрали --vtt
    if set -q _flag_vtt
        set format_opts --convert-subs vtt
    end

    # --- ЗАПУСК ---
    yt-dlp --write-subs --write-auto-subs --sub-langs "$target_lang" --skip-download $format_opts $argv
end
