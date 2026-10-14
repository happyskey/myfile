#!/bin/bash
SEARCH_DIR="/mnt/disk/xiaoyadata/xiaoya/json/media/ISO"
DEST_PARENT="$1"

if [ -z "${DEST_PARENT}" ] || [ ! -d "${DEST_PARENT}" ]; then
    echo "用法: $0 目标影片库根目录"
    echo "示例: $0 /mnt/media/movie"
    exit 1
fi

find "${SEARCH_DIR}" -type f -name "*-mediainfo.json" | while read -r jsonpath;do
    jsonname=$(basename "$jsonpath")
    foldername=${jsonname%-mediainfo.json}
    foldername=${foldername%'-'}

    # 递归在DEST_PARENT下查找完全匹配名称的目录，取第一个匹配
    destdir=$(find "${DEST_PARENT}" -type d -name "${foldername}" | head -n1)

    if [ -n "${destdir}" ] && [ -d "${destdir}" ];then
        cp -v "$jsonpath" "$destdir/"
    else
        echo "跳过，未递归找到目录：$foldername"
    fi
done
