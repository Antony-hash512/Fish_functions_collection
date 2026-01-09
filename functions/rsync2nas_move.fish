function rsync2nas_move --argument-names source target --description 'Move files to NAS using rsync size-only check'
    # Проверка: введены ли оба аргумента
    if test -z "$source"; or test -z "$target"
        echo "🔴 Ошибка: Нужно два пути."
        echo "Использование: rsync2nas <откуда/> <куда/>"
        return 1
    end

    # Эхо команды, чтобы ты видел, что происходит
    echo "🚀 Запуск rsync переноса..."
    echo "📂 Из: $source"
    echo "📂 В:  $target"
    echo "--------------------------------"

    # Сама команда с твоими ключами
    rsync -avP \
        --no-o --no-g --no-p --no-t \
        --size-only \
        --remove-source-files \
        $source $target
end
