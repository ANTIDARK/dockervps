## 方案架构

| 组件 | 变更 | 说明 |
|------|------|------|
| **caddy反向代理** |  caddy | 反向代理 |
| **TTYD 认证** | 网页ssh | 通过环境变量 `USER_NAME`/`USER_PASS`修改 |
| **文件管理** |  dufs | 单文件 Rust 编写，更轻量，支持上传/下载/认证 |

---

## 环境变量配置

| 变量 | 默认值 | 用途 |
|------|--------|------|
| `USER_NAME` | `admin` | TTYD 网页终端登录用户名 |
| `USER_PASS` | `admin123` | TTYD 网页终端登录密码 |
| `DUFS_USER` | `admin` | dufs 文件管理登录用户名 |
| `DUFS_PASS` | `admin123` | dufs 文件管理登录密码 |

---

## 使用方式

```bash
# 构建并启动
docker compose up -d --build

# 或自定义环境变量
USER_NAME=myuser USER_PASS=mypass DUFS_USER=fileadmin DUFS_PASS=filepass docker compose up -d --build
```

**访问地址**：
- 导航页：`http://你的IP:80/`
- Web 终端：`http://你的IP:80/ttyd/`（输入 USER_NAME / USER_PASS）
- 文件管理：`http://你的IP:80/files/`（输入 DUFS_USER / DUFS_PASS）

---

## 终端内使用 sudo

TTYD 登录后，用户已配置免密码 sudo：
```bash
$ whoami
admin
$ sudo apt-get update   # 不需要输入密码
$ sudo su               # 直接切换到 root

```
 
---

## dufs 功能

| 功能 | 支持 |
|------|------|
| 文件浏览 | ✅ |
| 上传文件 | ✅ |
| 下载文件 | ✅ |
| 删除文件 | ✅ |
| 搜索文件 | ✅ |
| 创建文件夹 | ✅ |
| 压缩/解压 | ✅ |
| 基本认证 | ✅ |

---

## 资源预估

| 组件 | 内存占用 |
|------|----------|
| SSHD | ~5MB |
| TTYD | ~10MB |
| dufs | ~15MB |
| Caddy | ~15MB |
| Alpine 基础 | ~20MB |
| **合计** | **~65MB** |

---
