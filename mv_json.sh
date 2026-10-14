#!/bin/bash
SEARCH_DIR="/源json目录"
DEST_PARENT="/影片库父目录"

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