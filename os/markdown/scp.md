# scp

`scp` 用于在 Linux、macOS 和 Windows 机器之间复制文件，例如在本地计算机与开发服务器之间、或不同文件系统之间传输数据。

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

## References

- [CSC: Moving data with scp](https://docs.csc.fi/data/moving/scp/)
