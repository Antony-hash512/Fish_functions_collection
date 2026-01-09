# Fish Functions Collection

This repository contains a collection of custom functions for the **Fish shell**. 
These scripts are designed to automate daily tasks, manage system configurations, handle file operations, and improve the overall terminal experience.

Many functions include interactive elements, color-coded output, and safety checks.

## Functions Overview

| Function Name | Description | Possible Keys / Arguments | Language (Comments/Desc) |
| :--- | :--- | :--- | :--- |
| **deluge_extract** | Extract `.torrent` files from Deluge state based on a download path. | `<search_path> [dest_dir]` |  Mixed: Russian /  English |
| **deluge_extract2** | Advanced extraction of `.torrent` files by Path OR by Name. | `<search_term> [dest_dir]`, `--name` (`-n`) |  Mixed: Russian /  English |
| **fedit** | Find and open a fish function using `fzf` and your preferred editor. | Interactive |  Russian |
| **find_hardlinks** | Find all hardlinks pointing to a specific file. | `[-d /path] <file>` |  Russian |
| **fish_greeting** | Customizes or suppresses the default Fish shell greeting. | N/A |  Mixed: English /  Russian |
| **fish_prompt** | A custom, informative prompt with git status, error codes, and icons. | N/A |  Russian |
| **frename** | Rename a fish function (both the file and the internal function name). | `<old_name> <new_name>` |  Russian |
| **gdisk_mount** | Mount Google Drive using `rclone` (requires existing `gdrive` config). | N/A |  English |
| **hcp** | Recursive hardlink copy (safe wrapper for `cp -al`). | `<source> <dest>` |  Russian |
| **last_pkgs** | Show the list of most recently installed packages (Arch Linux). | `[limit]` |  Russian |
| **mancat** | Output the content of a man page directly to the terminal (no pager). | `<man_page>` |  Russian |
| **mancopy** | Copy the content of a man page to the system clipboard. | `<man_page>` |  Russian |
| **my_fish_functions** | List all custom functions in this collection with their descriptions. | `--all` |  Russian |
| **nat_off4nas_iptables**| Disable NAT and clear `iptables` rules for internet sharing. | N/A |  Russian |
| **nat_on4nas_iptables** | Enable NAT to share internet to another device (e.g., NAS) interactively. | Interactive |  Russian |
| **nvim** | Wrapper to run Neovim with `SHELL=/bin/bash` (compatibility fix). | `[args...]` |  Russian |
| **rsync2nas_move** | Move files to NAS using `rsync` with `size-only` check. | `<source> <target>` |  Russian |
| **save_local_torrents**| Export loaded `.torrent` files from local Deluge with human-readable names. | `[dest_dir]` |  Mixed: Russian /  English |
| **smv** | "**Smart Move**": Safely move files handling recursion, duplicates, and name conflicts. | `file1 [file2...] <dest_dir>` |  Russian |
| **sudo** | Wrapper for `sudo-rs` (Rust implementation) with fallback to standard sudo. | `[args...]` |  Russian |
| **sudo-switch-alias** | Toggle the `sudo` alias between the system `sudo` and `sudo-rs`. | N/A |  Russian |
| **update-grub** | Shortcut to update GRUB2 configuration (Ubuntu-style style command for Arch). | N/A |  Russian |
| **which-versions** | Show all installed paths and versions for a specific program. | `<command>` |  Russian |
| **yt-dlp-transcript** | Download subtitles/transcripts from YouTube using `yt-dlp`. | `[url]`, `--lang`, `--vtt`, `--text` |  Russian |
