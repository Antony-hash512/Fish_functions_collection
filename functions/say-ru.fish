function say-ru --description "Озвучить переданный текст или буфер обмена (Wayland/X11)"
    set -l text_to_say "$argv"

    # Если аргументов нет, берем текст из буфера обмена
    if test -z "$text_to_say"
        if set -q WAYLAND_DISPLAY
            # Работаем в Wayland
            set text_to_say (wl-paste)
        else
            # Работаем в X11 (или Xwayland)
            set text_to_say (xclip -o -selection clipboard 2>/dev/null)
        end
    end

    # Если буфер тоже оказался пустым
    if test -z "$text_to_say"
        set text_to_say "Буфер обмена пустой, поэтому мне нечего сказать."
    end

    # Выводим текст в терминал
    echo "$text_to_say"

    # Запускаем озвучку (-w означает ожидание завершения)
    spd-say -l ru -w -y tatiana -r +50 "$text_to_say"
end
