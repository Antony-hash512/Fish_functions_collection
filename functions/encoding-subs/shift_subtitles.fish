function shift_subtitles --description "Сдвигает тайминги в SRT-субтитрах на заданное количество секунд"
    argparse 'n/nobkp' -- $argv
    or return 1

    set -l file $argv[1]
    set -l offset $argv[2]

    # Проверка наличия аргументов
    if test -z "$file"; or test -z "$offset"
        echo "Использование: shift_subtitles <файл.srt> <секунды> [--nobkp]"
        echo "Пример (вперед): shift_subtitles episode.srt 2.5"
        echo "Пример (назад):  shift_subtitles episode.srt -1.2 --nobkp"
        return 1
    end

    if not test -f "$file"
        echo "Ошибка: Файл '$file' не найден."
        return 1
    end

    set -l tmp_file (mktemp)

    # Изолированный запуск Python-скрипта через uv
    uv run -q -- python -c "
import sys, re
from datetime import datetime, timedelta

try:
    delta = timedelta(seconds=float(sys.argv[1]))
except ValueError:
    print('Ошибка: Смещение должно быть числом.')
    sys.exit(1)

def adjust_time(match):
    t_str = match.group(0)
    try:
        t = datetime.strptime(t_str, '%H:%M:%S,%f')
        new_t = t + delta
        # Предотвращаем уход времени в минус (в Python это переход на 1899 год)
        if new_t.year < 1900:
            new_t = datetime.strptime('00:00:00,000', '%H:%M:%S,%f')
        # Возвращаем в формате ЧЧ:ММ:СС,МММ
        return new_t.strftime('%H:%M:%S,%f')[:-3]
    except ValueError:
        return t_str

with open(sys.argv[2], 'r', encoding='utf-8') as f:
    content = f.read()

# Регулярное выражение для поиска SRT таймингов
pattern = re.compile(r'\d{2}:\d{2}:\d{2},\d{3}')
new_content = pattern.sub(adjust_time, content)

with open(sys.argv[3], 'w', encoding='utf-8') as f:
    f.write(new_content)
" "$offset" "$file" "$tmp_file"

    # Замена исходного файла в случае успешного выполнения
    if test $status -eq 0
        if not set -q _flag_nobkp
            cp "$file" "$file.bak"
            and echo "Создана резервная копия: $file.bak"
        end
        mv "$tmp_file" "$file"
        echo "Успешно: Тайминги в '$file' сдвинуты на $offset сек."
    else
        rm "$tmp_file"
        echo "Ошибка: Произошел сбой при обработке субтитров."
        return 1
    end
end
