#!/bin/bash

update_hosts_file() {
    local domain="$1"

    # 获取域名的IPv4地址列表
    ip_list=$(nslookup "$domain" | awk '/^Address: / { print $2 }' | grep '\.' | head -n 1)

    # 检查是否成功获取到IPv4地址
    if [ -n "$ip_list" ]; then
        # 遍历IPv4地址
        for ip in $ip_list; do
            # 检查是否可以 ping 通
            if ping -c 2 "$ip" &> /dev/null; then
                # 检查是否已存在相同的IP地址
                if ! grep -q "$domain" /etc/hosts; then
                    # 将IPv4地址写入hosts文件
                    echo "$ip $domain" | tee -a /etc/hosts > /dev/null
                    echo "已将 $ip $domain 写入hosts文件"
                else
                    echo "IP地址 $ip $domain 已存在于hosts文件中"
                fi
            else
                echo "无法 ping 通 $ip $domain，将不写入hosts文件"
            fi
        done
    else
        echo "无法获取到IPv4地址"
    fi
}

update_hosts() {
    # $1 是域名，后面的参数是多个 IP 地址
    domain="$1"
    shift  # 将第一个参数移除，因为它是域名

    for ip in "$@"; do  # 遍历剩下的每个 IP 地址
        # 检查是否可以 ping 通
        if ping -c 4 "$ip" &> /dev/null; then
            # 检查是否已经存在该域名
            if ! grep -q "$domain" /etc/hosts; then
                # 将IPv4地址写入hosts文件
                echo "$ip $domain" | tee -a /etc/hosts > /dev/null
                echo "已将 $ip $domain 写入hosts文件"
            else
                echo "域名 $ip $domain 已存在于hosts文件中"
            fi
            break  # 一旦找到一个可以ping通的IP，就退出循环
        else
            echo "无法 ping 通 $ip $domain，继续测试下一个IP"
        fi
    done
}


#docker exec -i emby wget -S --spider https://api.themoviedb.org

# IPv4地址自动解析通的写入hosts文件
update_hosts_file "image.tmdb.org"
update_hosts_file "api.tmdb.org"

echo
## IPv4地址手动指定写入hosts
update_hosts "api.themoviedb.org" 52.85.151.18 3.168.178.36 18.173.219.98
update_hosts "www.themoviedb.org" 18.66.122.113 18.67.51.128 18.245.175.23
update_hosts "assets.fanart.tv" 192.99.151.161 158.69.0.103

update_hosts "www.thetvdb.com" 108.138.20.106 3.162.172.98 54.230.177.110
update_hosts "api4.thetvdb.com" 54.192.18.34 18.172.134.68 54.230.176.30
update_hosts "artworks.thetvdb.com" 52.222.215.82 3.168.38.68 54.230.62.199
