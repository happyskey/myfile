#!/bin/bash
emby_address="http://127.0.0.1:6908"
curl --speed-time 10 --speed-limit 1 -sSf "$emby_address/web/index.html" >/dev/null || docker restart emby1
mem=$(docker stats --no-stream --format '{{.MemPerc}}' emby1 | tr -d '%')
awk -v m="$mem" 'BEGIN{exit !(m>55)}' && docker restart emby1

sleep 10

emby_address="http://127.0.0.1:6909"
curl --speed-time 10 --speed-limit 1 -sSf "$emby_address/web/index.html" >/dev/null || docker restart emby2
mem=$(docker stats --no-stream --format '{{.MemPerc}}' emby2 | tr -d '%')
awk -v m="$mem" 'BEGIN{exit !(m>55)}' && docker restart emby2
