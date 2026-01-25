function squash_manager --description "Smartly manage SquashFS: create (optional encryption), mount, and umount"
    # Аргументы для создания/шифрования
    argparse 'c/compression=!_validate_int' 'no-progress' 'e/encrypt' 'h/help' -- $argv
    or return 1

    set -l action $argv[1]
    set -l root_cmd (functions -q get_root_cmd; and get_root_cmd; or echo "sudo")

    # --- СПРАВКА ---
    if set -q _flag_help; or test (count $argv) -eq 0
        echo "Usage: squash_manager create [OPTIONS] <input_path> [output_path]"
        echo "       squash_manager mount <image> <mount_point>"
        echo "       squash_manager umount <mount_point>"
        echo ""
        echo "Options for 'create':"
        echo "  -e, --encrypt         Create an encrypted LUKS container (Secure FIFO stream)"
        echo "  -c, --compression=N   Zstd compression level (default: 15)"
        echo "  --no-progress         Disable progress bar"
        echo ""
        echo "Description:"
        echo "  Converts a directory OR an archive (tar.zst, zip, 7z, etc.) into SquashFS."
        echo "  With -e, it creates a LUKS container and streams data without cleartext on disk."
        return 0
    end

    switch "$action"
        case mount
            set -l img $argv[2]
            set -l mnt $argv[3]
            if test -z "$img"; or test -z "$mnt"
                echo "Error: Usage: squash_manager mount <image> <mount_point>"
                return 1
            end

            set -l mapper_name "sq_"(string replace -a (string escape --style=regex ".") "_" (basename $img))
            mkdir -p $mnt

            if $root_cmd cryptsetup isLuks $img 2>/dev/null
                echo "Opening encrypted container..."
                $root_cmd cryptsetup open $img $mapper_name; and $root_cmd mount /dev/mapper/$mapper_name $mnt
            else
                echo "Mounting standard SquashFS..."
                $root_cmd mount -o loop $img $mnt
            end
            echo "Mounted at $mnt"
            return 0

        case umount
            set -l mnt $argv[2]
            if test -z "$mnt"
                echo "Error: Usage: squash_manager umount <mount_point>"
                return 1
            end

            set -l dev ($root_cmd findmnt -n -o SOURCE $mnt)
            echo "Unmounting $mnt..."
            $root_cmd umount $mnt

            if string match -q "/dev/mapper/sq_*" "$dev"
                set -l mapper_name (basename $dev)
                echo "Closing LUKS container $mapper_name..."
                $root_cmd cryptsetup close $mapper_name
            end

            rmdir $mnt 2>/dev/null
            echo "Done."
            return 0

        case create
            set -l input_path $argv[2]
            set -l output_path $argv[3]
            if test -z "$input_path"
                echo "Error: Input path required."
                return 1
            end

            if test -z "$output_path"
                set -l clean_name (string trim -r -c / $input_path)
                set clean_name (string replace -r '\.(tar\.zst|tar\.gz|tgz|tar\.xz|txz|tar\.bz2|tbz|tar|7z|zip|rar)$' '' $clean_name)
                set output_path "$clean_name.squashfs"
            end

            set -l comp_level (set -q _flag_compression; and echo $_flag_compression; or echo 15)

            # Определение декомпрессора
            set -l decompress_cmd
            if not test -d $input_path
                switch $input_path
                    case '*.tar.zst' '*.tzst'; set decompress_cmd zstd -dcf
                    case '*.tar.gz' '*.tgz'; set decompress_cmd gzip -dcf
                    case '*.tar.xz' '*.txz'; set decompress_cmd xz -dcf
                    case '*.tar.bz2' '*.tbz'; set decompress_cmd bzip2 -dcf
                    case '*.tar'; set decompress_cmd cat
                    case '*.7z' '*.zip' '*.rar' '*.iso'
                        type -q bsdtar; or begin; echo "Error: bsdtar required"; return 1; end
                        set decompress_cmd bsdtar -c -f - --format=tar "@-"
                    case '*'; echo "Error: Unknown format"; return 1; end
            end

            if set -q _flag_encrypt
                # --- ЛОГИКА С ШИФРОВАНИЕМ (FIFO) ---
                set -l raw_size (test -d $input_path; and du -sb $input_path | cut -f1; or stat -c %s $input_path)
                set -l container_size (math -s0 "$raw_size / 1024 / 1024 + ($raw_size / 1024 / 1024 / 10) + 32")

                # Проверка места
                set -l free_space (df -m . | tail -1 | awk '{print $4}')
                if test $container_size -gt $free_space
                    echo "Error: Not enough space. Need $container_size MB, but only $free_space MB available."
                    return 1
                end

                echo "Preparing encrypted stream ($container_size MB)..."
                dd if=/dev/zero of=$output_path bs=1M count=$container_size status=progress

                # Очистка при опечатке в YES
                if not $root_cmd cryptsetup luksFormat $output_path
                    echo "Operation aborted. Removing empty container..."
                    rm $output_path
                    return 1
                end

                set -l tmp_map "sq_v_"(random)
                if $root_cmd cryptsetup open $output_path $tmp_map
                    set -l fifo "/tmp/sq_p_"(random)
                    mkfifo $fifo

                    # Твой патч с pv и cat
                    if type -q pv; and not set -q _flag_no_progress
                        $root_cmd fish -c "cat $fifo | pv -peta -s $raw_size | dd of=/dev/mapper/$tmp_map bs=1M status=none" &
                    else
                        $root_cmd fish -c "cat $fifo | dd of=/dev/mapper/$tmp_map bs=1M status=progress" &
                    end
                    set -l dd_pid $last_pid
                    sleep 1 

                    echo "Packing data (Zstd $comp_level)... This may take a while."
                    if test -d $input_path
                        # Убрал ошибочный -f и добавил логику подавления лишнего текста
                        mksquashfs $input_path $fifo -comp zstd -Xcompression-level $comp_level -b 1M -no-recovery -noappend
                    else
                        # Для tar2sqfs флаг --force (-f) остается, он там нужен
                        set -l source_cmd (type -q pv; and not set -q _flag_no_progress; and echo "pv $input_path"; or echo "cat $input_path")
                        fish -c "$source_cmd | $decompress_cmd | tar2sqfs -c zstd -X level=$comp_level -b 1M --force -o $fifo"
                    end

                    wait $dd_pid
                    $root_cmd cryptsetup close $tmp_map
                    rm $fifo
                else
                    rm $output_path
                    return 1
                end
            else
                # --- ОБЫЧНОЕ СОЗДАНИЕ ---
                if test -d $input_path
                    set -l mk_opts -comp zstd -Xcompression-level $comp_level -b 1M -no-recovery
                    set -q _flag_no_progress; and set mk_opts $mk_opts -quiet; or set mk_opts $mk_opts -info
                    mksquashfs $input_path $output_path $mk_opts
                else
                    set -l source_cmd (type -q pv; and not set -q _flag_no_progress; and echo "pv $input_path"; or echo "cat $input_path")
                    fish -c "$source_cmd | $decompress_cmd | tar2sqfs -c zstd -X level=$comp_level -b 1M --force -o $output_path"
                end
            end

            if test $status -eq 0
                set_color green; echo "Success: $output_path"; set_color normal
                ls -lh $output_path
            end

        case '*'
            echo "Error: Unknown command '$action'. Available: create, mount, umount."
            return 1
    end
end
