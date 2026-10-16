#!/bin/sh
set -e

# ========== 1. 安装 fail2ban ==========
apt update -y
apt install fail2ban -y

# 如果系统使用 journald 而没有 auth.log，需要 python3-systemd
if [ ! -f /var/log/auth.log ]; then
    echo "⚠️  /var/log/auth.log 不存在，使用 systemd backend"
    apt install python3-systemd -y
    BACKEND_LINE="backend  = systemd"
    LOGPATH_LINE="# logpath 由 backend=systemd 接管，无需指定"
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
chown root:root /var/run/fail2ban
chmod 755 /var/run/fail2ban

# ========== 5. 配置语法检查（关键！）==========
echo "🔍 检查 fail2ban 配置语法..."
if ! fail2ban-client -t; then
    echo "❌ 配置有误，请检查 /etc/fail2ban/jail.local"
    exit 1
fi

# ========== 6. 启动服务 ==========
systemctl enable fail2ban
systemctl restart fail2ban

# 等待服务就绪（socket 创建需要一点时间）
sleep 2

if systemctl is-active --quiet fail2ban; then
    echo "✅ fail2ban 已启动"
else
    echo "❌ fail2ban 启动失败，查看日志：journalctl -u fail2ban -n 50 --no-pager"
    exit 1
fi

# ========== 7. 查看状态 ==========
fail2ban-client status sshd || true

echo ""
echo "✅ 安装配置完成！"
echo "应急解封：fail2ban-client set sshd unbanip 你的IP"
echo "实时日志：tail -f /var/log/fail2ban.log"
