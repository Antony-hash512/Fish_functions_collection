function nat_on4nas_iptables --description "Настройка временного NAT (Раздача интернета) например для NAS с помощью iptables"
    echo "=== Настройка временного NAT (Раздача интернета) ==="
    
    # 1. Получаем список интерфейсов для подсказки
    echo "Доступные сетевые интерфейсы:"
    ip -br link show | grep -v "lo"
    echo "---------------------------------------------------"

    # 2. Интерактивный запрос интерфейса с интернетом (WAN)
    # Пытаемся угадать: ищем беспроводной интерфейс (wlo/wlan)
    set default_wan (ip -br link show | awk '/^w/ {print $1}' | head -n 1)
    read -P "Введите интерфейс С ИНТЕРНЕТОМ (Вход) [$default_wan]: " wan_if
    if test -z "$wan_if"
        set wan_if $default_wan
    end

    # 3. Интерактивный запрос интерфейса локалки (LAN)
    # Пытаемся угадать: ищем проводной интерфейс (enp/eth), который не WAN
    set default_lan (ip -br link show | awk '/^e/ {print $1}' | head -n 1)
    read -P "Введите интерфейс КУДА раздавать (Выход на NAS) [$default_lan]: " lan_if
    if test -z "$lan_if"
        set lan_if $default_lan
    end

    # 4. Проверка
    if test -z "$wan_if"; or test -z "$lan_if"
        echo "ОШИБКА: Интерфейсы не выбраны."
        return 1
    end

    echo "---------------------------------------------------"
    echo "Настраиваем: Интернет ($wan_if) -> Локалка ($lan_if)"

    # 5. Включаем IP Forwarding (временно)
    echo "1. Включаем ip_forward..."
    sudo sysctl net.ipv4.ip_forward=1 > /dev/null

    # 6. Добавляем правила iptables
    echo "2. Настраиваем NAT (Masquerade)..."
    # Очищаем старые правила NAT для чистоты, если были
    sudo iptables -t nat -F POSTROUTING
    sudo iptables -t nat -A POSTROUTING -o $wan_if -j MASQUERADE

    echo "3. Разрешаем Forwarding..."
    # Разрешаем прохождение пакетов
    sudo iptables -A FORWARD -i $lan_if -o $wan_if -j ACCEPT
    # Разрешаем обратный трафик (Established)
    sudo iptables -A FORWARD -m conntrack --ctstate RELATED,ESTABLISHED -j ACCEPT

    echo "---------------------------------------------------"
    echo "✅ Готово! Интернет раздается."
    echo "Не забудьте прописать шлюз на NAS."
    
    # 7. Подсказка IP адреса для NAS
    set lan_ip (ip -br addr show $lan_if | awk '{print $3}' | cut -d/ -f1)
    echo "Ваш IP в локалке: $lan_ip"
    echo "Укажите этот IP ($lan_ip) как Gateway на NAS."
end
