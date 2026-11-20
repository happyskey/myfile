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

    # ================= 开始测试 =================
    # 1. 测试 image.tmdb.org 直连
    wget -T 8 -t 1 --spider "$URL_PRIMARY" >/dev/null 2>&1
    RES_PRIMARY=$?

    # 2. 测试 wsrv.nl 代理
    wget -T 8 -t 1 --spider "$URL_FALLBACK" >/dev/null 2>&1
    RES_FALLBACK=$?

    # ================= 打印结果 =================
    echo "--------------------------------------------------"
    echo "▶ 当前测试 IP: $ip"
    
    # 格式化输出 image.tmdb.org 结果
    if [ $RES_PRIMARY -eq 0 ]; then
        echo "  [✅ 成功] image.tmdb.org 直连"
    else
        echo "  [❌ 失败] image.tmdb.org 直连"
    fi

    # 格式化输出 wsrv.nl 结果
    if [ $RES_FALLBACK -eq 0 ]; then
        echo "  [✅ 成功] wsrv.nl 代理"
    else
        echo "  [❌ 失败] wsrv.nl 代理"
    fi

    # ================= 判断是否退出 =================
    # 只要直连成功，就说明这个IP是可用的，写入hosts并退出
    if [ $RES_PRIMARY -eq 0 ]; then
        echo "--------------------------------------------------"
        echo "🎉 找到可用IP: $ip (直连成功)，已保留在 /etc/hosts 中，脚本退出。"
        exit 0
    fi
    
    # 如果直连失败，但你希望代理成功也算成功，可以把下面的注释打开：
    # if [ $RES_FALLBACK -eq 0 ]; then
    #     echo "--------------------------------------------------"
    #     echo "🎉 找到可用IP: $ip (直连失败，但代理成功)，脚本退出。"
    #     exit 0
    # fi

done < "$TMP_IP_FILE"

echo "--------------------------------------------------"
echo "⚠️ 远程IP列表测试完毕，无可用IP!"
exit 1
