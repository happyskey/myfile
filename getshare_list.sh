#!/bin/sh

update_xiaoya() {
    local docker_cdn1="$1"
    local docker_cdn2="$2"
    local container_name="xiaoya"
    local container_images="xiaoyaliu/alist:latest"

    # 函数内获取宿主机挂载目录
    local xiaoya_dir
    xiaoya_dir=$(docker inspect -f '{{range .Mounts}}{{if eq .Destination "/data"}}{{.Source}}{{end}}{{end}}' "$container_name" 2>/dev/null)
    if [ -z "$xiaoya_dir" ]; then
        echo "ERROR: 获取容器 ${container_name} 的 /data 挂载目录失败"
        return 1
    fi

    local current_image
    current_image=$(docker inspect --format '{{.Config.Image}}' "$container_name" 2>/dev/null || true)

    if [ "$current_image" = "${docker_cdn1}/${container_images}" ]; then
        if ! docker image inspect "${docker_cdn2}/${container_images}" >/dev/null 2>&1; then
            echo "开始拉取镜像: ${docker_cdn2}/${container_images}"
            docker pull "${docker_cdn2}/${container_images}"
            if ! docker image inspect "${docker_cdn2}/${container_images}" >/dev/null 2>&1; then
                echo "ERROR: 镜像拉取失败 ${docker_cdn2}/${container_images}"
                return 1
            fi

            docker stop "$container_name" 2>/dev/null || true
            docker rm "$container_name" 2>/dev/null || true
            docker rmi "${docker_cdn1}/${container_images}" 2>/dev/null || true
			docker run -d --name=xiaoya --restart=always -p 5678:80 -p 2345:2345 -v $xiaoya_dir:/data -v $xiaoya_dir/data:/www/data -v $xiaoya_dir/update_data.sh:/update_data.sh $docker_cdn2/xiaoyaliu/alist:latest
            echo "${container_name} 容器重建完成"
        fi
    else
        echo "$container_name容器: 当前镜像[$current_image]"
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
                echo "ERROR: 镜像拉取失败 ${docker_cdn2}/${container_images}"
                return 1
            fi

            docker stop "$container_name" 2>/dev/null || true
            docker rm "$container_name" 2>/dev/null || true
            docker rmi "${docker_cdn1}/${container_images}" 2>/dev/null || true

			docker run -d --name="$container_name" --restart=always -v /var/run/docker.sock:/var/run/docker.sock -e TZ=Asia/Shanghai "${docker_cdn2}/${container_images}" --include‑stopped -c --schedule "0 0 7,15 * * *" xiaoya xiaoya‑emd aliyuntvtoken xiaoya‑115cleaner moviepilot‑v2
            echo "${container_name} 容器重建完成"
        fi
    else
        echo "$container_name容器: 当前镜像[$current_image]"
    fi
}

# 执行调用
update_xiaoya docker.1ms.run dockerproxy.net
# update_watchtower docker.1ms.run dockerproxy.net
