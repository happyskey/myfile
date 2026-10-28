#!/bin/bash

# 内存占用百分比
THRESHOLD=65

# ===== emby1 =====
emby1_address="http://127.0.0.1:6908"
emby1_ok=1

if ! curl --speed-time 10 --speed-limit 1 -sSf "$emby1_address/web/index.html" >/dev/null; then
    echo "[$(date '+%F %T')] emby1 网络超时/无法访问，重启 emby1"
    docker restart emby1
    emby1_ok=0
fi

emby1_mem=$(docker stats --no-stream --format '{{.MemPerc}}' emby1 | tr -d '%')
if awk -v m="$emby1_mem" 'BEGIN{exit !(m>'"$THRESHOLD"')}'; then
    echo "[$(date '+%F %T')] emby1 内存占用 ${emby1_mem}%，已达到阈值 ${THRESHOLD}%，重启 emby1"
    docker restart emby1
    emby1_ok=0
fi

[ "$emby1_ok" -eq 1 ] && echo "[$(date '+%F %T')] emby1 当前健康（内存 ${emby1_mem}%）"

sleep 10

# ===== emby2 =====
emby2_address="http://127.0.0.1:6909"
emby2_ok=1

if ! curl --speed-time 10 --speed-limit 1 -sSf "$emby2_address/web/index.html" >/dev/null; then
    echo "[$(date '+%F %T')] emby2 网络超时/无法访问，重启 emby2"
    docker restart emby2
    emby2_ok=0
fi

emby2_mem=$(docker stats --no-stream --format '{{.MemPerc}}' emby2 | tr -d '%')
if awk -v m="$emby2_mem" 'BEGIN{exit !(m>'"$THRESHOLD"')}'; then
    echo "[$(date '+%F %T')] emby2 内存占用 ${emby2_mem}%，已达到阈值 ${THRESHOLD}%，重启 emby2"
    docker restart emby2
    emby2_ok=0
fi

[ "$emby2_ok" -eq 1 ] && echo "[$(date '+%F %T')] emby2 当前健康（内存 ${emby2_mem}%）"
