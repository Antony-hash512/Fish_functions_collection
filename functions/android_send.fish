function android_send --description "Интерактивная отправка файлов на Android через ADB"
    # Проверка зависимостей
    if not command -q adb; echo "Ошибка: adb не найден."; return 1; end
    if not command -q fzf; echo "Ошибка: fzf не найден."; return 1; end

    # Проверка устройства
    set -l device_state (adb get-state 2>/dev/null)
    if test "$device_state" != "device"
        echo "Ошибка: Устройство не подключено."
        return 1
    end

    # Файлы для отправки
    set -l source_files $argv
    if test (count $source_files) -eq 0
        set source_files "."
        echo "📂 Файлы не выбраны, отправляем содержимое текущей папки..."
    end

    echo "🔍 Сканирование хранилищ..."

    # 1. Поиск корней
    set -l storage_roots "/sdcard"
    # Используем кавычки для защиты wildcards
    set -l ext_sd (adb shell ls -d '/storage/*' 2>/dev/null | grep -E '/[0-9A-F]{4}-[0-9A-F]{4}$')
    
    if test -n "$ext_sd"
        set storage_roots $storage_roots $ext_sd
    end

    # 2. Формирование меню
    set -l menu_list
    set -l common_dirs Movies Download DCIM Pictures Music Documents

    for root in $storage_roots
        set -l label "Internal"
        if string match -q "/storage/*-*" $root
            set label "SD Card"
        end

        # --- Добавляем пункт для ввода своей папки ---
        # Формат: Метка -> CUSTOM:Путь_к_корню
        set menu_list $menu_list "$label: ✍️  Другая папка (ввести вручную)... -> CUSTOM:$root"
        
        # Стандартные папки
        set menu_list $menu_list "$label: Root ($root) -> $root/"
        for dir in $common_dirs
            set menu_list $menu_list "$label: $dir -> $root/$dir/"
        end
    end

    # 3. Выбор через fzf
    set -l selection (string join \n $menu_list | fzf --prompt="Куда копировать? > " --height=40% --layout=reverse --border)

    if test -z "$selection"
        echo "Отмена."
        return 0
    end

    # Разбираем выбор
    set -l parts (string split -- " -> " $selection)
    set -l raw_target $parts[2]
    set -l final_target ""

    # 4. Проверяем, выбрал ли пользователь ручной ввод
    if string match -q "CUSTOM:*" $raw_target
        # Извлекаем корень (всё после CUSTOM:)
        set -l root_dir (string split ":" $raw_target)[2]
        
        echo "Введите путь относительно $root_dir/"
        echo "(Например: 'Series/New' или просто 'MyFolder')"
        read -P "📁 > " custom_name
        
        if test -z "$custom_name"
            echo "Имя папки не введено. Отмена."
            return 1
        end
        
        # Убираем ведущий слэш, если пользователь его ввел случайно
        set -l clean_name (string trim --chars="/" $custom_name)
        set final_target "$root_dir/$clean_name/"
    else
        # Обычный выбор из списка
        set final_target $raw_target
    end

    # 5. Копирование
    echo "🚀 Отправка в: $final_target"
    adb push $source_files "$final_target"

    if test $status -eq 0
        echo "✅ Копирование завершено."
        
        echo "🔄 Обновление медиатеки Android..."
        if test (count $source_files) -eq 1 -a -f "$source_files[1]"
            set -l filename (basename "$source_files[1]")
            adb shell am broadcast -a android.intent.action.MEDIA_SCANNER_SCAN_FILE -d "file://$final_target$filename" > /dev/null 2>&1
        else
            adb shell am broadcast -a android.intent.action.MEDIA_SCANNER_SCAN_FILE -d "file://$final_target" > /dev/null 2>&1
        end
    else
        echo "❌ Ошибка при копировании."
    end
end
