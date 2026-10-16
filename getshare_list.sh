#!/bin/sh

xiaoya_dir=$(docker inspect -f '{{range .Mounts}}{{if eq .Destination "/data"}}{{.Source}}{{end}}{{end}}' xiaoya)

update_xiaoya() {
    local docker_cdn1=$1
    local docker_cdn2=$2
	local container_name=xiaoya
	local container_images=xiaoyaliu/alist:latest
    local current_image=$(docker inspect --format '{{.Config.Image}}' $container_name 2>/dev/null || true)

    # 第一层if开始
    if [ "$current_image" = "$docker_cdn1/$images" ]; then
        # 第二层if开始
        if ! docker image inspect "$docker_cdn2/$container_images" >/dev/null 2>&1; then
            docker pull "$docker_cdn2/$container_images"
            if ! docker image inspect "$docker_cdn2/$container_images" >/dev/null 2>&1; then
                return 1
            fi
            # 拉取镜像成功后重建容器
            docker stop $container_name 2>/dev/null || true
            docker rm $container_name 2>/dev/null || true
            docker rmi "$docker_cdn1/$container_images" 2>/dev/null || true
			
			docker run -d --name=xiaoya --restart=always -p 5678:80 -p 2345:2345 -v $xiaoya_dir:/data -v $xiaoya_dir/data:/www/data -v $xiaoya_dir/update_data.sh:/update_data.sh $docker_cdn2/xiaoyaliu/alist:latest

        fi
    fi
}

update_watchtower() {
    local docker_cdn1=$1
    local docker_cdn2=$2
    local current_image=$(docker inspect --format '{{.Config.Image}}' watchtower 2>/dev/null || true)

    # 第一层if开始
    if [ "$current_image" = "$docker_cdn1/nickfedor/watchtower" ]; then
        # 第二层if开始
        if ! docker image inspect "$docker_cdn2/nickfedor/watchtower:latest" >/dev/null 2>&1; then
            docker pull "$docker_cdn2/nickfedor/watchtower:latest"
            if ! docker image inspect "$docker_cdn2/nickfedor/watchtower:latest" >/dev/null 2>&1; then
                return 1
            fi
            # 拉取镜像成功后重建容器
            docker stop watchtower 2>/dev/null || true
            docker rm watchtower 2>/dev/null || true
            docker rmi "$docker_cdn1/nickfedor/watchtower:latest" 2>/dev/null || true
            docker run -d --name=watchtower --restart=always \
                -v /var/run/docker.sock:/var/run/docker.sock \
                -e TZ=Asia/Shanghai \
                $docker_cdn2/nickfedor/watchtower \
                --include-stopped -c --schedule "0 0 7,15 * * *" \
                xiaoya xiaoya-emd aliyuntvtoken xiaoya-115cleaner moviepilot-v2
        fi  # 闭合第二层if
    fi      # 闭合最外层if（之前漏掉的关键fi）
}

update_xiaoya docker.1ms.run dockerproxy.net



