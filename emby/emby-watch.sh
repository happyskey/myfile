cat > /usr/local/bin/emby-watch.sh << 'EOF'
#!/bin/bash
# =====================================================
# 小雅Emby 终极根治版 2025 精准版（单库触发 + 双Emby + 防抖）
# 特点：新增 .strm 文件 → 只刷新对应库，不全库扫描
# =====================================================

medir_dir=/mnt/disk/xiaoyadata
# ========== 配置 ==========
PATHS=(
    "$medir_dir/xiaoya/每日更新/电影"
    "$medir_dir/xiaoya/每日更新/电视剧"
    "$medir_dir/xiaoya/每日更新/动漫剧场版"
    "$medir_dir/xiaoya/每日更新/动漫"
    "$medir_dir/xiaoya/纪录片（已刮削）"
    "$medir_dir/xiaoya/国产剧专属/电影"
    "$medir_dir/xiaoya/国产剧专属/电视剧集"
    "$medir_dir/xiaoya/strm"
    "$medir_dir/xiaoya/国产剧专属/综艺"
)

# 这里是每个库对应的真正 Emby Library ID（必须核对正确）
IDS=(118755 118860 1616971 1649163 775355 2835113 2832232 3549058 3113916)

API_KEY="887bd92fa1aa4938a34d968b9575ab74"
EMBY_URLS=("http://127.0.0.1:6908" "http://127.0.0.1:6909")

LOG="/var/log/emby-watch-ultimate.log"
LAST_TRIGGER_FILE="/tmp/emby-watch-last-trigger.log"
DEBOUNCE_SEC=10  # 库级防抖（秒）

# ========== 日志 ==========
log() { echo "[$(date '+%F %T')] $*" | tee -a "$LOG"; }

log "🚀 小雅Emby 精准版启动成功！监控 ${#PATHS[@]} 个路径，仅触发单库扫描"

# ========== 检查路径 ==========
for p in "${PATHS[@]}"; do
    [[ -d "$p" ]] || { log "❌ 路径不存在：$p"; exit 1; }
done

# ========== 防抖函数 ==========
should_trigger() {
    local key="$1"
    local now=$(date +%s)
    local last_time=$(grep -F "$key" "$LAST_TRIGGER_FILE" 2>/dev/null | awk '{print $2}')

    # 清理过期记录
    awk -v now="$now" -v maxage=$((DEBOUNCE_SEC*2)) '$2+0 >= now-maxage {print $0}' "$LAST_TRIGGER_FILE" 2>/dev/null > "${LAST_TRIGGER_FILE}.tmp"
    mv -f "${LAST_TRIGGER_FILE}.tmp" "$LAST_TRIGGER_FILE" 2>/dev/null

    if [[ -z "$last_time" || $((now - last_time)) -gt $DEBOUNCE_SEC ]]; then
        sed -i "/$key/d" "$LAST_TRIGGER_FILE" 2>/dev/null
        echo "$key $now" >> "$LAST_TRIGGER_FILE"
        return 0
    else
        return 1
    fi
}

# ========== 精准触发函数 ==========
trigger_emby_refresh() {
    local id="$1"
    for EMBY_URL in "${EMBY_URLS[@]}"; do
        # ✅ 使用 Library/RefreshItemsById 接口（只刷新该库）
		URL="$EMBY_URL/emby/Items/$id/Refresh?Recursive=true&api_key=$API_KEY"
        log "⚡ 单库刷新 → $URL"
        curl -s -X POST "$URL" >/dev/null &
    done
}

# ========== 核心监控 ==========
while true; do
    log "⚡ 开始 inotify 监控..."

    inotifywait -m -r -q --format '%w%f' -e create -e moved_to "${PATHS[@]}" 2>/dev/null |
    while read -r file; do
        [[ -f "$file" ]] || continue
        [[ "$file" == *.strm ]] || continue

        # 确定触发库 ID
        ID=""
        for i in "${!PATHS[@]}"; do
            if [[ "$file" == *"${PATHS[$i]}"* ]]; then
                ID="${IDS[$i]}"
                break
            fi
        done
        [[ -z "$ID" ]] && continue

        # 库级防抖
        if ! should_trigger "$ID"; then
            continue
        fi

        log "✨ 检测到新 strm 文件：$file"
        trigger_emby_refresh "$ID"
        sleep 0.3
    done

    log "⚠️ inotifywait 意外退出，3秒后重启..."
    sleep 3
done
EOF

chmod +x /usr/local/bin/emby-watch.sh

# ========== 依赖检查 ==========
if ! command -v inotifywait >/dev/null 2>&1; then
    echo "⚠️ 未检测到 inotifywait，正在安装 inotify-tools..."
    if command -v apt-get >/dev/null 2>&1; then
        apt-get update -y && apt-get install -y inotify-tools
    elif command -v yum >/dev/null 2>&1; then
        yum install -y inotify-tools
    elif command -v dnf >/dev/null 2>&1; then
        dnf install -y inotify-tools
    elif command -v apk >/dev/null 2>&1; then
        apk add --no-cache inotify-tools
    else
        echo "❌ 无法自动安装 inotify-tools，请手动安装后重试"
        exit 1
    fi
fi

# ========== 日志目录 ==========
mkdir -p "$(dirname /var/log/emby-watch-ultimate.log)"
touch /var/log/emby-watch-ultimate.log

# ========== systemd 服务 ==========
cat > /etc/systemd/system/emby-watch.service << 'EOF'
[Unit]
Description=小雅 Emby 新增 strm 精准单库刷新监控
After=network.target

[Service]
Type=simple
ExecStart=/usr/local/bin/emby-watch.sh
Restart=always
RestartSec=5
User=root
StandardOutput=journal
StandardError=journal

[Install]
WantedBy=multi-user.target
EOF

systemctl daemon-reload
systemctl restart emby-watch
systemctl enable emby-watch
journalctl -u emby-watch.service -f

echo 功能总结：
echo 1、实时监控 9 个指定路径下的新增 .strm 文件
echo 2、按路径精准匹配对应 Emby Library ID
echo 3、只刷新对应单库，不全库扫描
echo 4、双 Emby 实例（6908 / 6909）同时触发
echo 5、库级防抖 10 秒，避免频繁刷新
echo 6、inotifywait 意外退出自动 3 秒重启
echo 7、日志写入 /var/log/emby-watch-ultimate.log
