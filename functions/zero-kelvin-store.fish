function zero-kelvin-store --description "Zero-Kelvin Store: Freeze data to SquashFS and Unfreeze back"
    # Alias: zks
    
    function _zks_help
        echo "Usage: zero-kelvin-store (zks) <command> [options]"
        echo ""
        echo "Commands:"
        echo "  freeze [targets...] [archive_path]    Offload data to a SquashFS archive"
        echo "  unfreeze <archive_path>               Restore data from an archive"
        echo ""
        echo "Freeze Options:"
        echo "  -e, --encrypt                         Encrypt the archive using LUKS (via squash_manager)"
        echo "  -r, --read <file>                     Read list of targets from a file"
        echo ""
        echo "Examples:"
        echo "  zks freeze /home/user/project /mnt/nas/data/backup.sqfs"
        echo "  zks freeze -e /secret/data /mnt/nas/data/secret.sqfs_luks.img"
        echo "  zks unfreeze /mnt/nas/data/backup.sqfs"
        return 0
    end

    if test (count $argv) -eq 0
        or contains -- -h $argv
        or contains -- --help $argv
        _zks_help
        return 0
    end

    set -l command $argv[1]
    set -e argv[1]

    switch $command
        case freeze
            # --- FREEZE LOGIC ---
            argparse 'e/encrypt' 'r/read=' 'h/help' -- $argv
            or return 1

            if set -q _flag_help
                _zks_help
                return 0
            end

            set -l targets
            set -l output_archive

            # 1. Collect targets
            # From file
            if set -q _flag_read
                if test -f "$_flag_read"
                    # Read non-empty lines, ignoring comments if any
                    set targets $targets (cat "$_flag_read" | string trim | string match -r -v '^$')
                else
                    echo "Error: Target file '$_flag_read' not found."
                    return 1
                end
            end

            # From arguments (remaining argv)
            set -l args_count (count $argv)
            if test $args_count -lt 1
                echo "Error: Output archive path is required."
                return 1
            end

            set output_archive $argv[$args_count]
            
            # Handle if output is a directory (auto-generate filename)
            if test -d "$output_archive"
                set -l timestamp (date +%Y-%m-%d_%H%M%S)
                set -l new_name "zks_$timestamp.sqfs"
                # Strip trailing slash if present then append filename
                set output_archive (string trim -r -c / -- "$output_archive")"/$new_name"
                echo "Notice: Output path is a directory. Saving to: $output_archive"
            end
            
            # If there are targets in argv, add them
            if test $args_count -gt 1
                set -l arg_targets $argv[1..-2]
                set targets $targets $arg_targets
            end

            if test (count $targets) -eq 0
                echo "Error: No targets specified for freezing."
                return 1
            end

            # Verify targets exist and convert to absolute paths
            set -l abs_targets
            for t in $targets
                if not test -e "$t"
                    echo "Error: Target '$t' does not exist."
                    return 1
                end
                set -a abs_targets (realpath "$t")
            end
            set targets $abs_targets

            # Check dependencies
            if not functions -q squash_manager
                echo "Error: 'squash_manager' function not found."
                return 1
            end
            if not functions -q rm-if-empty
                echo "Error: 'rm-if-empty' function not found."
                return 1
            end

            # Prepare for isolation
            set -l build_uuid (random)
            # FIX 1: Generate build path in HOST to avoid race condition in cleanup
            set -l host_build_dir "/tmp/zks_build_$build_uuid"
            
            set -l target_list_file "/tmp/zks_targets_$build_uuid.txt"
            string join \n -- $targets > $target_list_file

            # FIX 3: Resolve absolute path
            set -l sq_man_path (realpath (functions --details squash_manager))
            
            # Export variables for the subshell
            set -lx ZKS_TARGET_LIST $target_list_file
            set -lx ZKS_OUTPUT (realpath -m $output_archive)
            set -lx ZKS_SQ_PATH $sq_man_path
            set -lx ZKS_ENCRYPT $_flag_encrypt
            set -lx ZKS_HOSTNAME (uname -n)
            set -lx ZKS_BUILD_DIR $host_build_dir

            echo "🧊 Freezing data..."

            # Execute functionality inside a new mount namespace
            # Passing variables explicitly because some sudo configs reject -E
            sudo \
                ZKS_TARGET_LIST="$ZKS_TARGET_LIST" \
                ZKS_OUTPUT="$ZKS_OUTPUT" \
                ZKS_SQ_PATH="$ZKS_SQ_PATH" \
                ZKS_ENCRYPT="$ZKS_ENCRYPT" \
                ZKS_HOSTNAME="$ZKS_HOSTNAME" \
                ZKS_BUILD_DIR="$ZKS_BUILD_DIR" \
                unshare -m --propagation private fish -c '
                # --- INSIDE NAMESPACE ---
                
                # 1. Load dependency
                source $ZKS_SQ_PATH

                # 2. Create Skeleton (Use specific path passed from host)
                mkdir -p $ZKS_BUILD_DIR
                set -l restore_root "$ZKS_BUILD_DIR/to_restore"
                mkdir -p $restore_root

                # 3. Create Manifest
                set -l manifest "$ZKS_BUILD_DIR/list.yaml"
                echo "metadata:" > $manifest
                echo "  date: \"$(date)\"" >> $manifest
                echo "  host: \"$ZKS_HOSTNAME\"" >> $manifest
                echo "files:" >> $manifest

                # 4. Bind Mount Targets
                set -l counter 1
                cat $ZKS_TARGET_LIST | while read -l target_path
                    if test -z "$target_path"; continue; end

                    set -l container_dir "$restore_root/$counter"
                    mkdir -p $container_dir

                    echo "  - id: $counter" >> $manifest
                    echo "    original_path: \"$target_path\"" >> $manifest

                    if test -d "$target_path"
                        mount --bind "$target_path" "$container_dir"
                        echo "    type: directory" >> $manifest
                    else
                        set -l fname (basename "$target_path")
                        touch "$container_dir/$fname"
                        mount --bind "$target_path" "$container_dir/$fname"
                        echo "    type: file" >> $manifest
                    end
                    set counter (math $counter + 1)
                end

                # 5. Pack
                set -l enc_arg
                if test -n "$ZKS_ENCRYPT"
                    set enc_arg "--encrypt"
                end

                echo "📦 Packing to $ZKS_OUTPUT..."
                # Use $enc_arg unquoted so it expands to nothing if empty
                squash_manager create $enc_arg --no-progress "$ZKS_BUILD_DIR" "$ZKS_OUTPUT"
                
                if test $status -eq 0
                    exit 0
                else
                    exit 1
                end
            '
            set -l exit_code $status

            # Cleanup in host system
            rm -f $target_list_file
            
            # FIX 1: Cleanup specific dir
            if test -d "$host_build_dir"
                if test $exit_code -eq 0
                    # Fix permissions so user tools can work
                    sudo chown -R (id -un):(id -gn) "$host_build_dir"

                    if functions -q rm-if-empty
                        rm-if-empty "$host_build_dir/to_restore"
                    end
                    
                    rm -f "$host_build_dir/list.yaml"
                end
                
                # Check directly with rmdir to be safe (mkdir'ом logic from user likely meant rmdir)
                rmdir "$host_build_dir" 2>/dev/null
            end

            if test $exit_code -eq 0
                set_color green
                echo "✅ Archive created successfully: $output_archive"
                set_color normal
            else
                echo "❌ Failed to create archive."
                return 1
            end


        case unfreeze
            argparse 'h/help' -- $argv
            if set -q _flag_help
                _zks_help
                return 0
            end

            if test (count $argv) -lt 1
                echo "Error: Archive path required."
                return 1
            end
            set -l archive_path $argv[1]

            if not test -f "$archive_path"
                echo "Error: Archive '$archive_path' not found."
                return 1
            end

            # Need get_root_cmd for writing to protected dirs
            set -l root_cmd (functions -q get_root_cmd; and get_root_cmd; or echo "sudo")

            # Temporary mount point
            set -l mount_point "/tmp/zks_mnt_"(random)
            
            echo "🔓 Mounting archive..."
            squash_manager mount "$archive_path" "$mount_point"
            or return 1

            set -l manifest "$mount_point/list.yaml"
            if not test -f "$manifest"
                echo "Error: Invalid archive format (list.yaml not found)."
                squash_manager umount "$mount_point"
                return 1
            end

            echo "📖 Reading manifest..."
            
            # Parse manifest
            set -l ids
            set -l paths
            set -l types
            
            set -l current_id ""
            cat $manifest | while read -l line
                if string match -q "*id: *" -- $line
                    set current_id (string replace -r ".*id: " "" -- $line)
                    set -a ids $current_id
                else if string match -q "*original_path: *" -- $line
                     if test -n "$current_id"
                        set -l p (string replace -r ".*original_path: \"" "" -- $line | string replace -r "\"" "" )
                        set -a paths $p
                     end
                else if string match -q "*type: *" -- $line
                    if test -n "$current_id"
                        set -l t (string replace -r ".*type: " "" -- $line)
                        set -a types $t
                    end
                end
            end

            # FIX 5: Interactive Logic Flags
            set -l restore_all_subsequent 0
            set -l restore_count 0

            for i in (seq (count $ids))
                set -l id $ids[$i]
                set -l orig_path $paths[$i]
                set -l type $types[$i]
                
                # Check for subsequent 'all' flag
                set -l do_restore 0
                
                if test $restore_all_subsequent -eq 1
                    set do_restore 1
                    echo "Auto-restoring #$id -> $orig_path"
                else
                    echo ""
                    echo "Entry #$id:"
                    echo "  Path: $orig_path"
                    echo "  Type: $type"
                    
                    read -P "Restore this? [y/n/a(all)/q(quit)] " -l choice
                    
                    switch $choice
                        case y Y yes
                            set do_restore 1
                        case a A all
                            set do_restore 1
                            set restore_all_subsequent 1
                        case q Q quit
                            break
                        case n N no
                            set do_restore 0
                        case '*'
                            # Default to no? or re-ask? treating as skip (no) for simplicity
                            set do_restore 0
                    end
                end

                if test $do_restore -eq 1
                    echo "  Restoring..."
                    
                    set -l dest_dir (dirname "$orig_path")
                    if not test -d "$dest_dir"
                        # Create parent dir if needed. Might need sudo.
                         if test -w (dirname "$dest_dir")
                            mkdir -p "$dest_dir"
                         else
                            $root_cmd mkdir -p "$dest_dir"
                         end
                    end
                    
                    set -l src_path "$mount_point/to_restore/$id/"
                    
                    # FIX 2: Check Permissions
                    set -l rsync_cmd "rsync"
                    if not test -w "$dest_dir"
                         echo "  Notice: Use $root_cmd to write to $dest_dir"
                         set rsync_cmd "$root_cmd rsync"
                    end

                    if test "$type" = "directory"
                         # ensure target exists
                         if not test -d "$orig_path"
                             if test -w "$dest_dir"
                                mkdir -p "$orig_path"
                             else
                                $root_cmd mkdir -p "$orig_path"
                             end
                         end
                         
                         $rsync_cmd -av "$src_path" "$orig_path/"
                    else
                         set -l files_inside (ls -A "$src_path")
                         if test (count $files_inside) -eq 1
                             set -l file_src "$src_path/$files_inside[1]"
                             $rsync_cmd -av "$file_src" "$orig_path"
                         else
                             echo "Warning: Ambiguous file content for ID $id. Skipping."
                         end
                    end
                    
                    set restore_count (math $restore_count + 1)
                end
            end

            echo ""
            echo "Restoration complete. ($restore_count items processed)"
            
            squash_manager umount "$mount_point"

        case '*'
            echo "Error: Unknown command '$command'"
            _zks_help
            return 1
    end
end
