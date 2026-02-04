function check_bin2 --description "Check if binary/package name exists in Arch repos or AUR"
    set -l bin_name $argv[1]

    if test -z "$bin_name"
        echo "Usage: check_bin <name>"
        return 1
    end

    # 1. Проверяем официальные репозитории (по файлу)
    echo "🔍 [1/3] Checking Official Repos for file 'usr/bin/$bin_name'..."
    set -l repo_file_result (pacman -F "usr/bin/$bin_name" 2>/dev/null)

    if test -n "$repo_file_result"
        set_color red
        echo "❌ BUSY: Binary exists in Official Repos:"
        set_color normal
        for line in $repo_file_result
             if string match -q "*/*" $line
                 echo "   -> $line"
             end
        end
    else
        set_color green
        echo "✅ FREE: No binary 'usr/bin/$bin_name' found in Official Repos"
        set_color normal
    end

    echo ""
    
    # 2. Проверяем Официальные репозитории (по имени пакета)
    # Иногда бинарника нет, но имя пакета занято (например, библиотеки или мета-пакеты)
    echo "🔍 [2/3] Checking Official Repos for package name '$bin_name'..."
    if pacman -Si "$bin_name" > /dev/null 2>&1
        set_color red
        echo "❌ BUSY: Package '$bin_name' already exists in Official Repos"
        set_color normal
    else
        set_color green
        echo "✅ FREE: Package name '$bin_name' is available in Official Repos"
        set_color normal
    end

    echo ""

    # 3. Проверяем AUR (по точному имени пакета)
    echo "🔍 [3/3] Checking AUR for package name '$bin_name'..."
    if type -q paru
        # Используем -Si. Если пакет есть, код возврата 0.
        if paru -Si "$bin_name" > /dev/null 2>&1
            set_color red
            echo "❌ BUSY: Package '$bin_name' already exists in AUR"
            set_color normal
            # Показываем краткую инфо
            paru -Si "$bin_name" | grep -E "Description|Version|URL" | sed 's/^/   -> /'
        else
            set_color green
            echo "✅ FREE: Package name '$bin_name' seems available in AUR"
            set_color normal
        end
    else
        echo "⚠️  paru/yay not found, skipping AUR check."
    end
end
