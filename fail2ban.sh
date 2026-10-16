#!/bin/sh
apt update -y && apt install fail2ban -y && \
cp /etc/fail2ban/jail.local /etc/fail2ban/jail.local.bak 2>/dev/null || true && \
cat > /etc/fail2ban/jail.local <<'EOF'
[DEFAULT]
bantime  = 600          # 封禁时长：10分钟（动态IP友好，误封后自动解封）
findtime = 300          # 检测时间窗口：5分钟
maxretry = 5            # 5次失败登录即封禁
banaction = iptables    # 使用iptables封禁
action = %(action_)s    # 仅封禁，不发邮件
ignoreip = 127.0.0.1/8 ::1

[sshd]
enabled  = true
filter   = sshd
port     = 22           # 如果改了SSH端口，这里也要改
logpath  = /var/log/auth.log
EOF
systemctl enable --now fail2ban && systemctl restart fail2ban && \
fail2ban-client status sshd && \
echo -e "\n✅ 安装配置完成！\n应急解封：fail2ban-client set sshd unbanip 你的IP\n实时日志：tail -f /var/log/fail2ban.log"
