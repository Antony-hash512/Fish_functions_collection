function show_qr --description "Display a QR code directly in the terminal (ANSI UTF8)"
    # Проверяем, передан ли аргумент
    if test (count $argv) -eq 0
        echo "Ошибка: укажите текст или ссылку для генерации QR-кода."
        echo "Пример: show_qr 'ss://...'"
        return 1
    end

    # Генерируем QR-код в терминале (ANSI UTF8 для лучшей совместимости)
    qrencode -t ansiutf8 "$argv[1]"
end
