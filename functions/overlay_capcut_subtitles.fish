function overlay_capcut_subtitles --description "Адаптивное наложение субтитров в стиле CapCut (красивые эффекты и стили)"
    argparse 'i/input=' 's/subtitles=' 'o/output=' 'f/font=' 'size=' 'style=' 'anim=' 'split' 'split-words=' 'split-chars=' 'margin=' 'h/help' -- $argv
    or return 1

    if set -q _flag_help; or not set -q _flag_input; or not set -q _flag_subtitles
        echo "Использование: overlay_capcut_subtitles -i <видео.mp4> -s <сабы.srt> [опции]"
        echo ""
        echo "Параметры:"
        echo "  -i, --input          Исходное видео"
        echo "  -s, --subtitles      Файл субтитров (srt)"
        echo "  -o, --output         Сохранить как (по умолчанию: subbed_<имя>)"
        echo "  -f, --font           Шрифт (по умолчанию: Montserrat, если установлен, иначе Arial)"
        echo "  --size               Размер шрифта (% от ширины, по умолчанию: 8)"
        echo "  --style              Стиль субтитров (по умолчанию: yellow-outline)"
        echo "                       Варианты: yellow-outline, white-outline, green-outline,"
        echo "                                 black-yellow-box, white-black-box, cyan-glow, pink-glow"
        echo "  --anim               Эффект появления (по умолчанию: pop)"
        echo "                       Варианты: pop, bounce, slideup, fade, none"
        echo "  --split              Разбивать длинные субтитры на короткие фразы (стиль Reels/Shorts)"
        echo "  --split-words        Макс. слов при разбивке (по умолчанию: 3)"
        echo "  --split-chars        Макс. символов при разбивке (по умолчанию: 18)"
        echo "  --margin             Вертикальный отступ от низа в % (по умолчанию: 15)"
        return 0
    end

    set -l input_video $_flag_input
    set -l input_subs $_flag_subtitles
    set -l output_video "subbed_"(basename $input_video)
    if set -q _flag_output
        set output_video $_flag_output
    end

    # Умный выбор шрифта по умолчанию (Montserrat -> Impact -> Arial)
    set -l font "Arial"
    if fc-list : family | grep -q -i "Montserrat"
        set font "Montserrat"
    else if fc-list : family | grep -q -i "Impact"
        set font "Impact"
    end
    if set -q _flag_font
        set font $_flag_font
    end

    set -l style_preset "yellow-outline"
    if set -q _flag_style
        set style_preset $_flag_style
    end

    set -l anim_preset "pop"
    if set -q _flag_anim
        set anim_preset $_flag_anim
    end

    set -l margin_percent 15
    if set -q _flag_margin
        set margin_percent $_flag_margin
    end

    # 1. Точно определяем разрешение видео
    set -l video_width (ffprobe -v error -select_streams v:0 -show_entries stream=width -of csv=s=x:p=0 $input_video)
    set -l video_height (ffprobe -v error -select_streams v:0 -show_entries stream=height -of csv=s=x:p=0 $input_video)

    if test -z "$video_width"
        echo "Ошибка: не удалось определить разрешение видео."
        return 1
    end

    # 2. Динамическая математика для ЛЮБОГО разрешения
    set -l size_percent 0.08
    if set -q _flag_size
        set size_percent (math "$_flag_size / 100")
    end
    
    set -l calc_font_size (math -s0 "$video_width * $size_percent")
    set -l calc_margin_v (math -s0 "$video_height * $margin_percent / 100")

    echo "=> Разрешение видео: $video_width x $video_height"
    echo "=> Шрифт: $font | Размер: $calc_font_size px | Отступ: $calc_margin_v px"
    echo "=> Стиль: $style_preset | Анимация: $anim_preset"

    # Встроенный Python-скрипт обработки субтитров с подсветкой синтаксиса в IDE
    # language=python
    # tree-sitter: language=python
    set -l python_code 'import sys
import os
import re
import argparse
from datetime import datetime, timedelta

