#!/bin/sh

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

xiaoya_dir=$(docker inspect -f '{{range .Mounts}}{{if eq .Destination "/data"}}{{.Source}}{{end}}{{end}}' "xiaoya" 2>/dev/null)
emby_dir=$(dirname "$(docker inspect -f '{{range .Mounts}}{{if eq .Destination "/etc/nsswitch.conf"}}{{.Source}}{{end}}{{end}}' emby)")

download_file() {
    local dst="$1"
    local url="$2"
    local chmod_exec="$3" # 传1代表需要chmod +x

    local tmp="${dst}.tmp"
    wget -q -O "$tmp" "$url"
    if [ $? -ne 0 ]; then
        rm -f "$tmp"
        ERROR "下载失败: $url"
        return 1
    fi
    mv "$tmp" "$dst"
    if [ "$chmod_exec" = "1" ]; then
        chmod +x "$dst"
    fi
    INFO "更新成功: $dst"
    return 0
}

if [ -n "$xiaoya_dir" ]; then
	INFO xiaoya_dir目录：$xiaoya_dir
	download_file "${xiaoya_dir}/update_data.sh" http://web.happyskey.top:8108/myfile/update_data.sh 1 || return 1
    download_file "${xiaoya_dir}/cnupdate.sh" http://web.happyskey.top:8108/myfile/cnupdate.sh 1 || return 1
    download_file "${xiaoya_dir}/alishare_list.txt" http://web.happyskey.top:8108/myfile/alishare_list.txt 0 || return 1
    download_file "${xiaoya_dir}/115share_list.txt" http://web.happyskey.top:8108/myfile/115share_list.txt 0 || return 1
fi

if [ -n "$emby_dir" ]; then
	INFO emby_dir目录：$emby_dir
	download_file "${emby_dir}/xiaoya/pathlib.txt" http://web.happyskey.top:8108/myfile/pathlib.txt 0 || return 1
fi

update_xiaoya() {
    local docker_cdn1="$1"
    local docker_cdn2="$2"
    local container_name="xiaoya"
    local container_images="xiaoyaliu/alist:latest"
    local current_image
    current_image=$(docker inspect --format '{{.Config.Image}}' "$container_name" 2>/dev/null || true)

    if [ "$current_image" = "${docker_cdn1}/${container_images}" ]; then
        if ! docker image inspect "${docker_cdn2}/${container_images}" >/dev/null 2>&1; then
            echo "开始拉取镜像: ${docker_cdn2}/${container_images}"
            docker pull "${docker_cdn2}/${container_images}"
            if ! docker image inspect "${docker_cdn2}/${container_images}" >/dev/null 2>&1; then
                ERROR "ERROR: 镜像拉取失败 ${docker_cdn2}/${container_images}"
                return 1
            fi

            docker stop "$container_name" 2>/dev/null || true
            docker rm "$container_name" 2>/dev/null || true
            docker rmi "${docker_cdn1}/${container_images}" 2>/dev/null || true
			docker run -d --name=xiaoya --restart=always -p 5678:80 -p 2345:2345 -v $xiaoya_dir:/data -v $xiaoya_dir/data:/www/data -v $xiaoya_dir/update_data.sh:/update_data.sh $docker_cdn2/xiaoyaliu/alist:latest
            INFO "${container_name} 容器重建完成"
        fi
    else
        INFO "$container_name容器: 当前镜像[$current_image]"
    fi
}

update_watchtower() {
    local docker_cdn1="$1"
    local docker_cdn2="$2"
    local container_name="watchtower"
    local container_images="nickfedor/watchtower:latest"

    local current_image
    current_image=$(docker inspect --format '{{.Config.Image}}' "$container_name" 2>/dev/null || true)

    if [ "$current_image" = "${docker_cdn1}/${container_images}" ]; then
        if ! docker image inspect "${docker_cdn2}/${container_images}" >/dev/null 2>&1; then
            echo "开始拉取镜像: ${docker_cdn2}/${container_images}"
            docker pull "${docker_cdn2}/${container_images}"
            if ! docker image inspect "${docker_cdn2}/${container_images}" >/dev/null 2>&1; then
                ERROR "ERROR: 镜像拉取失败 ${docker_cdn2}/${container_images}"
                return 1
            fi

            docker stop "$container_name" 2>/dev/null || true
            docker rm "$container_name" 2>/dev/null || true
            docker rmi "${docker_cdn1}/${container_images}" 2>/dev/null || true

			docker run -d --name="$container_name" --restart=always -v /var/run/docker.sock:/var/run/docker.sock -e TZ=Asia/Shanghai "${docker_cdn2}/${container_images}" --include‑stopped -c --schedule "0 0 7,15 * * *" xiaoya xiaoya‑emd aliyuntvtoken xiaoya‑115cleaner moviepilot‑v2
            INFO "${container_name} 容器重建完成"
        fi
    else
        INFO "$container_name容器: 当前镜像[$current_image]"
    fi
}

Tmdbtest() {
	content_type=$(curl -sLI "https://wsrv.nl/?url=https://image.tmdb.org/t/p/original/gFT9RJ92gPZvsIjbbkZtnktU6wj.jpg" | awk -F: 'tolower($1)=="content-type"{gsub(/\r/,"",$2); print $2}' | xargs)
    http_code=$(curl -L --head --silent -w "%{http_code}" "https://wsrv.nl/?url=https://image.tmdb.org/t/p/original/gFT9RJ92gPZvsIjbbkZtnktU6wj.jpg" | tail -n1)
    if [[ "$http_code" -eq 200 && "$content_type" == "image/jpeg" ]]; then
		sed -i -E 's|("AltMovieDbImageUrl"[[:space:]]*:[[:space:]]*)"[^"]*"|\1"https:\/\/wsrv.nl\/?url=https:\/\/image.tmdb.org"|' "$emby_dir/config/plugins/configurations/Strm Assistant_MetadataEnhanceOptions.json"
		INFO "图库CDN下载成功，状态码: $http_code, Content-Type: $content_type"
        INFO "Tmdb替换为wsrv.nl图库CDN"
    else
		sed -i -E 's|("AltMovieDbImageUrl"[[:space:]]*:[[:space:]]*)"[^"]*"|\1"https://image.tmdb.org"|' "$emby_dir/config/plugins/configurations/Strm Assistant_MetadataEnhanceOptions.json"
        INFO "图库CDN下载失败，状态码: $http_code, Content-Type: $content_type"
		INFO "切回Tmdb地址：image.tmdb.org"
    fi
	docker restart emby
}

# 计划任务修复
crontab -l | sed 's#https://gitee.com/happyskey/myfile/raw/master#http://web.happyskey.top:8108/myfile#g' | crontab -

# 清理失效媒体库
curl -X POST -H "X-Emby-Token: e825ed6f7f8f44ffa0563cddaddce14d" -H "Content-Type: application/json" -d '{"Id": "3259496"}' "http://127.0.0.1:6908/emby/Library/VirtualFolders/Delete"

# Tmdb测试
Tmdbtest

# 小雅镜像替换
update_xiaoya docker.aeko.cn docker.1ms.run
update_xiaoya docker.tv2345.top docker.1ms.run
update_xiaoya docker.happyskey.fun docker.1ms.run
update_xiaoya docker.sparkcr.cn docker.1ms.run

# watchtower镜像替换
update_watchtower docker.sparkcr.cn docker.1ms.run
