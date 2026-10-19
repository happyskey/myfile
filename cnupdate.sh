#！/bin/sh

# 检测是否在终端运行
if [ -t 1 ]; then
    # 在终端运行
    INTERACTIVE=1
    DOCKER_EXEC="docker exec -it"
    ARIA2_COLOR="--enable-color=true"
else
    # 非终端运行（如 cron）
    INTERACTIVE=0
    DOCKER_EXEC="docker exec"
    ARIA2_COLOR="--enable-color=false"
fi

# 定义日志函数
INFO() { echo -e "\033[34m[INFO]\033[0m[$(date '+%Y-%m-%d %H:%M:%S')] $1"; }  # 绿色
WARN() { echo -e "\033[33m[WARN]\033[0m[$(date '+%Y-%m-%d %H:%M:%S')] $1"; }  # 黄色
ERROR() { echo -e "\033[31m[ERROR]\033[0m[$(date '+%Y-%m-%d %H:%M:%S')] $1"; } # 红色

docker_cdn=docker.sparkcr.cn

INFO "随机 5-60 秒开始执行..."
sleep_time=$((RANDOM % 56 + 5))
INFO "请等待 $sleep_time 秒..."
sleep "$sleep_time"

run_on_weekday() {
    local target_weekday=$1
    local command=$2
    local current_weekday=$(date +%u)  # 获取当前是星期几(1-7)

    # 判断今天是否是指定的星期
    if [[ $current_weekday -eq $target_weekday ]]; then
        INFO "今天是星期${target_weekday}，执行命令..."
        eval "$command"
    else
        INFO "今天是星期${current_weekday}，非指定执行日（星期${target_weekday}）"
    fi
}

configenv() {
    INFO 同步更新
	# 如果用户输入了参数，使用第一个参数作为 xiaoya_dir
	if [ -n "$1" ]; then
	  emby_dir="$1"
	else
		if [ -d "/data/emby" ]; then
			emby_dir="/data/emby"
			xiaoya_dir="/data"
		else
			emby_dir=$(docker inspect --format '{{ range .Mounts }}{{ .Source }}{{ println }}{{ end }}' emby | grep 'config$' | awk -F'/config' '{print $1}')
			xiaoya_dir=$(docker inspect --format '{{ range .Mounts }}{{ .Source }}{{ println }}{{ end }}' xiaoya | awk '/xiaoya$/')
            #兼容特殊情况
            if [ -z "$emby_dir" ]; then
                emby_dir=$(docker inspect --format '{{ range .Mounts }}{{ .Source }}{{ println }}{{ end }}' emby1 | grep 'config1$' | awk -F'/config' '{print $1}')
            fi

			if [ -z "$emby_dir" ]; then
			ERROR "错误: emby_dir 变量未定义或为空，无法继续执行脚本。"
			exit 1
			fi
		fi
	fi
	# 解压工具7z检测
	if command -v 7z >/dev/null; then
		INFO "已支持7z命令"
	else
		if docker ps -a --format '{{.Names}}' | grep -wq "zip"; then
			docker restart zip
			sleep 2
			INFO "zip容器已安装"
		else
			docker run -d --name zip --restart=always --net=host -v $emby_dir:/media -e LANG=C.UTF-8 $docker_cdn/xiaoyaliu/glue:latest
		fi
	fi
    mkdir -p "$emby_dir/xiaoya/json"
	INFO "xiaoya_dir目录: $xiaoya_dir"
	INFO "emby_dir目录: $emby_dir"
}

strmclear() {
    [ ! -d "$1" ] && { echo "目录 $1 不存在"; return 1; }
    cd "$1" || { echo "无法进入目录 $1"; return 1; }
    INFO() { echo "[$(date '+%Y-%m-%d %H:%M:%S')] $1"; }

    # ====================== 全平台通用：今天日期（YYYYMMDD）======================
    today=$(date +%Y%m%d)
    INFO "今天日期：$today"

    # ====================== 统计今天 strm（全平台最稳）======================
    strmcount=0
    while IFS= read -r file; do
        # 兼容所有系统：取文件日期 YYYYMMDD
        fdate=$(stat -c "%y" "$file" 2>/dev/null | cut -d' ' -f1 | tr -d -)
        [ -z "$fdate" ] && fdate=$(stat -t "%Y%m%d" "$file" 2>/dev/null)
        [ "$fdate" = "$today" ] && strmcount=$((strmcount + 1))
    done < <(find . -type f -name "*.strm" 2>/dev/null)

    # ====================== 清理非今天 strm ======================
    if [ "$strmcount" -gt 100 ]; then
        INFO "今日strm：$strmcount 个，开始清理旧文件..."
        
        while IFS= read -r file; do
            fdate=$(stat -c "%y" "$file" 2>/dev/null | cut -d' ' -f1 | tr -d -)
            [ -z "$fdate" ] && fdate=$(stat -t "%Y%m%d" "$file" 2>/dev/null)
            if [ "$fdate" != "$today" ]; then
                rm -f "$file"
                INFO "已删除：$file"
            fi
        done < <(find . -type f -name "*.strm" 2>/dev/null)
        
        INFO "旧 strm 文件已全部清理"
    else
        INFO "今日strm：$strmcount 个，无需清理"
    fi

    # ====================== 清理空目录 ======================
    find . -mindepth 1 -maxdepth 4 -type d 2>/dev/null | while read -r dir; do
        if ! find "$dir" -name "*.strm" 2>/dev/null | grep -q .; then
            INFO "删除空目录：$dir"
            rm -rf "$dir"
        fi
    done
}

