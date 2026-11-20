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
    [ -z "$ip" ] && continue
    echo "===== 测试IP: $ip ====="

    # 过滤旧的image.tmdb.org，生成新hosts
    grep -v "image.tmdb.org" /etc/hosts > /tmp/hosts.tmp
    echo "$ip image.tmdb.org" >> /tmp/hosts.tmp
    # 重点修改：用重定向覆盖，替代cp
    cat /tmp/hosts.tmp > /etc/hosts

    # 验证解析是否生效
    echo "当前hosts解析验证："
    ping -c 1 image.tmdb.org

    wget -T 8 -t 1 --spider https://image.tmdb.org/t/p/original/j3EjlCTggdzrwmT0CpbBRT7RvSq.jpg
    if [ $? -eq 0 ];then
        echo "✅ 测试成功，已经写入hosts，生效IP：$ip"
        exit 0
    fi
    sleep 2
done < "$TMP_IP_FILE"

echo "⚠️ 远程IP列表全部测试完毕，无可用IP"
exit 1
