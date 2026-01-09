function sudo-switch-alias
    if test "$__sudo_using_rs" = "1"
        set -U __sudo_using_rs 0
        functions -e sudo
        echo "🔁 Переключено на оригинальный sudo (изменения применятся в новых окнах)"
    else
        set -U __sudo_using_rs 1
        function sudo
            command sudo-rs $argv
        end
        echo "🔁 Переключено на sudo-rs"
    end
end
