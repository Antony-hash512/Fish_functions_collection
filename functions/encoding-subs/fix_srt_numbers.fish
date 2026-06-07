function fix_srt_numbers --description "Перенумеровывает и исправляет форматирование SRT файла через ffmpeg"
    if test (count $argv) -eq 0
        echo "Использование: fix_srt_numbers <input.srt> [output.srt]"
        return 1
    end

    set input_file $argv[1]
    set output_file $argv[2]

    # Если второй аргумент не передан, создаем файл с префиксом fixed_
    if test -z "$output_file"
        set output_file "fixed_$input_file"
    end

    ffmpeg -v error -y -i $input_file -c:s srt $output_file
    echo "Готово! Отформатированные субтитры сохранены в $output_file"
end
