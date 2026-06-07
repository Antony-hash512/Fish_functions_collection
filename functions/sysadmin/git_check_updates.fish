function git_check_updates --description 'Show visual git history for all local and remote branches'
    # Сначала забираем изменения из всех ремоутов без мерджа
    git fetch --all --quiet
    
    # Выводим красивое дерево коммитов
    # %h - короткий хеш, %ar - относительное время, %s - сообщение, %d - декорации (ветки)
    git log --graph --pretty=format:'%C(yellow)%h%Creset -%C(auto)%d%Creset %s %Cgreen(%ar) %C(bold blue)<%an>%Creset' --all -n 25
end
