function migrate_antigravity_settings --description "Переезд на старый-добрый Antigravity IDE с отображением кода, после выпуска второй версии"
    #echo "Удаление дефолтных директорий новой IDE (если они уже созданы)..."
    #rm -rf ~/.config/"Antigravity IDE"
    #rm -rf ~/.antigravity-ide

    echo "Создание симлинков для пользовательских настроек и плагинов..."
    ln -s ~/.config/Antigravity ~/.config/"Antigravity IDE"
    ln -s ~/.antigravity ~/.antigravity-ide

    echo "Сброс кэша плагинов..."
    rm -f ~/.antigravity-ide/extensions/extensions.json

    echo "Готово! Симлинки созданы, можно запускать Antigravity IDE."

    echo "#Смена пакета на трушный в Arch Linux:"
    echo "sudo pacman -Syu"
    echo "paru -Rns antigravity"
    echo "paru -S antigravity-ide"
    echo "paru -Sua"
end
