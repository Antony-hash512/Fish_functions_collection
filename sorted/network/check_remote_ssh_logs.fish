function check_remote_ssh_logs --description "Проверка неудачных попыток входа по SSH на удаленном сервере"
    # Если аргумент не передан, по умолчанию подключаемся к alexhost
    set target_server $argv[1]
    if test -z "$target_server"
        set target_server "alexhost"
    end

    echo " Запрашиваю логи SSH за сегодня с сервера $target_server..."
    echo "---------------------------------------------------------"
    
    # Идем по SSH и фильтруем journalctl по неудачным попыткам и инвалидным юзерам
    ssh $target_server "journalctl -u sshd --since today | grep -iE 'Failed password|Invalid user|Connection closed by authenticating user'"
    
    echo "---------------------------------------------------------"
    echo " Проверка завершена."
end