def parse_time(time_str):
    h, m, s = time_str.split(":")
    s, ms = s.split(",")
    return timedelta(hours=int(h), minutes=int(m), seconds=int(s), milliseconds=int(ms))

def format_time(td):
    total_seconds = int(td.total_seconds())
    hours = total_seconds // 3600
    minutes = (total_seconds % 3600) // 60
    seconds = total_seconds % 60
    milliseconds = int(td.microseconds / 1000)
    return f"{hours:02d}:{minutes:02d}:{seconds:02d},{milliseconds:03d}"

def split_srt(input_path, output_path, max_words=3, max_chars=18):
    if not os.path.exists(input_path):
        print(f"Error: Input SRT file {input_path} not found.")
        sys.exit(1)
        
    with open(input_path, "r", encoding="utf-8", errors="ignore") as f:
        content = f.read()
    
    blocks = re.findall(r"(\d+)\n(\d{2}:\d{2}:\d{2},\d{3}) --> (\d{2}:\d{2}:\d{2},\d{3})\n((?:[^\n]+\n*)+)", content)
    
    if not blocks:
        blocks = re.findall(r"(\d+)\r?\n(\d{2}:\d{2}:\d{2},\d{3}) --> (\d{2}:\d{2}:\d{2},\d{3})\r?\n((?:[^\r\n]+\r?\n*)+)", content)

    new_blocks = []
    block_counter = 1
    
    for num, start_str, end_str, text_block in blocks:
        lines = [l.strip() for l in text_block.strip().split("\n") if l.strip()]
        text = " ".join(lines)
        words = text.split()
        
        if not words:
            continue
            
        start_td = parse_time(start_str)
        end_td = parse_time(end_str)
        total_duration = end_td - start_td
        
        chunks = []
        current_chunk = []
        current_char_count = 0
        
        for word in words:
            if len(current_chunk) >= max_words or (current_chunk and current_char_count + 1 + len(word) > max_chars):
                chunks.append(current_chunk)
                current_chunk = [word]
                current_char_count = len(word)
            else:
                current_chunk.append(word)
                current_char_count += (1 if current_chunk else 0) + len(word)
        if current_chunk:
            chunks.append(current_chunk)
            
        num_chunks = len(chunks)
        if num_chunks == 1:
            new_blocks.append((block_counter, start_str, end_str, " ".join(chunks[0])))
            block_counter += 1
        else:
            chunk_duration = total_duration / num_chunks
            for i, chunk in enumerate(chunks):
                chunk_start = start_td + chunk_duration * i
                chunk_end = start_td + chunk_duration * (i + 1)
                if i == num_chunks - 1:
                    chunk_end = end_td
                
                new_blocks.append((
                    block_counter,
                    format_time(chunk_start),
                    format_time(chunk_end),
                    " ".join(chunk)
                ))
                block_counter += 1
                
    with open(output_path, "w", encoding="utf-8") as f:
        for num, start, end, text in new_blocks:
            f.write(f"{num}\n{start} --> {end}\n{text}\n\n")

