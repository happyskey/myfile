cat > /root/install-fail2ban.sh <<'SCRIPT'
#!/bin/sh
set -e

# 1. 安装依赖
apt update -y
apt install -y fail2ban nftables
apt install -y python3-systemd 2>/dev/null || true

# 2. 备份旧配置
[ -f /etc/fail2ban/jail.local ] && \
    cp /etc/fail2ban/jail.local /etc/fail2ban/jail.local.bak.$(date +%s)

# 3. 写入 jail.local
cat > /etc/fail2ban/jail.local <<'EOF'
[DEFAULT]
logtarget = /var/log/fail2ban.log
loglevel  = INFO
dbfile    = /var/lib/fail2ban/fail2ban.sqlite3
ignoreip  = 127.0.0.1/8 ::1

[sshd]
enabled  = true
backend  = systemd
maxretry = 5
findtime = 10m
bantime  = 6h
action   = nftables
EOF

# 4. socket 目录
mkdir -p /var/run/fail2ban

# 5. 语法检查
fail2ban-client -t

# 6. 启动
systemctl enable fail2ban
systemctl restart fail2ban
sleep 2

# 7. 状态
fail2ban-client status
fail2ban-client status sshd
nft list tables | grep f2b-table || true

echo "✅ 安装配置完成！"
echo "应急解封：fail2ban-client set sshd unbanip 你的IP"
echo "实时日志：tail -f /var/log/fail2ban.log"
echo "查看封禁：nft list set inet f2b-table addr-set-sshd"
SCRIPT

chmod +x /root/install-fail2ban.sh
/root/install-fail2ban.sh
