function pass --description "Smart Pass: Auto-pull on modify + Vim editor"
    # 1. Список команд, которые меняют данные
    # (при вызове этих команд мы будем принудительно синхронизироваться)
    set -l modify_cmds insert edit rm mv cp generate init git

    # 2. Определяем подкоманду (первый аргумент)
    set -l subcommand $argv[1]

    # 3. Если команда меняющая — делаем Pull
    if contains -- $subcommand $modify_cmds
        echo "🔄 Syncing incoming changes from NAS..."
        
        # -C указывает git'у, в какой папке работать, не меняя текущую директорию
        # --rebase: ВАЖНО! Перестраивает историю, чтобы избежать лишних merge-коммитов
        # --autostash: Прячет твои локальные изменения, если они есть, и возвращает их после пулла
        git -C ~/.password-store pull --rebase --autostash -q origin master
        
        if test $status -ne 0
            echo "⚠️  Warning: Pull failed (Offline?). Proceeding with local version."
        else
            echo "✅ Synced."
        end
    end

    # 4. Настройка редактора (Vim для edit)
    if contains -- $subcommand edit
        set -lx EDITOR vim
        set -lx VISUAL vim
    end

    # 5. Выполнение самой команды pass
    EDITOR=vim VISUAL=vim command pass $argv
end
