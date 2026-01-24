function save_qr --description "Generate a QR code and save it to a PNG file (uses qrencode)"
    # Проверяем аргументы. Нужно минимум два: имя файла и текст.
    if test (count $argv) -lt 2
        echo "Использование: save_qr <имя_файла_без_расширения> '<текст или ссылка>'"
        echo "Пример: save_qr beeline_vpn 'ss://...'"
        return 1
    end

    set -l filename "$argv[1].png"
    # Собираем все остальные аргументы в одну строку (на случай пробелов в тексте, хоть в ss:// их и нет)
    set -l text "$argv[2..-1]"

    # -t PNG: явно указываем формат (хотя это дефолт)
    # -s 15: увеличенный размер точки для удобства сканирования
    qrencode -t PNG -s 15 -o "$filename" "$text"

    if test $status -eq 0
        echo "✅ QR-код успешно сохранён в файл: $filename"
        # Показать, где лежит файл
        ls -lh "$filename"
        # Можно раскомментировать следующую строку, чтобы сразу открывать картинку:
        # xdg-open "$filename"
    else
        echo "❌ Ошибка при создании QR-кода."
    end
end
