# See also
 - Other my dotfiles
   - You can find them here: [Antony-hash512_dotfiles](https://github.com/Antony-hash512/Antony-hash512_dotfiles)
 - Other vesions:
   - For Synology NAS: [Fish_functions_collection_for_DSM](https://github.com/Antony-hash512/Fish_functions_collection_for_DSM) 

# Fish Functions Collection

This repository contains a collection of custom functions for the [**Fish shell**](https://github.com/fish-shell/fish-shell). 
These scripts are designed to automate daily tasks, manage system configurations, handle file operations, and improve the overall terminal experience.

Many functions include interactive elements, color-coded output, and safety checks.

## Development Status & Localization

This is the active development branch (bleeding edge). New features land here first, which may result in a mix of English and Russian in code comments and output.

An English-only stable branch is planned for the future.

## Installation

### Using Fisher

> ⚠️ **Warning:**
> If you already have custom fish functions in your local config (`~/.config/fish/functions/`), installing via Fisher **may overwrite files with matching names**.

* **Check for conflicts:** Ensure your existing functions do not share names with the functions in this repository.
* **Manual approach:** If you are unsure, it is recommended to copy only the specific files you need manually (see below).
* **Conflict resolution:** You can use the `frename` utility included in this collection to easily rename functions if you need to resolve naming collisions.

```fish
fisher install Antony-hash512/Fish_functions_collection
```
### Manual

Clone the repository and copy functions to `~/.config/fish/functions/`.

> **💡 Pro Tip:**
> For granular control, use a visual diff tool (like **Meld** or **KDiff3**) to compare the cloned `functions/` directory against your local `~/.config/fish/functions/` and inspect individual files.
>
> If you are working remotely (SSH) or prefer the terminal, use **`vimdiff`** (or `nvim -d`). You can also use **Midnight Commander** (`mc`) with its Compare Directories (`C-x d`) or Compare Files (`C-x C-d`) hotkeys to view differences side-by-side and interactively merge changes.
>
> This allows you to visually inspect differences and safely transfer entire files or merge specific parts of the code without blindly overwriting your existing configuration.

## Functions Overview

| Function Name | Description | Possible Keys / Arguments | Dependencies | Language (Comments/Desc) |
| :--- | :--- | :--- | :--- | :--- |
| **rerlinks-cp** | Copy with `reflink=always` (Cow) (wrapper for `cp`). | `[source] [dest]` | N/A | Russian comments, English description |
| **deluge_extract** | Extract `.torrent` files from Deluge state based on a download path. | `<search_path> [dest_dir]` | `deluge` | Mixed: Russian (Interface, source code comments) /  English (description) |
| **deluge_extract2** | Advanced extraction of `.torrent` files by Path OR by Name. | `<search_term> [dest_dir]`, `--name` (`-n`) | `deluge` | Mixed: Russian (Interface, source code comments) /  English (description) |
| **fedit** | Find and open a fish function using `fzf` and your preferred editor. | Interactive | `fzf`, `bat` (optional) | Mixed: English (main interface) /  Russian (source code comments, description and errors) |
| **find_hardlinks** | Find all hardlinks pointing to a specific file. | `[-d /path] <file>` | N/A | Russian  |
| **fish_greeting** | Customizes or suppresses the default Fish shell greeting. | N/A | N/A | Interface: N/A,  Description: English, Mixed source code comments: English /  Russian |
| **fish_prompt** | A custom, informative prompt with git status, error codes, and icons. | N/A | `git` (optional for vcs prompt) | Interface: N/A, Description: English, Source code comments: Russian |
| **frename** | Rename a fish function (both the file and the internal function name). | `<old_name> <new_name>` | N/A | Interface: N/A, Description/Source code comments: Russian |
| **gdisk_mount** | Mount Google Drive using `rclone` (requires existing `gdrive` config). | N/A | `rclone` | English |
| **get_root_cmd** | Safely detect root privilege command (`sudo`, `doas`, `run0` etc.) using a whitelist. | N/A | N/A | English description, Russian comments |
| **hardlinks-cp** | Recursive hardlink copy (safe wrapper for `cp -al`). | `<source> <dest>` | N/A | Russian |
| **last_pkgs** | Show the list of most recently installed packages (Arch Linux). | `[limit]` | `expac` | Russian |
| **mancat** | Output the content of a man page directly to the terminal (no pager). | `<man_page>` | N/A | Interface: N/A, Description/Source code comments: Russian |
| **mancopy** | Copy the content of a man page to the system clipboard. | `<man_page>` | `wl-clipboard` (Wayland) or `xsel` (X11) | Interface: N/A, Description/Source code comments: Russian |
| **mount-remote-dir-by-rclone** | Mount remote directories using `rclone` (interactive wizard available). | `[up/down/list/forget]` | `rclone`, `get_root_cmd` (function) | Mixed |
| **mount-remote-dir-by-smb** | Mount remote SMB/CIFS shares (interactive wizard available). | `[up/down/list/forget]` | `cifs-utils`, `get_root_cmd` (function) | Mixed |
| **mount-remote-dir-by-webdav** | Mount remote WebDAV directories (davfs2) (interactive wizard available). | `[up/down/list/forget]` | `davfs2`, `get_root_cmd` (function) | Mixed |
| **my_fish_functions** | List all custom functions in this collection with their descriptions. | `--all` | N/A | Russian |
| **nat_on4nas_iptables** | Enable NAT to share internet to another device (e.g., NAS) interactively. | Interactive | `iptables`, `iproute2` | Russian |
| **nat_off4nas_iptables**| Disable NAT and clear `iptables` rules for internet sharing. | N/A | `iptables` | Russian |
| **nvim** | Wrapper to run Neovim with `SHELL=/bin/bash` (compatibility fix). | `[args...]` | `neovim` | Interface: N/A, Description/Source code comments: Russian |
| **paru_clean** | Clean `paru` (AUR helper) cache, keeping the last 2 versions. | N/A | `pacman-contrib`, `paru` | Russian |
| **rsync2nas_move** | Move files to NAS using `rsync` with `size-only` check. | `<source> <target>` | `rsync` | Russian |
| **save_local_torrents**| Export loaded `.torrent` files from local Deluge with human-readable names. | `[dest_dir]` | `deluge` | Mixed: Russian (Interface, source code comments) /  English (description) |
| **save_qr** | Generate a QR code and save it to a PNG file (uses `qrencode`). | `<filename> <text>` | `qrencode` | Russian code comments, English description |
| **show_qr** | Display a QR code directly in the terminal (ANSI UTF8). | `<text>` | `qrencode` | Russian code comments, English description |
| **smart-mv** | "**Smart Move**": Safely move files handling recursion, duplicates, and name conflicts. | `file1 [file2...] <dest_dir>` | `rsync` | Russian |
| **squash_manager** | Smartly manage SquashFS: create (optional encryption), mount, and umount. | `create [OPTIONS] <input> [output], mount <img/mnt>, umount <mnt>` | `squashfs-tools`, `cryptsetup` (for -e), `tar2sqfs` (for archives) | Mixed |
| **test_ssh_speed** | Test SSH connection speed using `pv` (pipe viewer). | `<host>` | `pv`, `openssh` | Russian code comments, English description |
| **sudo** | Wrapper for `sudo-rs` (Rust implementation) with fallback to standard sudo. | `[args...]` | `sudo-rs` (optional), `sudo` (standard) | Interface: N/A, Decription/source code comments:   Russian |
| **sudo-switch-alias** | Toggle the `sudo` alias between the system `sudo` and `sudo-rs`. | N/A | `sudo-rs` (optional) | Russian |
| **update-grub** | Shortcut to update GRUB2 configuration (Ubuntu-style style command for Arch). | N/A | `grub` | Interface: N/A, Decription/source code comments:   Russian |
| **which-versions** | Show all installed paths and versions for a specific program. | `<command>` | N/A | Russian |
| **yt-dlp-transcript** | Download subtitles/transcripts from YouTube using `yt-dlp`. | `[url]`, `--lang`, `--vtt`, `--text` | `yt-dlp` | Russian |



