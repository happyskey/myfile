#!/bin/sh
root="$1"

find "$root" -type f \( -iname "*.jpg" -o -iname "*.png" \) -print0 |
while IFS= read -r -d '' f; do
    base=$(basename "$f" | tr 'A-Z' 'a-z')

    # 只取一次元数据
    meta=$(identify -format "%w %b" "$f" 2>/dev/null) || continue
    w=${meta%% *}
    size=${meta#* }
    [ -z "$w" ] && continue

    # 解析字节数（identify %b 返回如 "1.2MB"），这里改用 stat 更可靠
    bytes=$(stat -c %s "$f")
    ts=$(stat -c %Y "$f")

    target=""   # 目标宽度
    quality=""

    case "$base" in
        *folder.jpg|*poster.jpg|*cover.jpg)
            # 优先按宽度规则
            if [ "$w" -ge 1001 ]; then target=1000; quality=75; fi
            # 再叠加大小规则（取更严格者）
            if [ "$bytes" -gt 400000 ]; then
                target=1000; quality=70
            fi
            ;;
        *clearlogo.png|*logo.png)
            if [ "$w" -ge 1001 ]; then target=1000; fi
            ;;
        *.jpg)
            if [ "$w" -ge 2561 ]; then target=2560; quality=70; fi
            if [ "$bytes" -gt 400000 ]; then
                # 已设过 target 就保留，否则按 70% 缩放
                [ -z "$target" ] && quality=70
            fi
            ;;
        *.png)
            [ "$bytes" -gt 400000 ] && quality=70   # 用百分比缩放
            ;;
    esac

    # 决定是否处理
    if [ -n "$target" ] || [ -n "$quality" ]; then
        echo "处理：$f"
        if [ -n "$target" ]; then
            geom="${target}x"
        else
            geom="70%"
        fi
        if mogrify -resize "$geom" ${quality:+-quality "$quality"} "$f"; then
            touch -d "@$ts" "$f"
        fi
    fi
done
