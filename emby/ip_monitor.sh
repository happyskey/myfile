#!/bin/sh
LOG="/var/log/nginx/access.log"
OUT="/data/custom/ip.txt"
TMP="/tmp/emby_ip.tmp"

touch "$OUT"
touch "$TMP"

# 用 tail -F 输出到 while 的同时，把 TMP 操作放在循环内部但用独立变量
tail -F "$LOG" | while read -r line; do
    reqtype=""
    ip=""
    logtime=""

    # 提取 reqtype、ip 和 logtime，避免多次调用 grep/cut
    if echo "$line" | grep -q "/emby/Items"; then
        reqtype="1000"
    elif echo "$line" | grep -q "/emby/Users/.*ShareLevel" && echo "$line" | grep -q "okhttp|Filmly|Yamby|EmbyCon"; then
        reqtype="1001"
    elif echo "$line" | grep -q "/emby/Users/.*ShareLevel"; then
        reqtype="1002"
    fi
    
    #1000  /emby/Items  
    #1001  /emby/Users/.*ShareLevel 且 含 okhttp/Filmly/Yamby
    #1002  /emby/Users/.*ShareLevel（前面已排除含关键词的）	

    [ -z "$reqtype" ] && continue

    # 根据 reqtype 设置阈值
    case "$reqtype" in
        1000) threshold=60 ;;
        1001) threshold=10 ;;
        1002) threshold=8 ;;
        *) threshold=14 ;;
    esac

    # 提取 IP 和时间戳，减少冗余操作
    ip=$(echo "$line" | cut -d' ' -f1)
    [ "$(echo "$ip" | grep -c "^192\.168\.1\.")" -gt 0 ] && continue  # 排除本地IP

    logtime=$(echo "$line" | awk -F'[][]' '{print $2}' | cut -d' ' -f1)

    # --- 关键改动：把 reqtype 加入 key，实现每秒每类型独立计数 ---
    key="$reqtype $ip $logtime"

    # 先写 TMP
    echo "$key" >> "$TMP"
    count=$(grep -c "^$key\$" "$TMP")

    # 保留最近 1000 行，用临时文件但避免管道问题
    TMP_TMP="/tmp/emby_ip.tmp.$$"
    tail -n 1000 "$TMP" > "$TMP_TMP" 2>/dev/null
    if [ -f "$TMP_TMP" ]; then
        mv "$TMP_TMP" "$TMP"
    fi

    # 当大于阈值时写入ip.txt 
    if [ "$count" -gt "$threshold" ]; then
        outline="$reqtype $ip $logtime"
        grep -q "^$outline\$" "$OUT" || echo "$outline" >> "$OUT"
    fi
done
