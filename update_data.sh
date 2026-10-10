#!/bin/bash
x=$1

# 定义日志函数
INFO() { echo -e "\033[34m[INFO]\033[0m[$(date '+%Y-%m-%d %H:%M:%S')] $1"; }  # 绿色
WARN() { echo -e "\033[33m[WARN]\033[0m[$(date '+%Y-%m-%d %H:%M:%S')] $1"; }  # 黄色
ERROR() { echo -e "\033[31m[ERROR]\033[0m[$(date '+%Y-%m-%d %H:%M:%S')] $1"; } # 红色

# 使用 curl 获取运行商
check_cmcc() {
    RESPONSE=$(curl -s --connect-timeout 3 https://cip.cc)
    # 检查是否成功获取数据
    if [ $? -ne 0 ]; then
        WARN "错误：无法连接到 cip.cc"
        return 1
    fi
    ISP=$(echo "$RESPONSE" | grep "运营商" | awk -F ':' '{print $2}' | tr -d '[:space:]')
    INFO "当前运营商：$ISP"

    if [[ "$ISP" == *移动* ]]; then
        download_url=http://web.happyskey.top:8108/data
    fi
}

# 备用地址
download_url1=https://gitxx.tv2345.top/https://raw.githubusercontent.com/xiaoyaDev/data/refs/heads/main
download_url2=https://data.xiaoya.pro

# 网络获取可用URL
# alive_urls=($(curl --ipv4 -s --max-time 4 "https://api.akams.cn/github" | jq -r '.data | sort_by(-.speed, .latency) | .[:10] | .[].url' | sed 's#$#/https://raw.githubusercontent.com/xiaoyaDev/data/main#g' ))

# 默认地址"https://gh.aeko.cn/https://raw.githubusercontent.com/xiaoyaDev/data/main"
mirror_base_urls=(
    "http://web.happyskey.top:8108/data"
    "https://ghfast.top/https://raw.githubusercontent.com/xiaoyaDev/data/refs/heads/main"
    "https://gitxx.tv2345.top/https://raw.githubusercontent.com/xiaoyaDev/data/main"
)

# 合并 URL 到 base_urls
base_urls=($(printf "%s\n" "${mirror_base_urls[@]}" | shuf))
base_urls=("${base_urls[@]}" "${alive_urls[@]}")

#获取下载地址
success=false
for base_url in "${base_urls[@]}"; do
    remote_ver=$(curl --ipv4 --max-time 10 ${base_url}/version.txt 2>/dev/null | grep '^[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}$')
    if [ $? -eq 0 ]; then
        success=true
		download_url="${base_url}"
        check_cmcc        # 如果移动使用默认地址
        INFO "有效地址为：$download_url" 
        download_custom_url=$(echo "$download_url" | cut -d'/' -f1-3 )
        INFO "有效域名为：$download_custom_url" 
        break
    fi
done
if [ "$success" = false ]; then
    ERROR "找不到有效下载地址，启用备用地址"
    wget -P /data/data http://web.happyskey.top:8108/data/index.zip || wget -P /data/data $download_url1/index.zip
    wget -P /data/data http://web.happyskey.top:8108/data/tvbox.zip || wget -P /data/data $download_url1/tvbox.zip
    wget -P /data/data http://web.happyskey.top:8108/data/update.zip || wget -P /data/data $download_url1/update.zip
    wget -P /data/data http://web.happyskey.top:8108/data/index.video.zip || wget -P /data/data $download_url1/index.video.zip
    wget -P /data/data http://web.happyskey.top:8108/data/version.zip || wget -P /data/data $download_url1/version.txt
fi

# 下载地址
#share115ID1="xiaoya swwz4ps339r 3025203310983380933 8888"
share_list_url_115="https://gitee.com/happyskey/myfile/raw/master/115share_list.txt"
alishare_list_url="https://gitee.com/happyskey/myfile/raw/master/alishare_list.txt"
share_internal_url_115="$download_custom_url/https://raw.githubusercontent.com/xiaoyaDev/data/refs/heads/main/115share_list.txt"
quarkshare_list_url="$download_custom_url/https://raw.githubusercontent.com/xiaoyaDev/data/refs/heads/main/quarkshare_list.txt"
xyclear_url="https://gitee.com/happyskey/myfile/raw/master/xyclear.sh"
xptv_url="https://gitee.com/happyskey/myfile/raw/master/xiaoya_alist.json"
update_data_url="https://gitee.com/happyskey/myfile/raw/master/update_data.sh"
rebootxy_url="https://gitee.com/happyskey/myfile/raw/master/rebootxy.sh"
cnupdate_url="https://gitee.com/happyskey/myfile/raw/master/cnupdate.sh"
emby115_clear_url="https://gitee.com/happyskey/myfile/raw/master/emby115_clear.sh"

# alitv接口
alitv=https://alitv.tv2345.top/api/oauth/alipan/token

# 检查zip文件完整性,$1 ZIP 文件路径
check_zip_integrity() {
    local FILE="$1"
    # 检查文件大小
    local FILE_SIZE
    FILE_SIZE=$(ls -l "$FILE" | awk '{print $5}' 2>/dev/null)

    # 测试ZIP文件完整性（仅在大小满足条件时执行）
    unzip -t "$FILE" >/dev/null 2>&1
    if [ $? -eq 0 ]; then
        INFO "文件检验：正常的 $FILE 大小: $FILE_SIZE 字节"
        return 0
    else
        ERROR "文件检验：错误的 $FILE"
        return 1
    fi
}

# download_file三个参数：下载链接、临时文件路径和最终文件路径
download_file() {
    local url=$1
    local temp_file=$2
    local final_file=$3

    # 下载文件，检查退出状态，设置超时和重试次数
    wget --timeout=5 --tries=3 -O "$temp_file" "$url" &> /dev/null
    if [ $? -eq 0 ] && [ -s "$temp_file" ]; then
        mv "$temp_file" "$final_file"
        INFO "$final_file 更新成功"
    else
        rm -f "$temp_file"
        ERROR "$final_file Error"
    fi
}

# 下载阿里清理和启动更新文件
download_file "$xyclear_url" "/data/xyclear_temp.sh" "/data/xyclear.sh"
download_file "$update_data_url" "/data/update_data_temp.sh" "/data/update_data.sh"
timeout 5 find /data -maxdepth 1 -type f -name "*.sh" -exec chmod +x {} \;

# 下载xptv
download_file "$xptv_url" "/data/xiaoya_alist_temp.json" "/data/xiaoya_alist.json"
mkdir -p /www/tvbox/ && cp -f /data/xiaoya_alist.json /www/tvbox/

# 下载阿里分享
download_file "$alishare_list_url" "/data/alishare_list_temp.txt" "/data/alishare_list.txt"

# 下载115share_internal.txt内置分享和115分享
if [ -s "/data/115_cookie.txt" ]; then
    download_file "$share_internal_url_115" "/data/share_internal_url_115_temp.txt" "/data/115share_internal.txt"
	download_file "$share_list_url_115" "/data/115share_list_temp.txt" "/data/115share_list.txt"
    #echo "$share115ID1" >> "/data/115share_list.txt"
else
    [ -d "/data/emby/xiaoya/音乐/BDrip" ] && rm -rf "/data/emby/xiaoya/音乐/演唱会/BDrip" || mv -f "/data/emby/xiaoya/音乐/演唱会/BDrip" "/data/emby/xiaoya/音乐/BDrip" 2>/dev/null
fi

 # 兼容旧版本非115清理资源
if [ ! -f "/data/115_cookie.txt" ]; then
	if [ -d "/data/emby/xiaoya/国产剧专属/电影A" ]; then
        # 检查 crontab 中是否已存在 emby115_clear.sh，若不存在则添加
        if ! crontab -l | grep -q "emby115_clear.sh"; then
            download_file "$emby115_clear_url" "/data/emby115_clear_temp.sh" "/data/emby115_clear.sh"
            (crontab -l ; echo "*/15 * * * * bash /data/emby115_clear.sh") | crontab -
        fi
	fi
else
    crontab -l | grep -v 'bash /data/emby115_clear.sh' | crontab -
fi


# 下载夸克分享
if [ -s "/data/quark_cookie.txt" ]; then
    download_file "$quarkshare_list_url" "/data/quarkshare_list_temp.txt" "/data/quarkshare_list.txt"
fi

data_dir="/www/data"
mkdir -p "${data_dir}"
touch "${data_dir}/version.txt"
local_ver=$(cat "${data_dir}/version.txt")
if [ "$(printf '%s\n' "$local_ver" "$remote_ver" | sort -V | head -n1)" != "$remote_ver" ] || [ ! -f "${data_dir}/tvbox.zip" ] || [ ! -f "${data_dir}/update.zip" ] || [ ! -f "${data_dir}/index.zip" ]; then
INFO "最新版本 $remote_ver 开始更新下载....."
    cp "${data_dir}/index.zip" "${data_dir}/index.zip.bak" > /dev/null 2>&1
    cp "${data_dir}/update.zip" "${data_dir}/update.zip.bak" > /dev/null 2>&1
    cp "${data_dir}/tvbox.zip" "${data_dir}/tvbox.zip.bak" > /dev/null 2>&1
    cp "${data_dir}/index.video.zip" "${data_dir}/index.video.zip.bak" > /dev/null 2>&1
    # if curl --ipv4 --insecure -fsSL --max-time 10 -o "${data_dir}/version.txt" "${download_url}/version.txt"; then INFO "成功更新 version.txt"; else WARN "更新失败 version.txt"; success=false; fi
    curl --ipv4 --insecure -fsSL --max-time 30 -o "${data_dir}/version.txt" "${download_url}/version.txt" && INFO "成功更新 version.txt" || (wget -q --timeout=30 -O "${data_dir}/version.txt" "${download_url2}/version.txt" && INFO "通过 wget 成功更新 version.txt" || (ERROR "wget 重试 version.txt 失败或文件损坏" && success=false))
    curl --ipv4 --insecure -fsSL --max-time 90 -o "${data_dir}/tvbox.zip" "${download_url}/tvbox.zip" && check_zip_integrity "${data_dir}/tvbox.zip" && INFO "成功更新 tvbox.zip" || (ERROR "tvbox.zip 下载失败或文件损坏" && wget -q --timeout=30 -O "${data_dir}/tvbox.zip" "${download_url2}/tvbox.zip" && check_zip_integrity "${data_dir}/tvbox.zip" && INFO "通过 wget 成功更新 tvbox.zip" || (ERROR "wget 重试 tvbox.zip 失败或文件损坏" && success=false))
    curl --ipv4 --insecure -fsSL --max-time 60 -o "${data_dir}/update.zip" "${download_url}/update.zip" && check_zip_integrity "${data_dir}/update.zip" && INFO "成功更新 update.zip" || (ERROR "update.zip 下载失败或文件损坏" && wget -q --timeout=30 -O "${data_dir}/update.zip" "${download_url2}/update.zip" && check_zip_integrity "${data_dir}/update.zip" && INFO "通过 wget 成功更新 update.zip" || (ERROR "wget 重试 update.zip 失败或文件损坏" && success=false))
    curl --insecure -fsSL --max-time 300 -o "${data_dir}/index.zip" "${download_url}/index.zip" && check_zip_integrity "${data_dir}/index.zip" && INFO "成功更新 index.zip" || (ERROR "index.zip 下载失败或文件损坏" && wget -q --timeout=30 -O "${data_dir}/index.zip" "${download_url2}/index.zip" && check_zip_integrity "${data_dir}/index.zip" && INFO "通过 wget 成功更新 index.zip" || (ERROR "wget 重试 index.zip 失败或文件损坏" && success=false))
    #curl --ipv4 --insecure -fsSL --max-time 60 -o "${data_dir}/index.video.zip" "${download_url}/index.video.zip" && check_zip_integrity "${data_dir}/index.video.zip" && INFO "成功更新 index.video.zip" || (ERROR "index.video.zip 下载失败或文件损坏" && wget -q --timeout=30 -O "${data_dir}/index.video.zip" "${download_url2}/index.video.zip" && check_zip_integrity "${data_dir}/index.video.zip" && INFO "通过 wget 成功更新 index.video.zip" || (ERROR "wget 重试 index.video.zip 失败或文件损坏"))
    if [ "$success" == true ]; then
        find "${data_dir}" -name "*.bak" -exec rm -f {} \;
    else
        rm -rf "${data_dir}/version.txt"
        find "${data_dir}" -name "*.zip" -exec rm -f {} \;
        mv "${data_dir}/index.zip.bak" "${data_dir}/index.zip"
        mv "${data_dir}/update.zip.bak" "${data_dir}/update.zip"
        mv "${data_dir}/tvbox.zip.bak" "${data_dir}/tvbox.zip"
        mv "${data_dir}/index.video.zip.bak" "${data_dir}/index.video.zip"
        WARN "数据已回退"
    fi

else
    INFO "数据版本已经是最新的无须更新"		
fi

cd /data
sed -i "s|http://xy.happyskey.top:34278/oauth/alipan/token|$alitv|" opentoken_url.txt
sed -i "s|http://xy.happyskey.top:34278/oauth/alipan/token|$alitv|" open_tv_token_url.txt

if [ -f "/data/jkj.txt" ]; then
  cd /data
  touch temp_transfer_folder_id.txt myopentoken.txt mytoken.txt docker_address.txt docker_address_ext.txt show_my_ali.txt
  touch guestlogin.txt guestpass.txt && echo dav888 > guestpass.txt
  echo "$alitv" > opentoken_url.txt
  echo "$alitv" > open_tv_token_url.txt
  touch cron.txt > /dev/null 2>&1
fi

if [ -f "/data/jkj115.txt" ]; then
  cd /data
  touch temp_transfer_folder_id.txt myopentoken.txt mytoken.txt docker_address.txt docker_address_ext.txt show_my_ali.txt 115_cookie.txt
  touch guestlogin.txt guestpass.txt && echo dav888 > guestpass.txt
  echo "$alitv" > opentoken_url.txt
  echo "$alitv" > open_tv_token_url.txt
  
  echo "我的115 0" > 115_list.txt
  echo "purge_ali_temp=true" > ali2115.txt
  echo "cookie=\"\"" >> ali2115.txt
  echo "purge_pan115_temp=true" >> ali2115.txt
  echo "dir_id=0" >> ali2115.txt
  touch cron.txt > /dev/null 2>&1
fi

if [ -f "/data/custom/ip_monitor.sh" ]; then
    > /data/custom/ip.txt
    #wget -O "/data/custom/ip_monitor.sh" "https://gitee.com/happyskey/myfile/raw/master/emby/xiaoya/ip_monitor.sh"
    #chmod +x /data/custom/ip_monitor.sh
fi

# 修改计划任务减少高峰期CPU占用
sed -i 's|*/15[[:space:]]*0,10,15-23[[:space:]]*\*[[:space:]]*\*[[:space:]]*\*[[:space:]]*/update_data\.sh[[:space:]]*x|10 1,4,10,13-16 * * * /update_data.sh x|' /etc/crontabs/root

# 自动清理任务，检查 crontab 中是否已存在xyclear.sh，若不存在则添加
if ! crontab -l | grep -q "xyclear.sh"; then
    (crontab -l ; echo "*/1 * * * * /data/xyclear.sh /data") | crontab -
fi

# 如果 /data/cron.txt 存在，极空间专用
if [ -f "/data/cron.txt" ]; then
    # 下载 rebootxy.sh 脚本并赋予执行权限
    download_file "$rebootxy_url" "/data/rebootxy_temp.sh" "/data/rebootxy.sh"

    # 检查 crontab 中是否已存在 rebootxy.sh，若不存在则添加
    if ! crontab -l | grep -q "rebootxy.sh"; then
        (crontab -l ; echo "10 6 * * * /data/rebootxy.sh") | crontab -
    fi

    if ! crontab -l | grep -q "/data/update_data.sh"; then
        (crontab -l ; echo "10 */3 * * * bash /data/update_data.sh") | crontab -
    fi

    # 下载 cnupdate.sh 脚本并赋予执行权限
    download_file "$cnupdate_url" "/data/cnupdate_temp.sh" "/data/cnupdate.sh"
    # 检查 crontab 中是否已存在 cnupdate.sh，若不存在则添加
    if ! crontab -l | grep -q "cnupdate.sh"; then
        (crontab -l ; echo "20 18,4 * * * bash /data/cnupdate.sh") | crontab -
    fi

    # 检查 7z 命令是否存在
    if command -v 7z > /dev/null 2>&1; then
        INFO "7z 命令已安装"
    else
        # 修改 APK 源并安装 p7zip
        sed -i 's/dl-cdn.alpinelinux.org/mirrors.aliyun.com/g' /etc/apk/repositories
        apk add p7zip
    fi
fi

if ! crontab -l | grep -q "chmod"; then
   (crontab -l ; echo "*/30 * * * * chmod +x /data/*") | crontab -
fi
timeout 5 find /data -maxdepth 1 -type f -name "*.sh" -exec chmod +x {} \;

> /var/log/nginx/access.log
> /var/log/nginx/error.log
rm /data/jkj.txt > /dev/null 2>&1
rm /data/jkj115.txt > /dev/null 2>&1
#touch /data/nosign.txt
INFO "启动加载完成"