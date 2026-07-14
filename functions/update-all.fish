function update-all --description "Full update: Arch, AUR, Flatpak, uv, Rust, Go"
        keychain --eval --quiet id_ed25519 | source
    set_color blue
    echo "==> Обновление системы (Arch + AUR)..."
    set_color normal
    paru -Syu

    set_color blue
    echo "==> Обновление Flatpak-приложений..."
    set_color normal
    if command -v flatpak > /dev/null
        # Можно добавить флаг -y (flatpak update -y), если не хочешь каждый раз жать 'y'
        flatpak update 
    else
        echo "Flatpak не установлен. Пропуск."
    end

    set_color blue
    echo "==> Обновление глобальных утилит Python (uv)..."
    set_color normal
    if command -v uv > /dev/null
        uv tool upgrade --all
       #uv self update установлено из extra
    else
        echo "uv не найден. Пропуск."
    end

    set_color blue
    echo "==> Обновление Rust-тулчейна..."
    set_color normal
    if command -v rustup > /dev/null
        rustup update
    else
        echo "rustup не найден. Пропуск."
    end
    
    set_color blue
    echo "==> Обновление бинарников Cargo..."
    set_color normal
    if command -v cargo-install-update > /dev/null
        cargo install-update -a
    else
        echo "Утилита cargo-update не найдена. Пропуск."
    end

    set_color blue
    echo "==> Обновление бинарников Go (через gup)..."
    set_color normal
    if command -v gup > /dev/null
        gup update
    else
        echo "Утилита gup не найдена. Пропуск."
    end

    set_color blue
    echo "==> Обновление Grok..."
    set_color normal
    if command -v grok > /dev/null
        grok update
    else
        echo "Грок не установлен, если хотете установить: curl -fsSL https://x.ai/cli/install.sh | bash"
    end

    set_color green
    echo "==> Все обновления успешно завершены!"
    set_color normal
end
