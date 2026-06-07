#!/usr/bin/env fish

# This script organizes fish functions into subdirectories under sorted/
# by creating symlinks to the flat repository of functions in functions/.

set funcs_dir functions
set sorted_dir sorted

# Define list of files for each category
set mapping \
    "core:fedit.fish" \
    "core:fish_greeting.fish" \
    "core:fish_prompt.fish" \
    "core:frename.fish" \
    "core:my_fish_functions.fish" \
    "encoding-audio:extract_original_audio.fish" \
    "encoding-audio:launch_cosyvoice_server.fish" \
    "encoding-audio:record_system_audio.fish" \
    "encoding-audio:replace_audio.fish" \
    "encoding-audio:replace_audio_track.fish" \
    "encoding-audio:separate_audio.fish" \
    "encoding-images:merge_image_sequences.fish" \
    "encoding-images:rename_frames_sequentially.fish" \
    "encoding-images:upscale_image_realesrgan.fish" \
    "encoding-subs:add_subtitle_hint.fish" \
    "encoding-subs:apply_hardsubs.fish" \
    "encoding-subs:fix_srt_numbers.fish" \
    "encoding-subs:shift_subtitles.fish" \
    "encoding-subs:srt2wav.fish" \
    "encoding-subs:watermark_pro.fish" \
    "encoding-subs:whisper_transcribe.fish" \
    "encoding-subs:yo_interactive.fish" \
    "encoding-subs:yt-dlp-transcript.fish" \
    "encoding-video:concatenate_videos.fish" \
    "encoding-video:upscale_video_realesrgan.fish" \
    "encoding-video:video_resolution.fish" \
    "etc:save_qr.fish" \
    "etc:show_qr.fish" \
    "legacy:deluge_extract2.fish" \
    "legacy:deluge_extract.fish" \
    "legacy:migrate_antigravity_settings.fish" \
    "legacy:nat_off4nas_iptables.fish" \
    "legacy:nat_on4nas_iptables.fish" \
    "legacy:save_local_torrents.fish" \
    "legacy:set_display_mirror.fish" \
    "legacy:squash_manager6.fish" \
    "legacy:squash_manager.fish" \
    "legacy:zero-kelvin-store.fish" \
    "network:check_remote_ssh_logs.fish" \
    "network:gdisk_mount.fish" \
    "network:mount-remote-dir-by-rclone.fish" \
    "network:mount-remote-dir-by-smb.fish" \
    "network:mount-remote-dir-by-webdav.fish" \
    "network:pass.fish" \
    "network:persistent_ssh.fish" \
    "network:rsync2nas_move.fish" \
    "network:test_ssh_speed.fish" \
    "say:say-en-direct.fish" \
    "say:say-en-kokoro.fish" \
    "say:say-ru-betatest1-direct.fish" \
    "say:say-ru-correct-stress.fish" \
    "say:say-ru-direct.fish" \
    "say:say-ru.fish" \
    "say:say-stop.fish" \
    "sysadmin:android_send.fish" \
    "sysadmin:check_bin.fish" \
    "sysadmin:find_hardlinks.fish" \
    "sysadmin:get_root_cmd.fish" \
    "sysadmin:git_check_updates.fish" \
    "sysadmin:hardlinks-cp.fish" \
    "sysadmin:last_pkgs.fish" \
    "sysadmin:mancat.fish" \
    "sysadmin:mancopy.fish" \
    "sysadmin:paru_clean.fish" \
    "sysadmin:reflinks-cp.fish" \
    "sysadmin:rm-if-empty.fish" \
    "sysadmin:smart-mv.fish" \
    "sysadmin:sudo.fish" \
    "sysadmin:sudo-switch-alias.fish" \
    "sysadmin:super_shred.fish" \
    "sysadmin:toggle_night_mode.fish" \
    "sysadmin:update-all.fish" \
    "sysadmin:update_all_git_repositories.fish" \
    "sysadmin:update-grub.fish" \
    "sysadmin:updates_rclone.fish" \
    "sysadmin:which-versions.fish"

for item in $mapping
    set -l parts (string split -m 1 ":" $item)
    set -l category $parts[1]
    set -l file $parts[2]
    
    set -l src_file "$funcs_dir/$file"
    set -l dest_dir "$sorted_dir/$category"
    set -l dest_file "$dest_dir/$file"
    
    # Check if the source file exists in the functions directory
    if test -f "$src_file"
        # Create category directory if it does not exist
        if not test -d "$dest_dir"
            mkdir -p "$dest_dir"
        end
        
        # Create relative symbolic link pointing to the file in functions/
        ln -sf "../../$funcs_dir/$file" "$dest_file"
        echo "Created symlink: $dest_file -> ../../$funcs_dir/$file"
        
        # Stage the symlink if in a git repository
        if git rev-parse --is-inside-work-tree >/dev/null 2>&1
            git add "$dest_file"
        end
    else
        echo "Warning: Source file $src_file not found"
    end
end
