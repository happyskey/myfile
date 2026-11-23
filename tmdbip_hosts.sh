#!/bin/sh
REMOTE_IP_LIST="http://web.happyskey.top:8108/myfile/tmdb_ip.txt"
TMP_IP_FILE="/tmp/tmdb_ip.txt"
CONTAINER_name=$1 #容器名字（保留参数，但测试不再依赖 docker exec）

# ================= 测试图片路径 =================
IMG_PATH_ORIG="/t/p/original/j3EjlCTggdzrwmT0CpbBRT7RvSq.jpg"
IMG_PATH_THUMB="/t/p/w780/j3EjlCTggdzrwmT0CpbBRT7RvSq.jpg"

URL_PRIMARY_ORIG="https://image.tmdb.org${IMG_PATH_ORIG}"
URL_FALLBACK_ORIG="https://wsrv.nl/?url=https://image.tmdb.org${IMG_PATH_ORIG}"
URL_PRIMARY_THUMB="https://image.tmdb.org${IMG_PATH_THUMB}"
URL_FALLBACK_THUMB="https://wsrv.nl/?url=https://image.tmdb.org${IMG_PATH_THUMB}"

TMP_IMG_ORIG="/tmp/tmdb_test_orig.jpg"
TMP_IMG_THUMB="/tmp/tmdb_test_thumb.jpg"

# 获取 Emby 插件配置目录
emby_dir=$(dirname "$(docker inspect -f '{{range .Mounts}}{{if eq .Destination "/etc/nsswitch.conf"}}{{.Source}}{{end}}{{end}}' $CONTAINER_name)")
JSON_FILE="$emby_dir/config/plugins/configurations/Strm Assistant_MetadataEnhanceOptions.json"

echo "正在拉取远程IP列表: $REMOTE_IP_LIST"
wget -T 10 -t 2 -O "$TMP_IP_FILE" "$REMOTE_IP_LIST"
if [ $? -ne 0 ];then
    echo "❌ 获取远程IP文件失败，退出测试"
    exit 1
fi

if [ ! -f "$JSON_FILE" ]; then
    echo "⚠️ 警告: 找不到配置文件 $JSON_FILE，将仅测试不修改配置。"
fi

# ================= 测试函数（在本环境内直接 wget） =================
# 返回 0 表示成功（退出码 0 且文件大小 > 0）
test_url() {
    _url="$1"
    _tmp="$2"
    rm -f "$_tmp"
    wget -T 8 -t 1 -O "$_tmp" "$_url" >/dev/null 2>&1
    _res=$?
    _size=0
    [ -f "$_tmp" ] && _size=$(wc -c < "$_tmp")
    if [ $_res -eq 0 ] && [ "$_size" -gt 0 ]; then
        echo "OK $_size"
        return 0
    else
        echo "FAIL $_res $_size"
        return 1
    fi
}

while read -r ip
do
    ip=$(echo "$ip" | tr -d '\r' | sed 's/^[[:space:]]*//;s/[[:space:]]*$//')
    [ -z "$ip" ] && continue

    # 生成 hosts，重定向覆盖 /etc/hosts（和最初脚本一致）
    grep -v "image.tmdb.org" /etc/hosts > /tmp/hosts.tmp
    echo "$ip image.tmdb.org" >> /tmp/hosts.tmp
    cat /tmp/hosts.tmp > /etc/hosts

    # ================= 测试 original =================
    OUT_ORIG=$(test_url "$URL_PRIMARY_ORIG" "$TMP_IMG_ORIG")
    RES_ORIG=$?
    SIZE_ORIG=$(echo "$OUT_ORIG" | awk '{print $2}')

    # ================= 测试 w780 =================
    OUT_THUMB=$(test_url "$URL_PRIMARY_THUMB" "$TMP_IMG_THUMB")
    RES_THUMB=$?
    SIZE_THUMB=$(echo "$OUT_THUMB" | awk '{print $2}')

    # ================= 测试代理 original / w780 =================
    OUT_FB_ORIG=$(test_url "$URL_FALLBACK_ORIG" "$TMP_IMG_ORIG")
    RES_FB_ORIG=$?
    SIZE_FB_ORIG=$(echo "$OUT_FB_ORIG" | awk '{print $2}')

    OUT_FB_THUMB=$(test_url "$URL_FALLBACK_THUMB" "$TMP_IMG_THUMB")
    RES_FB_THUMB=$?
    SIZE_FB_THUMB=$(echo "$OUT_FB_THUMB" | awk '{print $2}')

    rm -f "$TMP_IMG_ORIG" "$TMP_IMG_THUMB"

    # ================= 打印结果 =================
    echo "--------------------------------------------------"
    echo "▶ 当前测试 IP: $ip"
    [ $RES_ORIG -eq 0 ] && echo "  [✅ 成功] image.tmdb.org original (大小: ${SIZE_ORIG:-0}B)" || echo "  [❌ 失败] image.tmdb.org original (大小: ${SIZE_ORIG:-0}B)"
    [ $RES_THUMB -eq 0 ] && echo "  [✅ 成功] image.tmdb.org w780    (大小: ${SIZE_THUMB:-0}B)" || echo "  [❌ 失败] image.tmdb.org w780    (大小: ${SIZE_THUMB:-0}B)"
    [ $RES_FB_ORIG -eq 0 ] && echo "  [✅ 成功] wsrv.nl original       (大小: ${SIZE_FB_ORIG:-0}B)" || echo "  [❌ 失败] wsrv.nl original       (大小: ${SIZE_FB_ORIG:-0}B)"
    [ $RES_FB_THUMB -eq 0 ] && echo "  [✅ 成功] wsrv.nl w780          (大小: ${SIZE_FB_THUMB:-0}B)" || echo "  [❌ 失败] wsrv.nl w780          (大小: ${SIZE_FB_THUMB:-0}B)"

    # ================= 判定逻辑 =================
    # 直连：original 和 w780 都通过
    if [ $RES_ORIG -eq 0 ] && [ $RES_THUMB -eq 0 ]; then
        echo "🎉 直连完全可用（original + w780 均通过）！生效 IP: $ip"
        if [ -f "$JSON_FILE" ]; then
            sed -i -E 's|("AltMovieDbImageUrl"[[:space:]]*:[[:space:]]*)"[^"]*"|\1"https://image.tmdb.org"|' "$JSON_FILE"
            echo "✅ 配置文件已修改为直连模式 (https://image.tmdb.org)"
        fi
        exit 0
    fi

    # 代理：original 和 w780 都通过
    if [ $RES_FB_ORIG -eq 0 ] && [ $RES_FB_THUMB -eq 0 ]; then
        echo "🎉 直连不满足，但代理完全可用（original + w780 均通过）！生效 IP: $ip"
        if [ -f "$JSON_FILE" ]; then
            sed -i -E 's|("AltMovieDbImageUrl"[[:space:]]*:[[:space:]]*)"[^"]*"|\1"https:\/\/wsrv.nl\/?url=https:\/\/image.tmdb.org"|' "$JSON_FILE"
            echo "✅ 配置文件已修改为代理模式 (wsrv.nl)"
        fi
        exit 0
    fi

    if [ $RES_ORIG -eq 0 ] || [ $RES_THUMB -eq 0 ]; then
        echo "⚠️ 该 IP 部分可用（original/w780 未同时通过），继续测试下一个 IP"
    fi

done < "$TMP_IP_FILE"

echo "--------------------------------------------------"
echo "⚠️ 远程IP列表测试完毕，无同时满足 original + w780 的可用 IP!"
exit 1
