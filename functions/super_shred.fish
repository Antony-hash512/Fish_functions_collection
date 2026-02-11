function super_shred --description "Securely wipe files: 3 passes + zeroing + remove"
    # Проверка на наличие аргументов
    if test (count $argv) -eq 0
        echo "Usage: super_shred <file1> [file2] ..."
        return 1
    end

    # Выполняем shred с запрошенными параметрами
    # --verbose (-v): показывать прогресс
    # --iterations=3 (-n 3): 3 прохода случайными данными
    # --zero (-z): финальный проход нулями (скрывает факт шрединга)
    # --remove (-u): удаление файла после перезаписи
    command shred --verbose --iterations=3 --zero --remove $argv
end
