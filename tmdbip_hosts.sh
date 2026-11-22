#!/bin/sh
REMOTE_IP_LIST="http://web.happyskey.top:8108/myfile/tmdb_ip.txt"
TMP_IP_FILE="/tmp/tmdb_ip.txt"
CONTAINER_name=$1 #容器名字

# 测试图片路径
IMG_PATH="/t/p/original/j3EjlCTggdzrwmT0CpbBRT7RvSq.jpg"
URL_PRIMARY="https://image.tmdb.org${IMG_PATH}"
URL_FALLBACK="https://wsrv.nl/?url=https://image.tmdb.org${IMG_PATH}"

# 获取 Emby 插件配置目录
emby_dir=$(dirname "$(docker inspect -f '{{range .Mounts}}{{if eq .Destination "/etc/nsswitch.conf"}}{{.Source}}{{end}}{{end}}' $CONTAINER_name)")
JSON_FILE="$emby_dir/config/plugins/configurations/Strm Assistant_MetadataEnhanceOptions.json"

echo "正在拉取远程IP列表: $REMOTE_IP_LIST"
wget -T 10 -t 2 -O "$TMP_IP_FILE" "$REMOTE_IP_LIST"
if [ $? -ne 0 ];then
    echo "❌ 获取远程IP文件失败，退出测试"
    exit 1
fi

# 检查配置文件是否存在
if [ ! -f "$JSON_FILE" ]; then
    echo "⚠️ 警告: 找不到配置文件 $JSON_FILE，将仅测试不修改配置。"
fi

while read -r ip
do
    # 去掉回车和首尾空白
    ip=$(echo "$ip" | tr -d '\r' | sed 's/^[[:space:]]*//;s/[[:space:]]*$//')
    [ -z "$ip" ] && continue

    # 生成hosts，重定向覆盖docker /etc/hosts
    grep -v "image.tmdb.org" /etc/hosts > /tmp/hosts.tmp
    echo "$ip image.tmdb.org" >> /tmp/hosts.tmp
    cat /tmp/hosts.tmp > /etc/hosts

    # ================= 开始测试 =================
    wget -T 8 -t 1 -O /dev/null "$URL_PRIMARY" >/dev/null 2>&1
    RES_PRIMARY=$?

    wget -T 8 -t 1 -O /dev/null "$URL_FALLBACK" >/dev/null 2>&1
    RES_FALLBACK=$?
    
    # ================= 打印结果 =================
    echo "--------------------------------------------------"
    echo "▶ 当前测试 IP: $ip"
    [ $RES_PRIMARY -eq 0 ] && echo "  [✅ 成功] image.tmdb.org 直连" || echo "  [❌ 失败] image.tmdb.org 直连"
    [ $RES_FALLBACK -eq 0 ] && echo "  [✅ 成功] wsrv.nl 代理" || echo "  [❌ 失败] wsrv.nl 代理"
    
    # 1. 优先判断直连
    if [ $RES_PRIMARY -eq 0 ]; then
        echo "🎉 直连成功！生效 IP: $ip"
        if [ -f "$JSON_FILE" ]; then
            sed -i -E 's|("AltMovieDbImageUrl"[[:space:]]*:[[:space:]]*)"[^"]*"|\1"https://image.tmdb.org"|' "$JSON_FILE"
            echo "✅ 配置文件已修改为直连模式 (https://image.tmdb.org)"
        fi
        exit 0
    fi

    # 2. 如果直连失败，再判断代理是否成功
    if [ $RES_FALLBACK -eq 0 ]; then
        echo "🎉 直连失败，但代理成功！生效 IP: $ip"
        if [ -f "$JSON_FILE" ]; then
            sed -i -E 's|("AltMovieDbImageUrl"[[:space:]]*:[[:space:]]*)"[^"]*"|\1"https:\/\/wsrv.nl\/?url=https:\/\/image.tmdb.org"|' "$JSON_FILE"
            echo "✅ 配置文件已修改为代理模式 (wsrv.nl)"
        fi
        exit 0
    fi

done < "$TMP_IP_FILE"

echo "--------------------------------------------------"
echo "⚠️ 远程IP列表测试完毕，无可用IP!"
exit 1
