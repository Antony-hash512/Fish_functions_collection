function record_system_audio --description "Запись системного звука с интерактивным выбором устройства"
    # Получаем список всех доступных мониторов (только их имена)
    set -l monitors (pactl list short sources | grep monitor | awk '{print $2}')
    
    if test -z "$monitors"
        echo "Ошибка: Не найдено устройств для записи (мониторов)."
        return 1
    end

    # Предлагаем выбрать устройство через fzf
    set -l selected_monitor (printf "%s\n" $monitors | fzf --prompt="Выбери устройство для записи > " --height=10 --layout=reverse)
    
    # Если нажали Esc и ничего не выбрали — прерываем выполнение
    if test -z "$selected_monitor"
        echo "Отмена."
        return 0
    end

    # Формируем имя файла
    set -l output_file $argv[1]
    if test -z "$output_file"
        set output_file "system_audio_"(date +"%Y-%m-%d_%H-%M-%S")".wav"
    end

    echo "▶ Начинаю запись с устройства: $selected_monitor"
    echo "  Файл: $output_file"
    echo "  (Нажми Ctrl+C для остановки записи)"
    
    # Запускаем запись
    parecord --device=$selected_monitor $output_file
end
