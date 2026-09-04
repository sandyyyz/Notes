# scp

`scp` 用于通过 SSH 在本地与远程主机之间复制文件。它适合临时传输单个文件或目录；如果需要断点续传、增量同步或大量文件同步，通常 `rsync` 更合适。

## 语法速览

| 方向 | 命令形式 |
| --- | --- |
| local -> remote | `scp local_path user@host:/remote/path` |
| remote -> local | `scp user@host:/remote/path local_path` |
| remote -> remote | `scp user1@host1:/path user2@host2:/path` |

## local -> remote

从本地机器向远程服务器复制文件的基本语法：

```sh
scp /path/to/file username@server:/path/to/remote/destination
```

举个例子，可以这样把文件拷贝到开发服务器的指定目录下：

```sh
scp /path/in/local user@host_ip:/path/to/upload/
```

## remote -> local

相应地，从远程服务器向本地机器复制文件：

```sh
scp username@server:/path/to/file /path/to/local/destination
```

## 常用选项

| 选项 | 作用 |
| --- | --- |
| `-r` | 递归复制目录 |
| `-P <port>` | 指定 SSH 端口，注意是大写 `P` |
| `-i <key>` | 指定私钥文件 |
| `-C` | 启用压缩 |
| `-p` | 保留修改时间、访问时间和权限 |

## References

- [CSC: Moving data with scp](https://docs.csc.fi/data/moving/scp/)
