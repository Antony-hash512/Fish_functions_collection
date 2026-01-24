function test_ssh_speed
    # Проверяем наличие pv, так как это ключевая часть пайплайна
    if not type -q pv
        echo "Ошибка: утилита 'pv' не найдена. Установите её (sudo pacman -S pv)."
        return 1
    end

    # Передаем все аргументы ($argv) команде ssh
    yes | pv | ssh $argv "cat >/dev/null"
end
