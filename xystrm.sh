#!/bin/sh
# 定义日志函数
INFO() { echo -e "\033[34m[INFO]\033[0m[$(date '+%Y-%m-%d %H:%M:%S')] $1"; } # 绿色
WARN() { echo -e "\033[33m[WARN]\033[0m[$(date '+%Y-%m-%d %H:%M:%S')] $1"; } # 黄色
ERROR() { echo -e "\033[31m[ERROR]\033[0m[$(date '+%Y-%m-%d %H:%M:%S')] $1"; } # 红色

strm_dir="/mnt/disk/strmdata/strm"
strmup_dir="/mnt/disk/strmdata/strmup"
zip_dir="/mnt/disk/strmdata/zip"

process_and_compress() {
  INFO 开始处理数据并打包上传：$1
  # 定义输入参数
  local input_dir="$1" # 输入目录路径
  local source_dir="$(dirname "$input_dir")" # 输入目录的上一级目录
  local final_zip="$2" # 最终压缩文件路径
  local path_zip="$3" # true压缩目录本身，false压缩目录内容
  # 切换到源目录
  cd "$source_dir" || exit
  # 查找 .strm 文件并进行字符串替换
  find ./ -name "*.strm" -exec sed -i \
    -e "s#http://192.168.1.6:5244#http://xiaoya.host:5678#g" \
    -e "s# #%20#g" \
    -e "s#|#%7C#g" {} \;
  # 删除旧的临时压缩文件
  rm -rf "$zip_dir/temp.zip"
  # 创建新的压缩文件
    if [ "$path_zip" = true ]; then
        # 执行压缩目录本身
        7za a -t7z -mx=9 -m0=lzma2 -mfb=64 -md=32m -ms=on "$zip_dir/temp.zip" "$input_dir"
    else
        # 执行压缩目录的内容
        7za a -t7z -mx=9 -m0=lzma2 -mfb=64 -md=32m -ms=on "$zip_dir/temp.zip" "$input_dir/*"
    fi
    # 如果临时压缩文件存在且大于2KB，则替换最终压缩文件
    if [ -f "$zip_dir/temp.zip" ]; then
        # 获取文件大小（以字节为单位）
        filesize=$(stat -c%s "$zip_dir/temp.zip")
        # 检查文件大小是否大于2048字节（2KB）
        if [ "$filesize" -gt 2048 ]; then
            rm -rf "$final_zip"
            mv "$zip_dir/temp.zip" "$final_zip"
        fi
    fi
}
# 目录文件名预处理数据
bash -c "$(curl -s https://istoreos.happyskey.top:46589/download/rename.sh)" -s $strm_dir/电视剧实时同步更新 $strmup_dir/电视剧集 5 TV
bash -c "$(curl -s https://istoreos.happyskey.top:46589/download/rename.sh)" -s $strm_dir/电影实时同步更新 $strmup_dir/电影 1 movie
bash -c "$(curl -s https://istoreos.happyskey.top:46589/download/rename.sh)" -s $strm_dir/已完结的电视剧 $strmup_dir/已完结的电视剧 10 TV
bash -c "$(curl -s https://istoreos.happyskey.top:46589/download/rename.sh)" -s $strm_dir/欧美剧大合集 $strmup_dir/六大合集欧美 10 TV
bash -c "$(curl -s https://istoreos.happyskey.top:46589/download/rename.sh)" -s $strm_dir/华语剧大合集 $strmup_dir/六大合集华语 10 TV
bash -c "$(curl -s https://istoreos.happyskey.top:46589/download/rename.sh)" -s $strm_dir/xxxx $strmup_dir/xxx 1 hexie

# 处理数据并上传
process_and_compress "$strmup_dir/" "$zip_dir/newstrm.zip" "false"
