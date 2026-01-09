function fish_prompt --description 'Write out the prompt'
    set -l last_status $status
    set -l normal (set_color normal)
    set -l status_color (set_color brgreen)
    set -l cwd_color (set_color $fish_color_cwd)
    set -l vcs_color (set_color brpurple)
    set -l prompt_status ""

    # Длина пути (0 = полный путь)
    set -q fish_prompt_pwd_dir_length
    or set -lx fish_prompt_pwd_dir_length 0

    # Определяем суффикс (иконку)
    set -l suffix '🐟'
    if functions -q fish_is_root_user; and fish_is_root_user
        set suffix '#'
        set cwd_color (set_color $fish_color_cwd_root)
    else if set -q __sudo_using_rs; and test "$__sudo_using_rs" = "1"
        set suffix '🦀🐟'
    end

    # Если была ошибка - красим в красный и выводим код
    if test $last_status -ne 0
        set status_color (set_color $fish_color_error)
        set prompt_status $status_color "[" $last_status "]" $normal
    end

    # Сборка промпта: [user@host] [path] [git] [status]
    # На новой строке выводим иконку
    echo -s (prompt_login) ' ' $cwd_color (prompt_pwd) $vcs_color (fish_vcs_prompt) $normal ' ' $prompt_status
    echo -n -s $status_color $suffix ' ' $normal
end
