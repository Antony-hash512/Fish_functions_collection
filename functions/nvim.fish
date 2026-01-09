function nvim
    # Запускаем nvim, принудительно сообщая ему, что оболочка — bash
    env SHELL=/bin/bash nvim $argv
end
