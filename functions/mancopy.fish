function mancopy --description "Скопировать содержимое man в буфер обмена"
    if set -q WAYLAND_DISPLAY
        man $argv | col -b | wl-copy
    else if set -q DISPLAY
        man $argv | col -b | xsel -b
    else
        echo "Не удалось определить графическое окружение (X11 или Wayland)"
        return 1
    end
end
