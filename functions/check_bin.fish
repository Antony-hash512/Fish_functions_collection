function check_bin --description "Check if binary name exists in Arch repos or AUR"
    set -l bin_name $argv[1]

    if test -z "$bin_name"
        echo "Usage: check_bin <binary_name>"
        return 1
    end

    echo "🔍 Checking official repositories for 'usr/bin/$bin_name'..."
    # Используем -F с точным путем usr/bin/
    # 2>/dev/null скрывает ошибки, если база не найдена (но лучше держать её обновленной через pacman -Fy)
    set -l repo_result (pacman -F "usr/bin/$bin_name" 2>/dev/null)

    if test -n "$repo_result"
        set_color red
        echo "❌ BUSY in Official Repos:"
        set_color normal
        # Выводим только строки с именем пакета и веткой (core/extra)
        for line in $repo_result
             # Простая фильтрация вывода pacman -F, чтобы показать пакет
             if string match -q "*/*" $line
                 echo "   -> $line"
             end
        end
    else
        set_color green
        echo "✅ FREE in Official Repos (usr/bin/$bin_name not found)"
        set_color normal
    end

    echo ""
    echo "🔍 Checking AUR for package names containing '$bin_name'..."
    # Поиск в AUR через paru (или yay, если paru нет)
    if type -q paru
        paru -Ss -q "$bin_name" | grep -iE "^aur/$bin_name "
    else if type -q yay
        yay -Ss -q "$bin_name" | grep -iE "^aur/$bin_name "
    else
        echo "⚠️  AUR helper (paru/yay) not found, skipping AUR check."
    end
    
    # Для AUR мы просто показываем grep, если вывод пустой — значит чисто.
    if test $status -eq 0
         set_color red
         echo "⚠️  Found matches in AUR (see above)"
         set_color normal
    else
         set_color green
         echo "✅ No exact package match in AUR found"
         set_color normal
    end
end
