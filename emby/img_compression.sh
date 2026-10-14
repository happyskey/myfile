#!/bin/sh
#4K JPG → 2K / 70%
find $1 -type f -iname "*.jpg" -exec sh -c 'for f; do w=$(identify -format "%w" "$f" 2>/dev/null); if [ -n "$w" ] && [ "$w" -ge 2561 ]; then ts=$(stat -c %Y "$f"); echo "处理：$f"; if mogrify -resize 2560x -quality 70 "$f"; then touch -d "@$ts" "$f"; fi; fi; done' sh {} +

#指定图片（folder/poster/cover）宽≥1001 压到1000px
find $1 -type f \( -iname "*folder.jpg" -o -iname "*poster.jpg" -o -iname "*cover.jpg" \) -exec sh -c 'for f; do w=$(identify -format "%w" "$f" 2>/dev/null); if [ -n "$w" ] && [ "$w" -ge 1001 ]; then ts=$(stat -c %Y "$f"); echo "处理：$f"; if mogrify -resize 1000x -quality 75 "$f"; then touch -d "@$ts" "$f"; fi; fi; done' sh {} +

#PNG（clearlogo/logo）缩放到 1000px
find $1 -type f \( -iname "clearlogo.png" -o -iname "logo.png" \) -print0 | while IFS= read -r -d '' f; do w=$(identify -format "%w" "$f" 2>/dev/null); if [ -n "$w" ] && [ "$w" -ge 1001 ]; then ts=$(stat -c %Y "$f"); echo "处理：$f"; if convert "$f" -resize 1000x -define png:color-type=6 "$f"; then touch -d "@$ts" "$f"; fi; fi; done

#大于 400 KB 的指定 JPG 文件（folder/poster/cover）
find $1 -type f \( -iname "*folder.jpg" -o -iname "*poster.jpg" -o -iname "*cover.jpg" \) -exec sh -c 'for f; do s=$(stat -c %s "$f"); if [ "$s" -gt 400000 ]; then ts=$(stat -c %Y "$f"); echo "处理中：$f"; mogrify -resize 1000x -quality 70 "$f" && touch -d "@$ts" "$f"; fi; done' sh {} +

#大于 400 KB JPG → 缩放 70%
find $1 -type f -iname "*.jpg" -exec sh -c 'for f; do s=$(stat -c %s "$f"); if [ "$s" -gt 400000 ]; then ts=$(stat -c %Y "$f"); echo "处理中：$f"; mogrify -resize 70% "$f" && touch -d "@$ts" "$f"; fi; done' sh {} +

#大于 400 KB PNG → 缩放 70%
find $1 -type f -iname "*.png" -print0 | while IFS= read -r -d '' f; do s=$(stat -c %s "$f"); if [ "$s" -gt 400000 ]; then ts=$(stat -c %Y "$f"); echo "处理：$f"; if convert "$f" -resize 70% -define png:color-type=6 "$f"; then touch -d "@$ts" "$f"; fi; fi; done
