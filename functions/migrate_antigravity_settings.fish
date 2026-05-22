function migrate_antigravity_settings
    echo "Удаление дефолтных директорий новой IDE (если они уже созданы)..."
    rm -rf ~/.config/"Antigravity IDE"
    rm -rf ~/.antigravity-ide

    echo "Создание симлинков для пользовательских настроек и плагинов..."
    ln -s ~/.config/Antigravity ~/.config/"Antigravity IDE"
    ln -s ~/.antigravity ~/.antigravity-ide

    echo "Сброс кэша плагинов..."
    rm -f ~/.antigravity-ide/extensions/extensions.json

    echo "Готово! Симлинки созданы, можно запускать Antigravity IDE."
end