# 兼容历史版本
115clear() {
	if [ ! -f "$xiaoya_dir/115_cookie.txt" ]; then
		if [ -d "$emby_dir/xiaoya/国产剧专属/电影A" ]; then
			INFO "开始清理TV资源..."
			mkdir -p "$emby_dir/xiaoya/国产剧专属/国产剧A"
			cp -rf "$emby_dir/xiaoya/每日更新/电视剧/国产剧"/* "$emby_dir/xiaoya/国产剧专属/国产剧A/"
			rm -rf $emby_dir/xiaoya/国产剧专属/国产剧A/115/
			
            INFO "开始清理Movie资源..."
			mkdir -p "$emby_dir/xiaoya/国产剧专属/电影A"
			cp -rf "$emby_dir/xiaoya/每日更新/电影"/* "$emby_dir/xiaoya/国产剧专属/电影A/"
            rm -rf $emby_dir/xiaoya/国产剧专属/电影A/115/

			# 删除没有 .strm 文件的目录
			find . -type d -exec sh -c 'find "$1" -type f -name "*.strm" | grep -q . || echo "$1"' sh {} \; | xargs -I {} rm -rf {}
		else
			WARN "新版本数据跳过此项"
            return 1
		fi
	else
		INFO "当前115网盘配置"
	fi
}

alidata() {
    local download_url="$1"    # 第一个参数：下载链接
    local zip_filename="$2"    # 第二个参数：下载的zip文件名
    local target_path="$3"     # 第三个参数：解压后的目标路径

    if [ -d "/data/emby" ]; then
        wget -O "$emby_dir/temp/$zip_filename" "$download_url"

        # 解压文件
        cd "$emby_dir/$target_path" && 7z x -bb1 -aoa -mmt=16 "$emby_dir/temp/$zip_filename"
        cd "$emby_dir/temp" && rm -rf "$zip_filename"
    else
        curl -fsSL -o "$emby_dir/temp/$zip_filename" "$download_url"
        
        # 解压并调用函数，并传递指定的路径清理
        if command -v 7z >/dev/null 2>&1; then
            cd $emby_dir/$target_path && 7z x -bb1 -aoa -mmt=16 $emby_dir/temp/$zip_filename
        else
            $DOCKER_EXEC zip /bin/sh -c "cd /media/$target_path && 7z x -bb1 -aoa -mmt=16 /media/temp/$zip_filename"
        fi
        $DOCKER_EXEC zip /bin/sh -c "cd /media/temp/ && rm -rf $zip_filename"
    fi
}

# 如果没有 curl，直接默认走海外源（最安全）
if ! command -v curl &> /dev/null; then
    hostaddr="http://web.happyskey.top:8108/"
else
    # 有 curl 才进行判断，默认走web，其余如超时|重置|空返回都走frp
    CONTENT=$(curl -fsSL --connect-timeout 2 --max-time 3 http://web.happyskey.top:8108/)
    if echo "$CONTENT" | grep -q "newstrm"; then
        hostaddr="http://web.happyskey.top:8108"
    else
        hostaddr="http://frp1.yytj.shop:8108"
    fi
fi

configenv #初始化环境
rm -rf "/data/emby/xiaoya/音乐/演唱会/BDrip" >/dev/null 2>&1
find "/data/emby/xiaoya/音乐/演唱会" -type f -name "*.strm" -exec grep -q "未分类" {} \; -delete
115clear #兼容历史清理115数据

# 下载最新strm并解压
alidata "${hostaddr}/newstrm.zip" "newstrm.zip" "xiaoya/国产剧专属"

# 清理非今天的strm数据
strmclear "${emby_dir%/}/xiaoya/国产剧专属/电视剧集"
strmclear "${emby_dir%/}/xiaoya/国产剧专属/六大合集华语"
strmclear "${emby_dir%/}/xiaoya/国产剧专属/六大合集欧美"
strmclear "${emby_dir%/}/xiaoya/国产剧专属/电影"
strmclear "${emby_dir%/}/xiaoya/国产剧专属/综艺"
strmclear "${emby_dir%/}/xiaoya/国产剧专属/和谐电影"
strmclear "${emby_dir%/}/xiaoya/国产剧专属/和谐剧集"
strmclear "${emby_dir%/}/xiaoya/国产剧专属/已完结的电视剧"
strmclear "${emby_dir%/}/xiaoya/国产剧专属/已完结剧集补剧"

if [ -d "/mnt/disk/xiaoyadata/xiaoya" ]; then
    #alidata "https://openlist.happyskey.top:46589/d/115/xiaoya/gcj_json.zip" "gcj_json.zip" "xiaoya/json/media" "false"
fi
