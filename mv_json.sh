#!/bin/bash
SEARCH_DIR="/mnt/disk/xiaoyadata/xiaoya/json/media/ISO"
DEST_PARENT="$1"

find "${SEARCH_DIR}" -type f -name "*-mediainfo.json" | while read -r jsonpath;do
    jsonname=$(basename "$jsonpath")
    foldername=${jsonname%-mediainfo.json}
    foldername=${foldername%'-'}
    destdir="${DEST_PARENT}/${foldername}"
    if [ -d "$destdir" ];then
        cp -v "$jsonpath" "$destdir/"
    else
        echo "跳过，目录不存在：$foldername"
    fi
done
