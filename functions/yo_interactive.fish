function yo_interactive -d "Интерактивный ёфикатор с контекстом для субтитров" -a file_path
    if test -z "$file_path"
        set_color yellow
        echo "Использование: yo_interactive <файл.srt>"
        set_color normal
        return 1
    end

    if not test -f "$file_path"
        set_color red
        echo "Ошибка: Файл '$file_path' не найден!"
        set_color normal
        return 1
    end

    set_color cyan
    echo "[1/2] Применяю безопасные (100%) замены через eyo..."
    set_color normal

    # 1. Сначала молча применяем все безопасные замены
    if not eyo -i "$file_path"
        set_color red
        echo "Ошибка при запуске 'eyo'. Убедитесь, что он установлен."
        set_color normal
        return 1
    end

    set_color cyan
    echo "[2/2] Анализирую спорные слова (омографы)..."
    set_color normal

    # 2. Вызываем встроенный Python скрипт для интерактивного выбора
    python -c '
import sys
import subprocess
import re
import os

file_path = sys.argv[1]

# Запускаем линтер eyo, принудительно отключая цвета (чтобы не ломать парсинг)
try:
    env = os.environ.copy()
    env["FORCE_COLOR"] = "0"
    env["NO_COLOR"] = "1"
    res = subprocess.run(["eyo", "--lint", file_path], capture_output=True, text=True, check=True, env=env)
except subprocess.CalledProcessError as e:
    # eyo возвращает ненулевой код, если нашел проблемы (это норм для линтера)
    res = e

unsafe = []
is_unsafe_block = False

# Регулярка для зачистки ANSI цветовых кодов (на случай, если eyo проигнорирует NO_COLOR)
ansi_escape = re.compile(r"\x1B(?:[@-Z\\-_]|\[[0-?]*[ -/]*[@-~])")

# Парсим вывод
for raw_line in res.stdout.splitlines():
    # Очищаем строку от мусора и пробелов по краям
    line = ansi_escape.sub("", raw_line).strip()

    if "Not safe replacements:" in line:
        is_unsafe_block = True
        continue
    if line == "---" and is_unsafe_block:
        is_unsafe_block = False
        continue
        
    if is_unsafe_block:
        # Используем search вместо match, чтобы игнорировать любые символы в начале строки
        m = re.search(r"(\d+)\.\s+(.*?)\s+→\s+(.*?)\s+\((\d+):(\d+)\)", line)
        if m:
            unsafe.append({
                "id": int(m.group(1)),
                "orig": m.group(2).strip(),
                "new": m.group(3).strip(),
                "line": int(m.group(4)) - 1, # В Python индексация с 0
                "col": int(m.group(5)) - 1
            })

if not unsafe:
    print("\n\033[92m[+] Всё готово! Безопасные замены применены, спорных слов не найдено.\033[0m")
    sys.exit(0)

# Читаем файл для контекста
with open(file_path, "r", encoding="utf-8") as f:
    lines = f.readlines()

print("\n\033[93m[?] Найдены слова-омографы. Выберите номера для замены на «ё»:\033[0m\n")

for item in unsafe:
    l_idx = item["line"]
    c_idx = item["col"]
    w_len = len(item["orig"])
    
    if l_idx < len(lines):
        orig_line_full = lines[l_idx]
        if c_idx + w_len <= len(orig_line_full):
            # ANSI escape код для желтого фона/черного текста: \033[30;43m
            highlighted = orig_line_full[:c_idx] + "\033[30;43m" + item["orig"] + "\033[0m" + orig_line_full[c_idx+w_len:]
            print(f" \033[1m{item['id']}.\033[0m {item['orig']} → \033[92m{item['new']}\033[0m")
            print(f"    Контекст: {highlighted.strip()}\n")
        else:
             print(f" {item['id']}. {item['orig']} → {item['new']} (Контекст недоступен)")

ans = input("Номера через запятую (напр: 1, 3-5) или Enter для пропуска: ").strip()

if not ans:
    print("\nСохранено без изменений омографов.")
    sys.exit(0)

# Парсинг ввода
selected = set()
for part in ans.split(","):
    part = part.strip()
    if "-" in part:
        try:
            s, e = map(int, part.split("-"))
            selected.update(range(s, e + 1))
        except ValueError:
            pass
    elif part.isdigit():
        selected.add(int(part))

to_apply = [u for u in unsafe if u["id"] in selected]

# Применяем замены с конца файла (чтобы не съехали индексы колонок в начале)
to_apply.sort(key=lambda x: (x["line"], x["col"]), reverse=True)

applied_count = 0
for item in to_apply:
    l_idx = item["line"]
    c_idx = item["col"]
    w_len = len(item["orig"])
    
    if l_idx < len(lines):
        old_l = lines[l_idx]
        if c_idx + w_len <= len(old_l):
            lines[l_idx] = old_l[:c_idx] + item["new"] + old_l[c_idx+w_len:]
            applied_count += 1

with open(file_path, "w", encoding="utf-8") as f:
    f.writelines(lines)

print(f"\n\033[92m[+] Успешно заменено {applied_count} омографов! Файл сохранён.\033[0m")
' "$file_path"

end
