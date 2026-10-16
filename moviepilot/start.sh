#!/bin/bash
# 启动 rclone 后台挂载
rclone mount MP: /media/yunpan --daemon --vfs-cache-mode writes --allow-other --allow-non-empty >>/tmp/rclone.log 2>&1 &

# 继续执行官方原入口（保留 MoviePilot 主进程）
exec /entrypoint.sh "$@"
