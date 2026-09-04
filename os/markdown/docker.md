# docker

Docker 将应用运行环境封装为镜像，并以容器形式启动进程。镜像是只读的分层文件系统，容器在其上增加一层可写层；删除容器后，未挂载到宿主机或 volume 的数据通常会随之丢失。

## 常用概念

| 概念 | 说明 |
| --- | --- |
| Image | 只读模板，包含文件系统、默认命令和元数据 |
| Container | 镜像的运行实例，本质上是受 namespace/cgroup 隔离的进程集合 |
| Volume | 由 Docker 管理的持久化数据目录 |
| Bind mount | 将宿主机路径直接挂载进容器 |
| Dockerfile | 用声明式步骤描述镜像构建过程，适合固化可复现环境 |

## 实践原则

1. 需要长期复现的依赖应写入 Dockerfile，不要依赖手工 `apt install` 或 `docker commit`。
2. 需要保留的数据应使用 volume 或 bind mount，而不是写在容器可写层中。
3. 在开发环境中运行容器时，优先使用数字 UID/GID：`--user "$(id -u):$(id -g)"`，避免挂载目录产生 root-owned 文件。