def make_ass(basic_ass, output_ass, args):
    if not os.path.exists(basic_ass):
        print(f"Error: Basic ASS file {basic_ass} not found.")
        sys.exit(1)

    styles_map = {
        "yellow-outline": {
            "primary": "&H0000FFFF",
            "secondary": "&H00000000",
            "outline_col": "&H00000000",
            "back_col": "&H00000000",
            "border_style": 1,
            "outline_factor": 0.09,
            "shadow_factor": 0.04
        },
        "white-outline": {
            "primary": "&H00FFFFFF",
            "secondary": "&H00000000",
            "outline_col": "&H00000000",
            "back_col": "&H00000000",
            "border_style": 1,
            "outline_factor": 0.09,
            "shadow_factor": 0.04
        },
        "black-yellow-box": {
            "primary": "&H00000000",
            "secondary": "&H00000000",
            "outline_col": "&H0000FFFF",
            "back_col": "&H0000FFFF",
            "border_style": 3,
            "outline_factor": 0.18,
            "shadow_factor": 0.0
        },
        "white-black-box": {
            "primary": "&H00FFFFFF",
            "secondary": "&H00000000",
            "outline_col": "&HB0000000",
            "back_col": "&HB0000000",
            "border_style": 3,
            "outline_factor": 0.18,
            "shadow_factor": 0.0
        },
        "green-outline": {
            "primary": "&H0000FF00",
            "secondary": "&H00000000",
            "outline_col": "&H00000000",
            "back_col": "&H00000000",
            "border_style": 1,
            "outline_factor": 0.09,
            "shadow_factor": 0.04
        },
        "cyan-glow": {
            "primary": "&H00FFFFFF",
            "secondary": "&H00000000",
            "outline_col": "&H00FFFF00",
            "back_col": "&H00FFFF00",
            "border_style": 1,
            "outline_factor": 0.05,
            "shadow_factor": 0.15
        },
        "pink-glow": {
            "primary": "&H00FFFFFF",
            "secondary": "&H00000000",
            "outline_col": "&H00FF00FF",
            "back_col": "&H00FF00FF",
            "border_style": 1,
            "outline_factor": 0.05,
            "shadow_factor": 0.15
        }
    }

    style_cfg = styles_map.get(args.style_preset, styles_map["yellow-outline"])
    
    font_size = args.font_size
    outline_px = round(font_size * style_cfg["outline_factor"], 1)
    shadow_px = round(font_size * style_cfg["shadow_factor"], 1)
    
    anim_preset = args.anim_preset
    anim_tags = ""
    
    if anim_preset == "pop":
        anim_tags = r"{\fscx60\fscy60\t(0,120,\fscx100\fscy100)}"
    elif anim_preset == "bounce":
        anim_tags = r"{\fscx50\fscy50\t(0,100,\fscx115\fscy115)\t(100,180,\fscx100\fscy100)}"
    elif anim_preset == "slideup":
        x_coord = args.video_width // 2
        y_end = args.video_height - args.margin_v
        y_start = y_end + int(font_size * 0.4)
        anim_tags = rf"{{\fad(100,0)\move({x_coord},{y_start},{x_coord},{y_end},0,150)}}"
    elif anim_preset == "fade":
        anim_tags = r"{\fad(150,150)}"

    with open(basic_ass, "r", encoding="utf-8", errors="ignore") as f:
        basic_content = f.read()

    dialogue_lines = []
    for line in basic_content.splitlines():
        if line.startswith("Dialogue:"):
            parts = line.split(",", 9)
            if len(parts) == 10:
                layer = parts[0].split(":")[1].strip()
                start_time = parts[1].strip()
                end_time = parts[2].strip()
                style_name = "Default"
                speaker = parts[4].strip()
                margin_l = parts[5].strip()
                margin_r = parts[6].strip()
                margin_v = parts[7].strip()
                effect = parts[8].strip()
                text = parts[9].strip()
                
                new_text = anim_tags + text
                
                reconstructed_line = f"Dialogue: {layer},{start_time},{end_time},{style_name},{speaker},{margin_l},{margin_r},{margin_v},{effect},{new_text}"
                dialogue_lines.append(reconstructed_line)

    primary_color = style_cfg["primary"]
    secondary_color = style_cfg["secondary"]
    outline_color = style_cfg["outline_col"]
    back_color = style_cfg["back_col"]
    border_style = style_cfg["border_style"]

    with open(output_ass, "w", encoding="utf-8") as f:
        f.write("[Script Info]\n")
        f.write("ScriptType: v4.00+\n")
        f.write(f"PlayResX: {args.video_width}\n")
        f.write(f"PlayResY: {args.video_height}\n")
        f.write("ScaledBorderAndShadow: yes\n\n")
        
        f.write("[V4+ Styles]\n")
        f.write("Format: Name, Fontname, Fontsize, PrimaryColour, SecondaryColour, OutlineColour, BackColour, Bold, Italic, Underline, StrikeOut, ScaleX, ScaleY, Spacing, Angle, BorderStyle, Outline, Shadow, Alignment, MarginL, MarginR, MarginV, Encoding\n")
        f.write(f"Style: Default,{args.font},{font_size},{primary_color},{secondary_color},{outline_color},{back_color},-1,0,0,0,100,100,0,0,{border_style},{outline_px},{shadow_px},2,10,10,{args.margin_v},1\n\n")
        
        f.write("[Events]\n")
        f.write("Format: Layer, Start, End, Style, Name, MarginL, MarginR, MarginV, Effect, Text\n")
        for d_line in dialogue_lines:
            f.write(d_line + "\n")

