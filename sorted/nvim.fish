function nvim  --description 'Wrapper for nvim to set SHELL to bash'
    # Запускаем nvim, принудительно сообщая ему, что оболочка — bash
    env SHELL=/bin/bash nvim $argv
end
