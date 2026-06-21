function yt-dl-manager --description 'Менеджер скачивания Shorts (create-index / dl-missed / auto-dl-missed)'
    switch $argv[1]
        case create-index
            echo "🔄 Создаём/обновляем downloaded.txt из файлов в папке..."
            fd -e webm -e mp4 -d 1 | sed -E 's/.*\[([A-Za-z0-9_-]{11})\].*/\1/' | sort -u > downloaded.txt
            echo "✅ Готово! В архиве:" (wc -l < downloaded.txt) "видео"

        case dl-missed
            echo "🔍 Ищем недостающие Shorts..."
            yt-dlp --flat-playlist --print id "https://www.youtube.com/@SimonSkrepecki" | sort > /tmp/current.txt
            sort downloaded.txt > /tmp/downloaded_sorted.txt
            comm -23 /tmp/current.txt /tmp/downloaded_sorted.txt > missing.txt
            rm -f /tmp/current.txt /tmp/downloaded_sorted.txt

            set count (wc -l < missing.txt)
            echo "📊 Найдено недостающих: $count"

            if test $count -gt 0
                echo "⬇️  Начинаю скачивание только недостающих..."
                yt-dlp --download-archive downloaded.txt --cookies-from-browser firefox --flat-playlist -a missing.txt
            else
                echo "🎉 Всё уже скачано!"
            end

        case auto-dl-missed
            echo "🚀 Запуск полного цикла: create-index + dl-missed"
            yt-dl-manager create-index
            yt-dl-manager dl-missed

        case '*'
            echo "Использование:"
            echo "   yt-dl-manager create-index     → обновить archive из файлов"
            echo "   yt-dl-manager dl-missed        → скачать только недостающие"
            echo "   yt-dl-manager auto-dl-missed   → сделать оба шага сразу"
    end
end
