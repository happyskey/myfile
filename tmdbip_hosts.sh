#!/bin/sh
REMOTE_IP_LIST="http://web.happyskey.top:8108/myfile/tmdb_ip.txt"
TMP_IP_FILE="/tmp/tmdb_ip.txt"

# 测试图片路径
IMG_PATH="/t/p/original/j3EjlCTggdzrwmT0CpbBRT7RvSq.jpg"
URL_PRIMARY="https://image.tmdb.org${IMG_PATH}"
URL_FALLBACK="https://wsrv.nl/?url=https://image.tmdb.org${IMG_PATH}"

# ================= 动态获取所有匹配的 Emby 容器 =================
CONTAINERS=$(docker ps --format '{{.Names}}' | grep -E '^(emby|embyserver)$')

if [ -z "$CONTAINERS" ]; then
    echo "❌ 未找到 emby 或 embyserver 容器，退出。"
    exit 1
fi

echo "✅ 检测到以下容器:"
echo "$CONTAINERS" | while read -r cname; do echo "   - $cname"; done

# 定义一个函数：根据容器名修改对应的配置文件并重启
update_emby_config() {
    local target_url="$1"
    local c_name
    local success_count=0
    local need_restart_list=""

    for c_name in $CONTAINERS; do
        # 获取该容器的挂载路径
        local c_dir=$(dirname "$(docker inspect -f '{{range .Mounts}}{{if eq .Destination "/etc/nsswitch.conf"}}{{.Source}}{{end}}{{end}}' "$c_name")")
        local c_json="$c_dir/config/plugins/configurations/Strm Assistant_MetadataEnhanceOptions.json"

        if [ -f "$c_json" ]; then
            # 使用 | 作为分隔符，避免 URL 中的 / 产生转义问题
            sed -i -E "s|(\"AltMovieDbImageUrl\"[[:space:]]*:[[:space:]]*)\"[^\"]*\"|\1\"$target_url\"|" "$c_json"
            echo "  ✅ [$c_name] 配置已修改为: $target_url"
            success_count=$((success_count + 1))
            need_restart_list="$need_restart_list $c_name"
        else
            echo "  ⚠️ [$c_name] 未找到配置文件，跳过: $c_json"
        fi
    done

    # ================= 执行重启操作 =================
    if [ -n "$need_restart_list" ]; then
        echo "▶ 正在重启受影响的容器: $need_restart_list"
        for c_name in $need_restart_list; do
            echo "  🔄 正在重启容器: $c_name ..."
            docker restart "$c_name"
            if [ $? -eq 0 ]; then
                echo "  ✅ [$c_name] 重启成功"
            else
                echo "  ❌ [$c_name] 重启失败，请手动检查"
            fi
        done
    fi
    
    return $success_count
}

echo "正在拉取远程IP列表: $REMOTE_IP_LIST"
wget -T 10 -t 2 -O "$TMP_IP_FILE" "$REMOTE_IP_LIST"
if [ $? -ne 0 ]; then
    echo "❌ 获取远程IP文件失败，退出测试"
    exit 1
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
    wget -T 8 -t 1 --spider "$URL_PRIMARY" >/dev/null 2>&1
    RES_PRIMARY=$?

    wget -T 8 -t 1 --spider "$URL_FALLBACK" >/dev/null 2>&1
    RES_FALLBACK=$?

    # ================= 打印结果 =================
    echo "--------------------------------------------------"
    echo "▶ 当前测试 IP: $ip"
    [ $RES_PRIMARY -eq 0 ] && echo "  [✅ 成功] image.tmdb.org 直连" || echo "  [❌ 失败] image.tmdb.org 直连"
    [ $RES_FALLBACK -eq 0 ] && echo "  [✅ 成功] wsrv.nl 代理" || echo "  [❌ 失败] wsrv.nl 代理"

    # ================= 逻辑判断与配置修改 =================
    
    # 1. 优先判断直连
    if [ $RES_PRIMARY -eq 0 ]; then
        echo "🎉 直连成功！生效 IP: $ip"
        update_emby_config "https://image.tmdb.org"
        exit 0
    fi

    # 2. 如果直连失败，再判断代理是否成功
    if [ $RES_FALLBACK -eq 0 ]; then
        echo "🎉 直连失败，但代理成功！生效 IP: $ip"
        update_emby_config "https:\/\/wsrv.nl\/?url=https:\/\/image.tmdb.org"
        exit 0
    fi

done < "$TMP_IP_FILE"

echo "--------------------------------------------------"
echo "⚠️ 远程IP列表测试完毕，无可用IP!"
exit 1
