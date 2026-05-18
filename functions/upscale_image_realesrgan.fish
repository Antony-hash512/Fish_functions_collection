function upscale_image_realesrgan -d "Upscale a single image using Real-ESRGAN with anime/photo modes"
    # Парсим флаги: -a/--anime и -p/--photo
    argparse 'a/anime' 'p/photo' 'h/help' -- $argv
    or return 1

    if set -ql _flag_help
        echo "Usage: upscale_image_realesrgan [-a|--anime] [-p|--photo] <input.jpg> <output.png>"
        return 0
    end

    # Позиционные аргументы (остаются после парсинга флагов)
    set -l input_file $argv[1]
    set -l output_file $argv[2]
    
    if test -z "$input_file"; or test -z "$output_file"
        echo "Error: Missing input or output file."
        echo "Usage: upscale_image_realesrgan [-a|--anime] [-p|--photo] <input.jpg> <output.png>"
        return 1
    end

    # Выбираем модель (по умолчанию ставим photo)
    set -l model_name "realesrgan-x4plus"
    
    if set -ql _flag_anime
        echo "Модель: Аниме (realesrgan-x4plus-anime)"
        set model_name "realesrgan-x4plus-anime"
    else if set -ql _flag_photo
        echo "Модель: Фото (realesrgan-x4plus)"
        set model_name "realesrgan-x4plus"
    else
        echo "Модель не указана, используем по умолчанию: Фото (realesrgan-x4plus)"
    end

    echo "Запуск RealESRGAN на Vulkan..."
    # Пробрасываем переменную $model_name во флаг -n
    realesrgan-ncnn-vulkan -i $input_file -o $output_file -n $model_name -s 4

    echo "Подгоняем размер под 1056x1872 для ComfyUI..."
    magick $output_file -resize 1056x1872\! $output_file
    
    echo "Готово! Кадр можно грузить в ноду."
end
