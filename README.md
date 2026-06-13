---

## 架构设计

```
用户浏览器 ──► 平台映射端口 ──► Caddy :80
                                      │
                    ├─► / ──────────► 导航页 (静态HTML)
                    ├─► /ttyd ──────► TTYD (localhost:7681)
                    └─► /files ─────► File Browser (localhost:8080)
                    
SSHD 在容器内部运行，不暴露端口
```

**只暴露 1 个端口（80）**，所有服务通过路径区分。

---

## 访问路径

| 路径 | 服务 | 说明 |
|------|------|------|
| `/` | **导航页** | 美观的入口页面，点击跳转各服务 |
| `/ttyd` | **Web 终端** | TTYD 浏览器终端，登录后可用 bash |
| `/files` | **文件管理** | File Browser，支持上传/下载/编辑 |

---

## 默认凭证

| 服务 | 用户名 | 密码 |
|------|--------|------|
| Root（TTYD 登录） | `root` | `root123`（可自定义） |
| File Browser | `admin` | `admin` |

---

## 使用方法

```bash
# 1. 下载两个文件到同一目录
# 2. 构建并启动
docker compose up -d --build

# 3. 访问 http://你的IP:8080 即可看到导航页
```

---

## 关于 SSH 的使用

由于只能暴露 1 个端口，SSH（22 端口）**不直接暴露**。有两种使用方式：

1. **通过 TTYD 网页终端**：访问 `/ttyd`，用 `root/root123` 登录后，在容器内直接使用 `ssh localhost` 或直接用 bash
2. **如果需要外部 SSH**：可以在平台再申请一个 TCP 端口映射给 22，或配合 Cloudflare Tunnel 等

---

## 资源预估

| 组件 | 内存占用 |
|------|----------|
| SSHD | ~5MB |
| TTYD | ~10MB |
| File Browser | ~30MB |
| Caddy | ~15MB |
| Alpine 基础 | ~20MB |
| **合计** | **~80MB** |

在你的 250MB 限制内非常宽松。

---

下载文件：
- [Dockerfile](sandbox:///mnt/agents/output/Dockerfile)
- [docker-compose.yml](sandbox:///mnt/agents/output/docker-compose.yml)
