#!/bin/bash

# 一键安装 Emby BadHttp 监控服务（核心脚本内容完全未修改）
# 用法：把本文件保存为 emby-watch-install.sh 后执行
#   sudo bash emby-watch-install.sh

# ===========================
# 写入核心监控脚本（内容 100% 原样，未做任何修改）
# ===========================
sudo tee /usr/local/bin/emby-watch.sh > /dev/null << 'EOF'
#!/bin/bash

logfile="/tmp/embyserver.log"
tmpfile="/tmp/emby-badhttp.log"
logblock="/var/log/emby/emby-badhttp-block.log"

# ==================== 新增配置区 ====================
# 白名单文件（一行一个 IP 或网段，支援 CIDR，例如 192.168.1.0/24）
WHITELIST_FILE="/var/log/emby/emby_whitelist.txt"

# 永久黑名单文件（被拉进这里后永久 DROP，永不解封）
BLACKLIST_FILE="/var/log/emby/emby_blacklist.txt"

# 封禁时间递进（秒）
BANTIME_LEVEL=( 4 6 8 10 )
# ====================================================

# ==================== 新增：IP格式验证 ====================
validate_ip() {
    local ip="$1"

    # 必须符合 N.N.N.N
    [[ "$ip" =~ ^([0-9]{1,3}\.){3}[0-9]{1,3}$ ]] || return 1

    # 每段必须 0~255
    IFS='.' read -r a b c d <<< "$ip"
    for seg in "$a" "$b" "$c" "$d"; do
        (( seg >= 0 && seg <= 255 )) || return 1
    done

    return 0
}
# =======================================================


# 读取白名单和永久黑名单（热更新）
load_lists() {
    declare -gA WHITELIST BLACKLIST
    WHITELIST=(); BLACKLIST=()

    [[ -f "$WHITELIST_FILE" ]] && while IFS= read -r ip; do
        [[ -n "$ip" && "$ip" != "#"* ]] && WHITELIST["$ip"]=1
    done < "$WHITELIST_FILE"

    [[ -f "$BLACKLIST_FILE" ]] && while IFS= read -r ip; do
        [[ -n "$ip" && "$ip" != "#"* ]] && BLACKLIST["$ip"]=1
    done < "$BLACKLIST_FILE"
}
load_lists   # 初次加载

# 阈值
BADHTTP_THRESHOLD=3
RESP500_THRESHOLD=4

# 计数器
declare -A badhttp_times resp500_times ban_count

# 已封禁 IP 及解封时间
declare -A banned_ips

# 初始化临时文件
> "$tmpfile"
> "$logblock"


# 检查 IP 是否在名单内
is_whitelisted() {
    local ip="$1"
    for wl in "${!WHITELIST[@]}"; do
        if [[ "$wl" == *"/"* ]]; then
            ip route get "$ip" 2>/dev/null | grep -q "src.*$wl" && return 0
        elif [[ "$ip" == "$wl" ]]; then
            return 0
        fi
    done
    return 1
}

is_blacklisted() {
    local ip="$1"
    [[ -n "${BLACKLIST[$ip]}" ]]
}


# 永久拉黑
permaban() {
    local ip="$1"
    iptables -I DOCKER-USER -s "$ip" -j DROP
    echo "$ip" >> "$BLACKLIST_FILE"

    echo "$(date '+%Y-%m-%d %H:%M:%S') 永久封禁 IP: $ip (拉入黑名单)" | tee -a "$logblock"

    unset banned_ips["$ip"]
    unset badhttp_times["$ip"]
    unset resp500_times["$ip"]
    unset ban_count["$ip"]
}


