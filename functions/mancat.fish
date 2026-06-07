function mancat --description "Вывести содержимое man в терминал"
    man $argv | col -b
end
