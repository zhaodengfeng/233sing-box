hop_port_start=20000
hop_port_end=50000

hop_pause() {
    echo
    echo -ne "按任意键返回..."
    read -rsn1
    echo -e "\n"
}

hop_apply() {
    unset is_config_file is_protocol port uuid password username ss_method ss_password door_port door_addr net_type path host is_servername is_private_key is_public_key net
    get info "$1"

    if [[ $net != "hysteria2" ]]; then
        warn "仅对 Hysteria2 提供."
        hop_pause
        return
    fi

    if [[ ! $port ]]; then
        warn "无法获取服务端口."
        hop_pause
        return
    fi

    if type -P nft &>/dev/null && nft list ruleset &>/dev/null; then
        hop_backend=nftables
        nft list table ip nat &>/dev/null || nft add table ip nat
        nft list chain ip nat prerouting &>/dev/null || nft 'add chain ip nat prerouting { type nat hook prerouting priority dstnat; }'
        nft list chain ip nat output &>/dev/null || nft 'add chain ip nat output { type nat hook output priority -100; }'

        nft_prerouting_rule="udp dport ${hop_port_start}-${hop_port_end} counter redirect to :${port}"
        nft_output_rule="ip daddr != 127.0.0.0/8 udp dport ${hop_port_start}-${hop_port_end} counter redirect to :${port}"

        nft list chain ip nat prerouting | grep -F "$nft_prerouting_rule" &>/dev/null || nft add rule ip nat prerouting udp dport ${hop_port_start}-${hop_port_end} counter redirect to :${port}
        nft list chain ip nat output | grep -F "$nft_output_rule" &>/dev/null || nft add rule ip nat output ip daddr '!=' 127.0.0.0/8 udp dport ${hop_port_start}-${hop_port_end} counter redirect to :${port}
    elif type -P iptables &>/dev/null; then
        hop_backend=iptables
        iptables -t nat -C PREROUTING -p udp --dport ${hop_port_start}:${hop_port_end} -j REDIRECT --to-ports ${port} &>/dev/null || \
            iptables -t nat -A PREROUTING -p udp --dport ${hop_port_start}:${hop_port_end} -j REDIRECT --to-ports ${port}
        iptables -t nat -C OUTPUT ! -d 127.0.0.0/8 -p udp --dport ${hop_port_start}:${hop_port_end} -j REDIRECT --to-ports ${port} &>/dev/null || \
            iptables -t nat -A OUTPUT ! -d 127.0.0.0/8 -p udp --dport ${hop_port_start}:${hop_port_end} -j REDIRECT --to-ports ${port}
    else
        warn "未检测到 nftables 或 iptables."
        hop_pause
        return
    fi

    _green "\n已添加端口跳跃"
    msg "配置: $is_config_file"
    msg "跳跃端口: ${hop_port_start}-${hop_port_end}/udp"
    msg "服务端口: ${port}/udp"
    msg "后端: $hop_backend\n"
    hop_pause
}
