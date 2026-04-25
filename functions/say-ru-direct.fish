function say-ru-direct --description "Озвучить переданный текст или буфер обмена (Wayland/X11)"
    set -l text_to_say "$argv"

    if test -z "$text_to_say"
        if set -q WAYLAND_DISPLAY
            set text_to_say (wl-paste)
        else
            set text_to_say (xclip -o -selection clipboard 2>/dev/null)
        end
    end

    if test -z "$text_to_say"
        set text_to_say "Буфер обмена пустой, поэтому мне нечего сказать."
    end

    echo "▶ Читаю текст: $text_to_say"
    echo "  (Нажми Ctrl+C для остановки)"

    # Прямой вызов RHVoice-test
    #echo "$text_to_say" | RHVoice-test -p tatiana
    echo "$text_to_say" | RHVoice-test -p tatiana -v 190 -r 180
end
