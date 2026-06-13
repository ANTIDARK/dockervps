# 使用 Alpine 作为基础镜像
FROM alpine:latest

# 安装必要软件（全部使用 Alpine 官方包，100% 兼容 musl）
RUN apk add --no-cache \
    openssh-server \
    ttyd \
    nginx \
    curl \
    tzdata \
    && rm -rf /var/cache/apk/*

# 生成 root 初始密码（默认: root123）
ARG ROOT_PASSWORD=root123
RUN echo "root:${ROOT_PASSWORD}" | chpasswd

# 配置 SSH
RUN ssh-keygen -A \
    && echo "PermitRootLogin yes" >> /etc/ssh/sshd_config \
    && echo "PasswordAuthentication yes" >> /etc/ssh/sshd_config \
    && echo "PubkeyAuthentication yes" >> /etc/ssh/sshd_config

# 下载并安装 File Browser（Go 静态链接，兼容 musl）
RUN curl -fsSL -o /tmp/filebrowser.tar.gz \
    "https://github.com/filebrowser/filebrowser/releases/download/v2.32.0/filebrowser-v2.32.0-linux-amd64.tar.gz" \
    && tar -xzf /tmp/filebrowser.tar.gz -C /usr/local/bin filebrowser \
    && chmod +x /usr/local/bin/filebrowser \
    && rm -f /tmp/filebrowser.tar.gz

# 创建必要目录
RUN mkdir -p /srv /etc/filebrowser /var/www/html /run/nginx

# 设置 nginx 权限
RUN chown -R nginx:nginx /var/www/html \
    && chmod -R 755 /var/www/html

# 生成导航页（单行 HTML，避免构建时多行写入问题）
RUN printf '%s' '<!DOCTYPE html><html lang="zh-CN"><head><meta charset="UTF-8"><meta name="viewport" content="width=device-width,initial-scale=1.0"><title>Server Toolbox</title><style>*{margin:0;padding:0;box-sizing:border-box}body{font-family:-apple-system,BlinkMacSystemFont,"Segoe UI",Roboto,sans-serif;background:linear-gradient(135deg,#1a1a2e 0%,#16213e 100%);min-height:100vh;display:flex;justify-content:center;align-items:center;color:#fff}.container{text-align:center;padding:40px}h1{font-size:2.5rem;margin-bottom:10px;background:linear-gradient(90deg,#00d4ff,#7b2cbf);-webkit-background-clip:text;-webkit-text-fill-color:transparent}.subtitle{color:#8892b0;margin-bottom:50px;font-size:1rem}.cards{display:flex;gap:30px;flex-wrap:wrap;justify-content:center}.card{background:rgba(255,255,255,.05);border:1px solid rgba(255,255,255,.1);border-radius:16px;padding:35px 45px;width:260px;cursor:pointer;transition:all .3s ease;text-decoration:none;color:#fff}.card:hover{background:rgba(255,255,255,.1);transform:translateY(-5px);border-color:rgba(0,212,255,.5);box-shadow:0 10px 40px rgba(0,212,255,.15)}.icon{font-size:3rem;margin-bottom:15px}.card h2{font-size:1.3rem;margin-bottom:10px}.card p{color:#8892b0;font-size:.9rem;line-height:1.5}.info{margin-top:50px;padding:20px;background:rgba(255,255,255,.03);border-radius:12px;font-size:.85rem;color:#8892b0}.info code{background:rgba(255,255,255,.1);padding:2px 8px;border-radius:4px;color:#00d4ff}</style></head><body><div class="container"><h1>Server Toolbox</h1><p class="subtitle">网页端服务器管理工具集</p><div class="cards"><a href="/ttyd/" class="card"><div class="icon">&#128187;</div><h2>Web 终端</h2><p>基于 TTYD 的浏览器终端，可直接操作服务器命令行</p></a><a href="/files/" class="card"><div class="icon">&#128193;</div><h2>文件管理</h2><p>基于 File Browser 的网页文件管理器，支持上传下载编辑</p></a></div><div class="info"><p>&#128273; Root 密码: <code>root123</code> | FileBrowser: <code>admin / admin</code></p><p style="margin-top:8px">&#128161; SSH 服务在容器内运行，通过 Web 终端登录后可使用 <code>ssh localhost</code></p></div></div></body></html>' \
    > /var/www/html/index.html

# 删除 nginx 默认配置
RUN rm -f /etc/nginx/http.d/default.conf

# 创建 nginx 配置（使用 printf 写入，避免 heredoc 问题）
RUN printf '%s\n' \
    'server {' \
    '    listen 80;' \
    '    server_name localhost;' \
    '    location / {' \
    '        root /var/www/html;' \
    '        index index.html;' \
    '    }' \
    '    location /ttyd {' \
    '        return 301 /ttyd/;' \
    '    }' \
    '    location /ttyd/ {' \
    '        proxy_pass http://127.0.0.1:7681;' \
    '        proxy_http_version 1.1;' \
    '        proxy_set_header Upgrade $http_upgrade;' \
    '        proxy_set_header Connection "upgrade";' \
    '        proxy_set_header Host $host;' \
    '        proxy_set_header X-Real-IP $remote_addr;' \
    '        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;' \
    '        proxy_set_header X-Forwarded-Proto $scheme;' \
    '        proxy_read_timeout 86400;' \
    '    }' \
    '    location /files {' \
    '        return 301 /files/;' \
    '    }' \
    '    location /files/ {' \
    '        proxy_pass http://127.0.0.1:8080;' \
    '        proxy_set_header Host $host;' \
    '        proxy_set_header X-Real-IP $remote_addr;' \
    '        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;' \
    '        proxy_set_header X-Forwarded-Proto $scheme;' \
    '    }' \
    '}' \
    > /etc/nginx/http.d/toolbox.conf

# 创建启动脚本
RUN cat > /start.sh << 'EOF'
#!/bin/sh
set -e

echo "========================================"
echo "  Alpine Server Toolbox"
echo "========================================"
echo ""
echo "  导航页      : http://<你的IP>:<映射端口>/"
echo "  Web 终端    : http://<你的IP>:<映射端口>/ttyd/"
echo "  文件管理    : http://<你的IP>:<映射端口>/files/"
echo ""
echo "  Root 密码   : ${ROOT_PASSWORD:-root123}"
echo "  FileBrowser : admin / admin"
echo "========================================"
echo ""

# 创建必要目录
mkdir -p /srv /etc/filebrowser /run/nginx

# 初始化 File Browser（如果数据库不存在）
if [ ! -f /etc/filebrowser/filebrowser.db ]; then
    echo "[*] 初始化 File Browser 数据库..."
    filebrowser config init --database /etc/filebrowser/filebrowser.db
    filebrowser users add admin admin --perm.admin --database /etc/filebrowser/filebrowser.db
    echo "[*] File Browser 已初始化"
else
    echo "[*] File Browser 数据库已存在，跳过初始化"
fi

# 启动 SSHD（内部使用，不暴露端口）
echo "[*] 启动 SSHD 服务（内部）..."
/usr/sbin/sshd

# 启动 TTYD（监听 localhost:7681，base path 为 /ttyd）
echo "[*] 启动 TTYD 服务..."
ttyd -p 7681 -W -b /ttyd /bin/login &

# 启动 File Browser（监听 localhost:8080，baseurl 为 /files）
echo "[*] 启动 File Browser..."
filebrowser --database /etc/filebrowser/filebrowser.db \
    --root /srv \
    --address 127.0.0.1 \
    --port 8080 \
    --baseurl /files &

# 等待内部服务启动
sleep 2

# 启动 nginx（监听 :80，暴露给外部）
echo "[*] 启动 nginx 反向代理..."
nginx &

echo ""
echo "[*] 所有服务已启动"
echo "[*] 访问导航页开始使用"

# 保持容器运行
tail -f /dev/null
EOF
RUN chmod +x /start.sh

# 只暴露 nginx 的 80 端口
EXPOSE 80

CMD ["/start.sh"]