# 动态封禁时间
get_bantime() {
    local ip="$1"
    local cnt=${ban_count[$ip]:-0}
    local level=$(( cnt >= ${#BANTIME_LEVEL[@]} ? ${#BANTIME_LEVEL[@]}-1 : cnt ))
    echo "${BANTIME_LEVEL[$level]}"
}


# 主循环
tail -Fn0 "$logfile" | while read line; do
    now=$(date +%s)

    # 每 60 秒热加载名单
    [[ $(( now % 60 )) -eq 0 ]] && load_lists

    # 到期自动解封
    for ip in "${!banned_ips[@]}"; do
        if [[ "${banned_ips[$ip]}" -le "$now" ]]; then
            if ! is_blacklisted "$ip"; then
                iptables -D DOCKER-USER -s "$ip" -j DROP 2>/dev/null
                echo "$(date '+%Y-%m-%d %H:%M:%S') 解封 IP: $ip" | tee -a "$logblock"
            fi
            unset banned_ips["$ip"]
        fi
    done

    # 提取 IP
    ip=$(echo "$line" | perl -CSD -pe 's/[\x{200B}-\x{200D}]//g' \
        | grep -Po '((Source Ip)|Response 500 to):?\s*\K[0-9]{1,3}(\.[0-9]{1,3}){3}' | head -1)

    [[ -z "$ip" ]] && continue

    # 新增：IP格式校验，不合法直接跳过
    validate_ip "$ip" || continue

    # 白名单直接跳过
    if is_whitelisted "$ip"; then
        continue
    fi

    # 永久黑名单直接 drop
    if is_blacklisted "$ip"; then
        [[ -z "${banned_ips[$ip]}" ]] && iptables -I DOCKER-USER -s "$ip" -j DROP 2>/dev/null
        continue
    fi

    # 临时封禁中，不再统计
    if [[ -n "${banned_ips[$ip]}" ]]; then
        continue
    fi


    # -----------------------------
    # BadHttpRequestException
    # -----------------------------
    if echo "$line" | grep -q "BadHttpRequestException"; then
        badhttp_times[$ip]="${badhttp_times[$ip]} $now"
        badhttp_times[$ip]=$(echo "${badhttp_times[$ip]}" | tr ' ' '\n' | awk -v n=$now '$1 >= n-1' | tr '\n' ' ')
        count=$(echo "${badhttp_times[$ip]}" | wc -w)

        if [[ "$count" -ge "$BADHTTP_THRESHOLD" ]]; then
            ban_count[$ip]=$(( ${ban_count[$ip]:-0} + 1 ))
            bantime=$(get_bantime "$ip")

            if [[ "$bantime" -ge 999999999 ]]; then
                permaban "$ip"
            else
                iptables -I DOCKER-USER -s "$ip" -j DROP
                banned_ips[$ip]=$((now + bantime))
                echo "$(date '+%Y-%m-%d %H:%M:%S') 封禁 IP: $ip, 类型: BADHTTP, 第 ${ban_count[$ip]} 次, 封禁 ${bantime}s" | tee -a "$logblock"
            fi
            badhttp_times[$ip]=""
        fi
    fi


    # -----------------------------
    # Response 500
    # -----------------------------
    if echo "$line" | grep -q "Response 500 to"; then
        resp500_times[$ip]="${resp500_times[$ip]} $now"
        resp500_times[$ip]=$(echo "${resp500_times[$ip]}" | tr ' ' '\n' | awk -v n=$now '$1 >= n-1' | tr '\n' ' ')
        count=$(echo "${resp500_times[$ip]}" | wc -w)

        if [[ "$count" -ge "$RESP500_THRESHOLD" ]]; then
            ban_count[$ip]=$(( ${ban_count[$ip]:-0} + 1 ))
            bantime=$(get_bantime "$ip")

            if [[ "$bantime" -ge 999999999 ]]; then
                permaban "$ip"
            else
                iptables -I DOCKER-USER -s "$ip" -j DROP
                banned_ips[$ip]=$((now + bantime))
                echo "$(date '+%Y-%m-%d %H:%M:%S') 封禁 IP: $ip, 类型: RESP500, 第 ${ban_count[$ip]} 次, 封禁 ${bantime}s" | tee -a "$logblock"
            fi
            resp500_times[$ip]=""
        fi
    fi

done
EOF

# ===========================
# 权限
# ===========================
sudo chmod +x /usr/local/bin/emby-watch.sh

# ===========================
# 创建必要目录和空文件（防止脚本启动时报错）
# ===========================
sudo mkdir -p /var/log/emby
sudo touch /var/log/emby/emby-badhttp-block.log
sudo touch /var/log/emby/emby_whitelist.txt
sudo touch /var/log/emby/emby_blacklist.txt

# ===========================
# 创建 systemd 服务（风格对齐 xiaoya）
# ===========================
sudo tee /etc/systemd/system/emby-watch.service > /dev/null << 'EOF'
[Unit]
Description=Emby BadHttp Monitor Service
After=network.target

[Service]
Type=simple
User=root
ExecStart=/usr/local/bin/emby-watch.sh
Restart=always
RestartSec=5
StandardOutput=journal
StandardError=journal

[Install]
WantedBy=multi-user.target
EOF

# ===========================
# 启动并开机自启
# ===========================
sudo systemctl daemon-reload
sudo systemctl enable --now emby-watch.service
sudo systemctl restart emby-watch.service

echo "=============================================="
echo "安装完成！"
echo "服务名：emby-watch.service"
echo "查看实时日志：journalctl -u emby-watch.service -f"
echo "白名单文件：/var/log/emby/emby_whitelist.txt"
echo "永久黑名单：/var/log/emby/emby_blacklist.txt"
echo "封禁日志：  /var/log/emby/emby-badhttp-block.log"
echo "=============================================="