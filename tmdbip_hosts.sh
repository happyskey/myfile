#!/bin/sh
REMOTE_IP_LIST="http://web.happyskey.top:8108/myfile/tmdb_ip.txt"
TMP_IP_FILE="/tmp/tmdb_ip.txt"

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

    # 静默测试，stdout/stderr全部丢到空设备
    ping -c 1 image.tmdb.org >/dev/null 2>&1
    wget -T 8 -t 1 --spider https://image.tmdb.org/t/p/original/j3EjlCTggdzrwmT0CpbBRT7RvSq.jpg >/dev/null 2>&1
    if [ $? -eq 0 ];then
        echo "✅ 测试成功，已经写入hosts，生效IP：$ip"
        exit 0
    else
        echo "❌ 测试失败，IP：$ip"
    fi
done < "$TMP_IP_FILE"

echo "⚠️ 远程IP列表测试完毕，无可用IP!"
exit 1
