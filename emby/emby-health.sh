#!/bin/bash

# ===== emby1 =====
emby1_address="http://127.0.0.1:6908"
if ! curl --speed-time 10 --speed-limit 1 -sSf "$emby1_address/web/index.html" >/dev/null; then
    echo "[$(date '+%F %T')] Emby1 网络超时/无法访问，重启 Emby1"
    docker restart emby1
fi
emby1_mem=$(docker stats --no-stream --format '{{.MemPerc}}' emby1 | tr -d '%')
if awk -v m="$emby1_mem" 'BEGIN{exit !(m>65)}'; then
    echo "[$(date '+%F %T')] Emby1 内存占用 ${emby1_mem}%，已达到阈值 55%，重启 Emby1"
    docker restart emby1
fi

sleep 10

# ===== emby2 =====
emby2_address="http://127.0.0.1:6909"
if ! curl --speed-time 10 --speed-limit 1 -sSf "$emby2_address/web/index.html" >/dev/null; then
    echo "[$(date '+%F %T')] Emby2 网络超时/无法访问，重启 Emby2"
    docker restart emby2
fi
emby2_mem=$(docker stats --no-stream --format '{{.MemPerc}}' emby2 | tr -d '%')
if awk -v m="$emby2_mem" 'BEGIN{exit !(m>65)}'; then
    echo "[$(date '+%F %T')] Emby2 内存占用 ${emby2_mem}%，已达到阈值 55%，重启 Emby2"
    docker restart emby2
fi
