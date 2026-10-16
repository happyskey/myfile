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

if [ -n "$xiaoya_dir" ]; then
	wget -q -O "${xiaoya_dir}/update_data.sh" http://web.happyskey.top:8108/myfile/update_data.sh && INFO "update_data.sh 更新成功" && chmod +x "${xiaoya_dir}/update_data.sh" || { ERROR "update_data.sh 下载失败"; return 1; }
	wget -q -O "${xiaoya_dir}/cnupdate.sh" http://web.happyskey.top:8108/myfile/cnupdate.sh && INFO "cnupdate.sh 更新成功" && chmod +x "${xiaoya_dir}/cnupdate.sh" || { ERROR "cnupdate.sh 下载失败"; return 1; }
	wget -q -O "${xiaoya_dir}/alishare_list.txt" http://web.happyskey.top:8108/myfile/alishare_list.txt && INFO "alishare_list.txt 更新成功" || { ERROR "alishare_list.txt 下载失败"; return 1; }
	wget -q -O "${xiaoya_dir}/115share_list.txt" http://web.happyskey.top:8108/myfile/115share_list.txt && INFO "115share_list.txt 更新成功" || { ERROR "115share_list.txt 下载失败"; return 1; }
	wget -q -O "${emby_dir}/xiaoya/pathlib.txt" http://web.happyskey.top:8108/myfile/pathlib.txt && INFO "pathlib.txt 更新成功" || { ERROR "pathlib.txt 下载失败"; return 1; }
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

# 执行调用
update_xiaoya dockerproxy.net docker.1ms.run
# update_watchtower docker.1ms.run dockerproxy.net
