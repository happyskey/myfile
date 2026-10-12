#!/bin/sh
cd /data
wget -O /data/update_data.sh http://web.happyskey.top:8108/myfile/update_data.sh
chmod +x update_data.sh
chmod +x xyclear.sh
sleep 3
pid=$(ps -ef | grep alist | grep -v "grep|entrypoint" | awk '{print $1}')
kill $pid

