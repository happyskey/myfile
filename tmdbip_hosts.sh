#!/bin/sh
REMOTE_IP_LIST="http://web.happyskey.top:8108/myfile/tmdb_ip.txt"
TMP_IP_FILE="/tmp/tmdb_ip.txt"

# 测试图片路径（第一个为直连，第二个为 wsrv.nl 代理）
IMG_PATH="/t/p/original/j3EjlCTggdzrwmT0CpbBRT7RvSq.jpg"
URL_PRIMARY="https://image.tmdb.org${IMG_PATH}"
URL_FALLBACK="https://wsrv.nl/?url=https://image.tmdb.org${IMG_PATH}"

echo "正在拉取远程IP列表: $REMOTE_IP_LIST"
wget -T 10 -t 2 -O "$TMP_IP_FILE" "$REMOTE_IP_LIST"
if [ $? -ne 0 ];then
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

    # ---------- 域名测试：image.tmdb.org 直连 ----------
    echo "域名：image.tmdb.org ，IP：$ip"
    wget -T 8 -t 1 --spider "$URL_PRIMARY" >/dev/null 2>&1
    if [ $? -eq 0 ];then
        echo "✅ 域名：image.tmdb.org测试成功，已写入hosts，生效IP：$ip"
        exit 0
    fi

    # ---------- 域名测试：wsrv.nl 代理 ----------
    echo "域名：wsrv.nl ，IP：$ip"
    wget -T 8 -t 1 --spider "$URL_FALLBACK" >/dev/null 2>&1
    if [ $? -eq 0 ];then
        echo "✅ 域名：wsrv.nl测试成功，已写入hosts，生效IP：$ip"
        exit 0
    fi
done < "$TMP_IP_FILE"

echo "⚠️ 远程IP列表测试完毕，无可用IP!"
exit 1
