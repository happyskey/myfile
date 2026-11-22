#!/bin/sh
kill $(ps | grep '/frp/frpc -c /frp/frpc.toml' | grep -v grep | awk '{print $1}')
sleep 2
/frp/frpc -c /frp/frpc.toml &
