function update_all_git_repositories --description "Обновить все ветки во всех git-репозиториях. Использование: update_all_git_repositories [-q|--quiet] [путь] (по-умолчанию в ~/git) "
    # Парсим аргументы: ищем флаг -q или --quiet
    argparse 'q/quiet' -- $argv
    or return 1 # Прерываем, если передан неизвестный флаг

    # После argparse в $argv остаются только позиционные аргументы (путь)
    set -l base_dir $argv[1]

    # Если аргумент не передан (пустой), используем каталог по умолчанию
    if test -z "$base_dir"
        set base_dir ~/git
    end

    # Убираем слэш на конце, если он был передан (просто для красивого вывода путей)
    set base_dir (string replace -r '/$' '' "$base_dir")

    if not test -d "$base_dir"
        echo "Каталог $base_dir не найден."
        return 1
    end

    # Ищем только те каталоги, внутри которых есть .git
    for git_dir in "$base_dir"/*/.git
        set -l repo_dir (dirname "$git_dir")
        echo -e "\n\033[1;34m===> Обновление репозитория: $repo_dir\033[0m"
        
        # Переходим в директорию репозитория (подавляем вывод pushd)
        pushd "$repo_dir" > /dev/null

        # Скачиваем все изменения со всех удаленных серверов и удаляем ссылки на удаленные ветки
        git fetch --all --prune --quiet

        set -l current_branch (git branch --show-current)

        # Проходим по всем локальным веткам
        for branch in (git for-each-ref refs/heads/ --format="%(refname:short)")
            # Проверяем, есть ли у ветки upstream (например, origin/main)
            set -l upstream (git for-each-ref refs/heads/$branch --format="%(upstream:short)")

            if test -n "$upstream"
                # Если передан флаг --quiet (или -q), делаем "как раньше"
                if set -q _flag_quiet
                    if test "$branch" = "$current_branch"
                        echo "  -> Активная ветка [$branch]: попытка fast-forward..."
                        git pull --ff-only --quiet
                    else
                        echo "  -> Фоновая ветка [$branch]: попытка fast-forward из $upstream..."
                        git fetch . $upstream:$branch 2>/dev/null
                        
                        if test $status -ne 0
                            echo "  [!] Не удалось обновить $branch (возможно, ветки разошлись)"
                        end
                    end
                else
                    # Подробный режим: проверяем хэши и выводим статус
                    set -l local_hash (git rev-parse $branch)
                    set -l upstream_hash (git rev-parse $upstream)

                    if test "$local_hash" = "$upstream_hash"
                        echo "  -> Ветка [$branch]: уже актуальна."
                    else
                        if test "$branch" = "$current_branch"
                            echo -n "  -> Активная ветка [$branch]: "
                            git pull --ff-only --quiet
                            if test $status -eq 0
                                echo -e "\033[0;32mуспешно обновлена (fast-forward)\033[0m"
                            else
                                echo -e "\033[0;31m[!] ошибка (вероятно, конфликтуют локальные изменения)\033[0m"
                            end
                        else
                            echo -n "  -> Фоновая ветка [$branch]: "
                            git fetch . $upstream:$branch 2>/dev/null
                            if test $status -eq 0
                                echo -e "\033[0;32mуспешно обновлена из $upstream\033[0m"
                            else
                                echo -e "\033[0;31m[!] ошибка (возможно, ветки разошлись)\033[0m"
                            end
                        end
                    end
                end
            else
                echo "  -> Ветка [$branch]: пропущена (нет upstream)."
            end
        end

        # Возвращаемся обратно
        popd > /dev/null
    end

    echo -e "\n\033[1;32mГотово! Все репозитории в каталоге $base_dir обработаны.\033[0m"
end
