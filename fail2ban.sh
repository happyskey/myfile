#!/bin/sh
set -e

# ========== 1. 安装 fail2ban ==========
apt update -y
apt install fail2ban -y

# 判断日志后端：无 auth.log 则用 systemd backend
if [ ! -f /var/log/auth.log ]; then
    apt install python3-systemd -y
    BACKEND_LINE="backend  = systemd"
    LOGPATH_LINE="# logpath 由 backend=systemd 接管"
else
    BACKEND_LINE="# backend 使用默认（文件读取）"
    LOGPATH_LINE="logpath  = /var/log/auth.log"
fi

# ========== 2. 备份旧配置 ==========
[ -f /etc/fail2ban/jail.local ] && cp /etc/fail2ban/jail.local /etc/fail2ban/jail.local.bak.$(date +%s)

# ========== 3. 写入新配置 ==========
cat > /etc/fail2ban/jail.local <<EOF
[DEFAULT]
bantime  = 600
findtime = 300
maxretry = 5
banaction = iptables
action = %(action_)s
ignoreip = 127.0.0.1/8 ::1

[sshd]
enabled  = true
filter   = sshd
port     = 22
${BACKEND_LINE}
${LOGPATH_LINE}
EOF

# ========== 4. 确保 socket 目录存在 ==========
mkdir -p /var/run/fail2ban

# ========== 5. 配置语法检查 ==========
fail2ban-client -t

# ========== 6. 启动服务 ==========
systemctl enable fail2ban
systemctl restart fail2ban
sleep 2

# ========== 7. 查看状态 ==========
fail2ban-client status sshd