if __name__ == "__main__":
    parser = argparse.ArgumentParser(description="CapCut Subtitles Helper")
    parser.add_argument("--action", choices=["split-srt", "make-ass"], required=True)
    parser.add_argument("--input-srt", type=str)
    parser.add_argument("--output-srt", type=str)
    parser.add_argument("--max-words", type=int, default=3)
    parser.add_argument("--max-chars", type=int, default=18)
    parser.add_argument("--basic-ass", type=str)
    parser.add_argument("--output-ass", type=str)
    parser.add_argument("--video-width", type=int)
    parser.add_argument("--video-height", type=int)
    parser.add_argument("--font", type=str, default="Arial")
    parser.add_argument("--font-size", type=int)
    parser.add_argument("--style-preset", type=str, default="yellow-outline")
    parser.add_argument("--anim-preset", type=str, default="pop")
    parser.add_argument("--margin-v", type=int)

    args = parser.parse_args()

    if args.action == "split-srt":
        split_srt(args.input_srt, args.output_srt, args.max_words, args.max_chars)
    elif args.action == "make-ass":
        make_ass(args.basic_ass, args.output_ass, args)
'

    # 3. Временные файлы
    set -l tmp_py (mktemp --suffix=.py)
    set -l tmp_ass (mktemp --suffix=.ass)
    set -l tmp_srt_ass (mktemp --suffix=.ass)
    set -l processed_srt $input_subs

    # Записываем встроенный Python-скрипт во временный файл
    printf "%s\n" $python_code > $tmp_py

    # Если включен split, запускаем разбиение SRT для динамичного темпа
    if set -q _flag_split
        set -l split_words 3
        if set -q _flag_split_words
            set split_words $_flag_split_words
        end
        set -l split_chars 18
        if set -q _flag_split_chars
            set split_chars $_flag_split_chars
        end

        echo "=> Динамическая разбивка текста субтитров (макс. слов: $split_words)..."
        set processed_srt (mktemp --suffix=.srt)
        python3 $tmp_py --action split-srt \
            --input-srt $input_subs \
            --output-srt $processed_srt \
            --max-words $split_words \
            --max-chars $split_chars
    end

    # Конвертируем SRT в базовый ASS, чтобы ffmpeg сам разобрался с таймкодами
    ffmpeg -v error -y -i $processed_srt $tmp_srt_ass

    # Стилизуем и анимируем ASS файл с помощью нашего python-хелпера
    python3 $tmp_py --action make-ass \
        --basic-ass $tmp_srt_ass \
        --output-ass $tmp_ass \
        --video-width $video_width \
        --video-height $video_height \
        --font "$font" \
        --font-size $calc_font_size \
        --style-preset "$style_preset" \
        --anim-preset "$anim_preset" \
        --margin-v $calc_margin_v

    # 4. Экранируем путь к временному файлу для ass-фильтра
    set -l escaped_ass (string replace -a ':' '\\:' $tmp_ass | string replace -a "'" "\\'")

    echo "=> Рендеринг видео с эффектами..."
    ffmpeg -y -i $input_video -vf "ass='$escaped_ass'" -c:v libx264 -preset fast -crf 23 -c:a copy $output_video

    # 5. Очистка временных файлов
    rm -f $tmp_ass $tmp_srt_ass $tmp_py
    if set -q _flag_split
        rm -f $processed_srt
    end
    echo "=> Готово! Результат сохранен в: $output_video"
end
