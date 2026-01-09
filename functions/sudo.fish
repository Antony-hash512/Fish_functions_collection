function sudo --description "Обертка для sudo-rs с возможностью отключения через __sudo_using_rs"
    # --wraps позволяет автодополнению работать так же, как у обычного sudo
    
    # 1. Проверяем, установлен ли sudo-rs
    if command -q sudo-rs
        # Если переменная настройки еще не задана — включаем по умолчанию (1)
        if not set -q __sudo_using_rs
            set -U __sudo_using_rs 1
        end

        # Если флаг включен — передаем управление sudo-rs
        if test "$__sudo_using_rs" = "1"
            command sudo-rs $argv
            return
        end
    else
        # Если sudo-rs в системе нет, на всякий случай сбрасываем флаг в 0
        if set -q __sudo_using_rs
             set -U __sudo_using_rs 0
        end
    end

    # 2. Если мы дошли сюда, значит либо sudo-rs нет, либо он выключен флагом.
    # ВАЖНО: используем 'command sudo', чтобы вызвать бинарник, 
    # а не зациклить эту же функцию бесконечно.
    command sudo $argv
end
