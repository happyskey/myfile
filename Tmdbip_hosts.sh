#!/bin/sh
REMOTE_IP_LIST="http://web.happyskey.top:8108/myfile/tmdb_ip.txt"
TMP_IP_FILE="/tmp/tmdb_ip.txt"

# 下载远端ip列表
echo "正在拉取远程IP列表: $REMOTE_IP_LIST"
wget -T 10 -t 2 -O "$TMP_IP_FILE" "$REMOTE_IP_LIST"
if [ $? -ne 0 ];then
    echo "❌ 获取远程IP文件失败，退出测试"
    exit 1
fi

# 循环读取每一行IP
while read -r ip
do
    # 跳过空行
    [ -z "$ip" ] && continue
    echo "===== 测试IP: $ip ====="

    # 清理旧image.tmdb.org记录，写入临时hosts再cp覆盖，规避Resource busy
    grep -v "image.tmdb.org" /etc/hosts > /tmp/hosts.tmp
    echo "$ip image.tmdb.org" >> /tmp/hosts.tmp
    cp /tmp/hosts.tmp /etc/hosts

    # 验证当前解析
    ping -c 1 image.tmdb.org

    # busybox wget握手探测
    wget -T 8 -t 1 --spider https://image.tmdb.org/t/p/original/j3EjlCTggdzrwmT0CpbBRT7RvSq.jpg
    if [ $? -eq 0 ];then
        echo "✅ 测试成功，当前生效IP：$ip"
        exit 0
    fi
    sleep 2
done < "$TMP_IP_FILE"

echo "⚠️ 远程IP列表全部测试完毕，无可用IP"
exit 1
