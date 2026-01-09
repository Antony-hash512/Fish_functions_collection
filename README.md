# Fish Functions Collection

This repository contains a collection of custom functions for the **Fish shell**. 
These scripts are designed to automate daily tasks, manage system configurations, handle file operations, and improve the overall terminal experience.

Many functions include interactive elements, color-coded output, and safety checks.

## Development Status & Localization

This is the active development branch (bleeding edge). New features land here first, which may result in a mix of English and Russian in code comments and output.

An English-only stable branch is planned for the future.

## Installation

### Using Fisher

> ⚠️ **Warning:**
> If you already have custom fish functions in your local config, installing via Fisher **may overwrite files with matching names**.
>
> * **Check for conflicts:** Ensure your existing functions do not share names with the functions in this repository.
> * **Manual approach:** If you are unsure, it is recommended to copy only the specific files you need manually (see below).
> * **Conflict resolution:** You can use the `frename` utility included in this collection to easily rename functions if you need to resolve naming collisions.

```fish
fisher install Antony-hash512/Fish_functions_collection
```
### Manual

Clone the repository and copy functions to `~/.config/fish/functions/`.

## Functions Overview

| Function Name | Description | Possible Keys / Arguments | Language (Comments/Desc) |
| :--- | :--- | :--- | :--- |
| **deluge_extract** | Extract `.torrent` files from Deluge state based on a download path. | `<search_path> [dest_dir]` |  Mixed: Russian (Interface, source code comments) /  English (description) |
| **deluge_extract2** | Advanced extraction of `.torrent` files by Path OR by Name. | `<search_term> [dest_dir]`, `--name` (`-n`) |  Mixed: Russian (Interface, source code comments) /  English (description) |
| **fedit** | Find and open a fish function using `fzf` and your preferred editor. | Interactive | Mixed: English (main interface) /  Russian (source code comments, description and errors) |
| **find_hardlinks** | Find all hardlinks pointing to a specific file. | `[-d /path] <file>` | Russian  |
| **fish_greeting** | Customizes or suppresses the default Fish shell greeting. | N/A | Interface: N/A,  Description: English, Mixed source code comments: English /  Russian |
| **fish_prompt** | A custom, informative prompt with git status, error codes, and icons. | N/A | Interface: N/A, Description: English, Source code comments: Russian |
| **frename** | Rename a fish function (both the file and the internal function name). | `<old_name> <new_name>` | Interface: N/A, Description/Source code comments: Russian |
| **gdisk_mount** | Mount Google Drive using `rclone` (requires existing `gdrive` config). | N/A |  English |
| **hcp** | Recursive hardlink copy (safe wrapper for `cp -al`). | `<source> <dest>` |  Russian |
| **last_pkgs** | Show the list of most recently installed packages (Arch Linux). | `[limit]` |  Russian |
| **mancat** | Output the content of a man page directly to the terminal (no pager). | `<man_page>` |  Interface: N/A, Description/Source code comments: Russian |
| **mancopy** | Copy the content of a man page to the system clipboard. | `<man_page>` |  Interface: N/A, Description/Source code comments: Russian |
| **my_fish_functions** | List all custom functions in this collection with their descriptions. | `--all` |  Russian |
| **nat_on4nas_iptables** | Enable NAT to share internet to another device (e.g., NAS) interactively. | Interactive |  Russian |
| **nat_off4nas_iptables**| Disable NAT and clear `iptables` rules for internet sharing. | N/A |  Russian |
| **nvim** | Wrapper to run Neovim with `SHELL=/bin/bash` (compatibility fix). | `[args...]` | Interface: N/A, Description/Source code comments: Russian |
| **rsync2nas_move** | Move files to NAS using `rsync` with `size-only` check. | `<source> <target>` |  Russian |
| **save_local_torrents**| Export loaded `.torrent` files from local Deluge with human-readable names. | `[dest_dir]` |  Mixed: Russian (Interface, source code comments) /  English (description) |
| **smv** | "**Smart Move**": Safely move files handling recursion, duplicates, and name conflicts. | `file1 [file2...] <dest_dir>` |  Russian |
| **sudo** | Wrapper for `sudo-rs` (Rust implementation) with fallback to standard sudo. | `[args...]` | Interface: N/A, Decription/source code comments:   Russian |
| **sudo-switch-alias** | Toggle the `sudo` alias between the system `sudo` and `sudo-rs`. | N/A |  Russian |
| **update-grub** | Shortcut to update GRUB2 configuration (Ubuntu-style style command for Arch). | N/A | Interface: N/A, Decription/source code comments:   Russian |
| **which-versions** | Show all installed paths and versions for a specific program. | `<command>` |  Russian |
| **yt-dlp-transcript** | Download subtitles/transcripts from YouTube using `yt-dlp`. | `[url]`, `--lang`, `--vtt`, `--text` |  Russian |
