function squash_manager6 --description "Ultimate SquashFS manager: Supports RAM-build for max speed + Encryption"
    argparse 'c/compression=!_validate_int' 'no-progress' 'e/encrypt' 'ram-cache=!_validate_int' 'h/help' -- $argv
    or return 1

    set -l action $argv[1]
    set -l root_cmd (functions -q get_root_cmd; and get_root_cmd; or echo "sudo")

    if set -q _flag_help; or test (count $argv) -eq 0
        echo "Usage: squash_manager6 create [OPTIONS] <input_path> [output_path]"
        echo "       squash_manager6 mount <image> <mount_point>"
        echo "       squash_manager6 umount <mount_point>"
        echo ""
        echo "Options:"
        echo "  -e, --encrypt       Encrypt output (LUKS)"
        echo "  --ram-cache=GB      Build in RAM (tmpfs) of this size (e.g. --ram-cache 8)"
        echo "                      Faster, prevents I/O errors. Requires free RAM."
        return 0
    end

    switch "$action"
        case mount
            set -l img $argv[2]
            set -l mnt $argv[3]
            test -z "$img"; or test -z "$mnt"; and begin; echo "Error: Need image and mountpoint"; return 1; end
            set -l mapper_name "sq_"(string replace -a (string escape --style=regex ".") "_" (basename $img))
            mkdir -p $mnt

            if $root_cmd cryptsetup isLuks $img 2>/dev/null
                if test -e /dev/mapper/$mapper_name
                    $root_cmd mount -t squashfs /dev/mapper/$mapper_name $mnt 2>/dev/null; and begin; echo "Mounted at $mnt"; return 0; end
                    $root_cmd cryptsetup close $mapper_name
                end
                echo "Opening encrypted container..."
                $root_cmd cryptsetup open $img $mapper_name; or return 1
                if $root_cmd mount -t squashfs /dev/mapper/$mapper_name $mnt
                    echo "Mounted at $mnt"; return 0
                else
                    echo "Mount failed."; $root_cmd cryptsetup close $mapper_name; return 1
                end
            else
                $root_cmd mount -t squashfs -o loop $img $mnt; and echo "Mounted at $mnt"; or echo "Mount failed"
            end

        case umount
            set -l mnt $argv[2]
            test -z "$mnt"; and return 1
            set -l dev ($root_cmd findmnt -n -o SOURCE $mnt)
            echo "Unmounting $mnt..."
            $root_cmd umount $mnt
            if string match -q "/dev/mapper/sq_*" "$dev"
                $root_cmd cryptsetup close (basename $dev)
            end
            rmdir $mnt 2>/dev/null; echo "Done."

        case create
            set -l input_path $argv[2]
            set -l output_path $argv[3]
            test -z "$input_path"; and return 1

            if test -z "$output_path"
                set -l clean_name (string trim -r -c / $input_path)
                set clean_name (string replace -r '\.(tar\.zst|tar\.gz|tgz|tar\.xz|txz|tar\.bz2|tbz|tar|7z|zip|rar)$' '' $clean_name)
                set output_path "$clean_name.squashfs"
            end
            
            set -l use_ram 0
            set -l ram_mount_point ""
            set -l temp_plain ""

            # --- ЛОГИКА RAM КЕША ---
            if set -q _flag_ram_cache
                set -l ram_gb $_flag_ram_cache
                echo "RAM Cache enabled: $ram_gb GB"
                
                # Создаем точку монтирования
                set ram_mount_point "/tmp/sq_ram_build_"(random)
                mkdir -p $ram_mount_point
                
                # Монтируем tmpfs
                echo "Mounting tmpfs ($ram_gb GB) at $ram_mount_point..."
                if not $root_cmd mount -t tmpfs -o size="$ram_gb"G tmpfs $ram_mount_point
                    echo "Error: Failed to mount RAM disk. Check permissions or free RAM."
                    rmdir $ram_mount_point
                    return 1
                end
                
                set use_ram 1
                set temp_plain "$ram_mount_point/temp_build.sqfs"
            else
                # Если без RAM, создаем временный файл рядом с целевым
                set temp_plain "$output_path.tmp.sqfs"
            end
            
            # Trap для очистки
            trap "
                if test -f \"$temp_plain\"
                    if test $use_ram -eq 0
                        echo 'Cleaning up temp file...'
                        rm \"$temp_plain\" 2>/dev/null
                    end
                end
                
                if test -n \"$ram_mount_point\"; and test -d \"$ram_mount_point\"
                     echo 'Unmounting RAM disk...'
                     $root_cmd umount \"$ram_mount_point\" 2>/dev/null
                     rmdir \"$ram_mount_point\" 2>/dev/null
                end

                if set -q tmp_map; and test -e /dev/mapper/$tmp_map
                     $root_cmd cryptsetup close $tmp_map 2>/dev/null
                end
                exit 1
            " INT TERM

            set -l comp_level (set -q _flag_compression; and echo $_flag_compression; or echo 15)
            
            # --- ШАГ 1: Создание Plain SquashFS ---
            if test $use_ram -eq 1
                echo "Step 1: Building image in RAM..."
            else
                echo "Step 1: Building temporary image on disk..."
            end
            
            set -l decompress_cmd
            if not test -d $input_path
                 switch $input_path
                    case '*.tar.zst' '*.tzst'; set decompress_cmd zstd -dcf
                    case '*.tar.gz' '*.tgz';   set decompress_cmd gzip -dcf
                    case '*.tar.xz' '*.txz';   set decompress_cmd xz -dcf
                    case '*.tar.bz2' '*.tbz';  set decompress_cmd bzip2 -dcf
                    case '*.tar';              set decompress_cmd cat
                    case '*'
                         type -q bsdtar; or return 1
                         set decompress_cmd bsdtar -c -f - --format=tar "@-"
                end
            end

            if test -d $input_path
                set -l mk_opts -comp zstd -Xcompression-level $comp_level -b 1M -no-recovery -noappend
                set -q _flag_no_progress; and set mk_opts $mk_opts -quiet; or set mk_opts $mk_opts -info
                mksquashfs "$input_path" "$temp_plain" $mk_opts
            else
                set -l source_cmd (type -q pv; and not set -q _flag_no_progress; and echo "pv \"$input_path\""; or echo "cat \"$input_path\"")
                fish -c "$source_cmd | $decompress_cmd | tar2sqfs -c zstd -X level=$comp_level -b 1M --force \"$temp_plain\""
            end

            if test $status -ne 0
                echo "Error creating squashfs image."
                return 1
            end

            # --- ШАГ 2: Шифрование / Перемещение ---
            if set -q _flag_encrypt
                set -l src_desc "temp file"
                if test $use_ram -eq 1
                    set src_desc "RAM"
                end
                echo "Step 2: Encrypting from $src_desc..."
                
                set -l sq_size (stat -c %s "$temp_plain")
                set -l container_size (math "$sq_size + 33554432")
                
                if not fallocate -l $container_size "$output_path" 2>/dev/null
                     dd if=/dev/zero of="$output_path" bs=1M count=(math "ceil($container_size/1024/1024)") status=none
                end

                if not $root_cmd cryptsetup luksFormat -q "$output_path"
                    echo "Encryption aborted."
                    rm "$output_path"
                    return 1
                end

                set -g tmp_map "sq_enc_"(random)
                if not $root_cmd cryptsetup open "$output_path" $tmp_map
                    echo "Failed to open container."
                    rm "$output_path"
                    return 1
                end

                echo "Copying data to encrypted container..."
                $root_cmd dd if="$temp_plain" of=/dev/mapper/$tmp_map bs=4M status=progress conv=fsync

                $root_cmd cryptsetup close $tmp_map
                
                echo "Success: Encrypted image created at $output_path"
            else
                echo "Moving to final destination..."
                if test $use_ram -eq 1
                    # Если в RAM, копируем на диск, т.к. mv не сработает между ФС
                    cp "$temp_plain" "$output_path"
                else
                    mv "$temp_plain" "$output_path"
                end
                echo "Success: $output_path"
            end
            
            ls -lh "$output_path"
            
            if test $use_ram -eq 1
                 $root_cmd umount "$ram_mount_point"
                 rmdir "$ram_mount_point"
            else
                 rm "$temp_plain" 2>/dev/null
            end
            set ram_mount_point ""
            set temp_plain ""
    end
end
