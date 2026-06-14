# 使用 Alpine 作为基础镜像
FROM alpine:edge

# 安装必要软件
RUN apk add --no-cache \
    openssh-server \
    openssh-client \
    ttyd \
    caddy \
    curl \
    tzdata \
    bash \
    sudo \
    tar \
    unzip \
    && rm -rf /var/cache/apk/*

# 配置 SSH（允许密码登录，监听 127.0.0.1 仅内部访问）
RUN ssh-keygen -A \
    && echo "PermitRootLogin yes" >> /etc/ssh/sshd_config \
    && echo "PasswordAuthentication yes" >> /etc/ssh/sshd_config \
    && echo "ListenAddress 127.0.0.1" >> /etc/ssh/sshd_config

# 下载并安装 dufs（单文件静态服务器，支持上传/下载/认证）
# 使用固定版本
RUN curl -fsSL -o /tmp/dufs.tar.gz \
    "https://github.com/sigoden/dufs/releases/download/v0.46.0/dufs-v0.46.0-x86_64-unknown-linux-musl.tar.gz" && \
    tar -xzf /tmp/dufs.tar.gz -C /usr/local/bin/ && \
    chmod +x /usr/local/bin/dufs && \
    rm /tmp/dufs.tar.gz

# 创建启动脚本（运行时处理用户创建和配置）
RUN cat > /start.sh << 'EOF'
#!/bin/bash
set -e

# ========================================
#  Alpine Server Toolbox (Dufs Edition)
# ========================================

# 环境变量配置（带默认值）
USER_NAME="${USER_NAME:-admin}"
USER_PASS="${USER_PASS:-admin123}"
DUFS_USER="${DUFS_USER:-admin}"
DUFS_PASS="${DUFS_PASS:-admin123}"

echo "========================================"
echo "  Alpine Server Toolbox"
echo "========================================"
echo ""
echo "  导航页      : http://<你的IP>:<映射端口>/"
echo "  Web 终端    : http://<你的IP>:<映射端口>/ttyd/"
echo "  文件管理    : http://<你的IP>:<映射端口>/files/"
echo ""
echo "  系统用户    : ${USER_NAME} / ${USER_PASS}"
echo "  文件管理    : ${DUFS_USER} / ${DUFS_PASS}"
echo "  sudo 权限   : 免密码 sudo"
echo "========================================"
echo ""

# 创建自定义用户（如果不存在）
if ! id "${USER_NAME}" &>/dev/null; then
    echo "[*] 创建用户 ${USER_NAME}..."
    adduser -D -s /bin/bash "${USER_NAME}"
    echo "${USER_NAME}:${USER_PASS}" | chpasswd

    # 加入 sudo 组并配置免密码 sudo
    adduser "${USER_NAME}" wheel 2>/dev/null || true
    echo "${USER_NAME} ALL=(ALL) NOPASSWD: ALL" >> /etc/sudoers

    echo "[*] 用户 ${USER_NAME} 创建完成，已配置免密码 sudo"
else
    echo "[*] 用户 ${USER_NAME} 已存在"
    # 更新密码
    echo "${USER_NAME}:${USER_PASS}" | chpasswd
fi

# 创建文件管理目录
mkdir -p /srv/dufs
chown -R "${USER_NAME}:${USER_NAME}" /srv/dufs

# 生成 Caddy 配置文件
cat > /etc/caddy/Caddyfile << CADDYCFG
{
    auto_https off
    admin off
}

:80 {
    # 根路径：导航页
    handle / {
        root * /var/www/html
        file_server
    }

    # TTYD 网页终端（直接运行 bash，使用 Caddy 基础认证）
    handle /ttyd/* {
        basicauth {
            ${USER_NAME} $(caddy hash-password --plaintext "${USER_PASS}")
        }
        reverse_proxy localhost:7681 {
            header_up Host {host}
            header_up X-Real-IP {remote}
            header_up X-Forwarded-For {remote}
            header_up X-Forwarded-Proto {scheme}
        }
    }

    # 文件管理 dufs
    handle /files/* {
        reverse_proxy localhost:5000 {
            header_up Host {host}
            header_up X-Real-IP {remote}
            header_up X-Forwarded-For {remote}
            header_up X-Forwarded-Proto {scheme}
        }
    }
}
CADDYCFG

# 创建导航页（动态生成，显示当前用户信息）
cat > /var/www/html/index.html << HTMLEND
<!DOCTYPE html>
<html lang="zh-CN">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>Server Toolbox</title>
    <style>
        * { margin: 0; padding: 0; box-sizing: border-box; }
        body {
            font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, sans-serif;
            background: linear-gradient(135deg, #1a1a2e 0%, #16213e 100%);
            min-height: 100vh;
            display: flex;
            justify-content: center;
            align-items: center;
            color: #fff;
        }
        .container { text-align: center; padding: 40px; }
        h1 {
            font-size: 2.5rem;
            margin-bottom: 10px;
            background: linear-gradient(90deg, #00d4ff, #7b2cbf);
            -webkit-background-clip: text;
            -webkit-text-fill-color: transparent;
        }
        .subtitle { color: #8892b0; margin-bottom: 50px; font-size: 1rem; }
        .cards { display: flex; gap: 30px; flex-wrap: wrap; justify-content: center; }
        .card {
            background: rgba(255,255,255,0.05);
            border: 1px solid rgba(255,255,255,0.1);
            border-radius: 16px;
            padding: 35px 45px;
            width: 260px;
            cursor: pointer;
            transition: all 0.3s ease;
            text-decoration: none;
            color: #fff;
        }
        .card:hover {
            background: rgba(255,255,255,0.1);
            transform: translateY(-5px);
            border-color: rgba(0,212,255,0.5);
            box-shadow: 0 10px 40px rgba(0,212,255,0.15);
        }
        .icon { font-size: 3rem; margin-bottom: 15px; }
        .card h2 { font-size: 1.3rem; margin-bottom: 10px; }
        .card p { color: #8892b0; font-size: 0.9rem; line-height: 1.5; }
        .info {
            margin-top: 50px;
            padding: 20px;
            background: rgba(255,255,255,0.03);
            border-radius: 12px;
            font-size: 0.85rem;
            color: #8892b0;
        }
        .info code { background: rgba(255,255,255,0.1); padding: 2px 8px; border-radius: 4px; color: #00d4ff; }
    </style>
</head>
<body>
    <div class="container">
        <h1>Server Toolbox</h1>
        <p class="subtitle">网页端服务器管理工具集</p>
        <div class="cards">
            <a href="/ttyd/" class="card">
                <div class="icon">&#128187;</div>
                <h2>Web 终端</h2>
                <p>基于 TTYD 的浏览器终端，可直接操作服务器命令行</p>
            </a>
            <a href="/files/" class="card">
                <div class="icon">&#128193;</div>
                <h2>文件管理</h2>
                <p>基于 dufs 的网页文件管理器，支持上传下载编辑</p>
            </a>
        </div>
        <div class="info">
            <p>&#128187; 终端用户: <code>${USER_NAME}</code> / <code>${USER_PASS}</code></p>
            <p style="margin-top:8px">&#128193; 文件管理: <code>${DUFS_USER}</code> / <code>${DUFS_PASS}</code></p>
            <p style="margin-top:8px">&#128161; 用户已加入 sudo 组，免密码执行 sudo</p>
        </div>
    </div>
</body>
</html>
HTMLEND

# 启动 SSHD（监听 127.0.0.1:22，仅内部使用）
echo "[*] 启动 SSHD 服务（内部 127.0.0.1:22）..."
/usr/sbin/sshd

# 启动 TTYD（直接运行 bash，使用 Caddy 基础认证）
echo "[*] 启动 TTYD 服务..."
ttyd -p 7681 --base-path /ttyd /bin/bash &
TTYD_PID=$!

# 启动 dufs（文件服务器，支持上传/下载/认证）
echo "[*] 启动 dufs 文件服务..."
# 使用 --path-prefix /files 适配反向代理
# 使用 -A 参数设置认证用户
# 使用 --allow-upload --allow-delete 允许上传删除
dufs -p 5000 \
    --path-prefix /files \
    -A "${DUFS_USER}:${DUFS_PASS}" \
    --allow-upload \
    --allow-delete \
    --allow-search \
    --allow-symlink \
    --allow-archive \
    /srv/dufs &
DUFS_PID=$!

# 等待内部服务启动
sleep 2

# 检查内部服务是否存活
if ! kill -0 $TTYD_PID 2>/dev/null; then
    echo "[!] TTYD 启动失败"
fi
if ! kill -0 $DUFS_PID 2>/dev/null; then
    echo "[!] dufs 启动失败"
fi

# 启动 Caddy 反向代理（监听 :80，暴露给外部）
echo "[*] 启动 Caddy 反向代理..."
caddy run --config /etc/caddy/Caddyfile &

echo ""
echo "[*] 所有服务已启动"
echo "[*] 访问导航页开始使用"

# 保持容器运行
tail -f /dev/null
EOF
RUN chmod +x /start.sh

# 只暴露 Caddy 的 80 端口
EXPOSE 80

CMD ["/start.sh"]
