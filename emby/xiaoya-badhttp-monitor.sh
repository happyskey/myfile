# 下载脚本
sudo tee /usr/local/bin/xiaoya-badhttp-monitor.sh > /dev/null <<'EOF'
#!/bin/bash

BASE_DIR="/mnt/disk"
LOG_FILE="/var/log/xiaoya/ip_block.log"
BLACKLIST_FILE="/var/log/xiaoya/blacklist.txt"

# ===========================
# 启动前清空 DOCKER-USER 中旧封禁 IP
# ===========================
iptables -S DOCKER-USER | grep -E "^-A DOCKER-USER -s " | while read -r line; do
    ip=$(echo "$line" | awk '{print $4}')
    iptables -D DOCKER-USER -s "$ip" -j DROP 2>/dev/null
    echo "$(date '+%Y-%m-%d %H:%M:%S') 清除旧封禁 IP: $ip" >> "$LOG_FILE"
done

declare -A banned_ips
declare -A last_seen_second
declare -A last_line

# ===========================
# 查找所有 custom/ip.txt 文件
# ===========================
IP_FILES=()
while IFS= read -r f; do
    [[ -f "$f" ]] && IP_FILES+=("$f")
done < <(find "$BASE_DIR" -type f -path "*/custom/ip.txt")

[[ ${#IP_FILES[@]} -eq 0 ]] && { echo "没有找到 ip.txt 文件"; exit 1; }

# 初始化每个文件行号
for f in "${IP_FILES[@]}"; do
    last_line["$f"]=$(wc -l < "$f")
done

# ===========================
# 黑名单线程（原逻辑保持不变）
# ===========================
if [[ -f "$BLACKLIST_FILE" ]]; then
(
    declare -A applied_blacklist

    while true; do
        mapfile -t blist < <(sed 's/^[[:space:]]*//;s/[[:space:]]*$//' "$BLACKLIST_FILE" | grep -v '^$')

        for ip in "${blist[@]}"; do
            [[ -z "$ip" ]] && continue
            if ! [[ $ip =~ ^([0-9]{1,3}\.){3}[0-9]{1,3}$ ]]; then
                continue
            fi

            if [[ -z "${applied_blacklist[$ip]}" ]]; then
                iptables -C DOCKER-USER -s "$ip" -j DROP 2>/dev/null
                if [[ $? -ne 0 ]]; then
                    iptables -I DOCKER-USER 1 -s "$ip" -j DROP
                    echo "$(date '+%Y-%m-%d %H:%M:%S') [黑名单] 永久封禁 $ip" >> "$LOG_FILE"
                fi
                applied_blacklist[$ip]=1
            fi
        done

        for ip in "${!applied_blacklist[@]}"; do
            if ! printf '%s\n' "${blist[@]}" | grep -qx "$ip"; then
                iptables -C DOCKER-USER -s "$ip" -j DROP 2>/dev/null
                if [[ $? -eq 0 ]]; then
                    iptables -D DOCKER-USER -s "$ip" -j DROP
                    echo "$(date '+%Y-%m-%d %H:%M:%S') [黑名单] 取消封禁 $ip" >> "$LOG_FILE"
                fi
                unset applied_blacklist["$ip"]
            fi
        done

        sleep 5
    done
) &
fi

# ===========================
# 定义小时段+ID独立封禁秒数映射
# ===========================
declare -A ID_HOUR_BANTIME
for h in {0..7}; do
    ID_HOUR_BANTIME["1000,$h"]=1
    ID_HOUR_BANTIME["1001,$h"]=10
    ID_HOUR_BANTIME["1002,$h"]=2
done
for h in {8..18}; do
    ID_HOUR_BANTIME["1000,$h"]=1
    ID_HOUR_BANTIME["1001,$h"]=10
    ID_HOUR_BANTIME["1002,$h"]=5
done
for h in {19..23}; do
    ID_HOUR_BANTIME["1000,$h"]=2
    ID_HOUR_BANTIME["1001,$h"]=15
    ID_HOUR_BANTIME["1002,$h"]=8
done

# ===========================
# 增量处理函数
# ===========================
process_file() {
    local f="$1"
    local total_lines
    total_lines=$(wc -l < "$f")
    local start_line=$(( last_line["$f"] + 1 ))
    [[ $start_line -le 0 ]] && start_line=1

    if [[ $start_line -le $total_lines ]]; then
        tail -n +"$start_line" "$f" | while read -r line; do
            [[ -z "$line" ]] && continue

            reason_id=$(echo "$line" | awk '{print $1}')
            ip=$(echo "$line" | awk '{print $2}')
            timestr=$(echo "$line" | awk '{print $3}')

            [[ -z "$reason_id" || -z "$ip" || -z "$timestr" ]] && continue
            [[ ! "$reason_id" =~ ^[0-9]+$ ]] && continue
            [[ ! $ip =~ ^([0-9]{1,3}\.){3}[0-9]{1,3}$ ]] && continue

            now=$(date -d "$timestr" +%s 2>/dev/null)
            [[ -z "$now" ]] && now=$(date +%s)

            # 1秒内重复忽略
            if [[ "${last_seen_second[$ip]}" == "$now" ]]; then
                continue
            fi
            last_seen_second[$ip]=$now

            # 已封禁且未到解封时间 → 跳过
            if [[ -n "${banned_ips[$ip]}" && "${banned_ips[$ip]}" -gt "$now" ]]; then
                continue
            fi

            hour=$(date +%H)
            BANTIME="${ID_HOUR_BANTIME["$reason_id,$hour"]}"
            [[ -z "$BANTIME" || "$BANTIME" -le 0 ]] && continue

            # 封禁
            iptables -I DOCKER-USER -s "$ip" -j DROP
            banned_ips[$ip]=$(( now + BANTIME ))
            echo "$(date '+%Y-%m-%d %H:%M:%S') 封禁 IP: $ip (ID:$reason_id) 封禁 ${BANTIME}s" | tee -a "$LOG_FILE"

            # 解封
            (
                sleep "$BANTIME"
                iptables -D DOCKER-USER -s "$ip" -j DROP
                echo "$(date '+%Y-%m-%d %H:%M:%S') 解封 IP: $ip (ID:$reason_id)" | tee -a "$LOG_FILE"
                unset banned_ips["$ip"]
            ) &
        done
    fi
    last_line["$f"]=$total_lines
}

# ===========================
# 监控文件变化，增量处理
# ===========================
while true; do
    if [[ ${#IP_FILES[@]} -eq 0 ]]; then
        sleep 1
        continue
    fi

    # inotify 等待任意文件修改
    inotifywait -e modify "${IP_FILES[@]}" >/dev/null 2>&1

    # 处理被修改的文件
    for f in "${IP_FILES[@]}"; do
        process_file "$f"
    done
done
EOF

sudo chmod +x /usr/local/bin/xiaoya-badhttp-monitor.sh

# 创建 systemd 服务
sudo tee /etc/systemd/system/xiaoya-badhttp-monitor.service > /dev/null <<'EOF'
[Unit]
Description=Xiaoya BadHttp Monitor Service
After=network.target

[Service]
Type=simple
User=root
ExecStart=/usr/local/bin/xiaoya-badhttp-monitor.sh
Restart=always
RestartSec=5
# 保证日志输出到 journal
StandardOutput=journal
StandardError=journal

[Install]
WantedBy=multi-user.target
EOF

# 启动服务并开机自启
systemctl daemon-reload
systemctl enable --now xiaoya-badhttp-monitor.service
systemctl restart xiaoya-badhttp-monitor.service
echo "journalctl -u xiaoya-badhttp-monitor.service -f"