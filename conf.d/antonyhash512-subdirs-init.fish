# ~/.config/fish/conf.d/antonyhash512-subdirs-init.fish

set -l funcs_dir "$HOME/.config/fish/functions"

if test -d "$funcs_dir"
    for dir in "$funcs_dir"/*/
        if not contains "$dir" $fish_function_path
            set -p fish_function_path "$dir"
        end
    end
end
