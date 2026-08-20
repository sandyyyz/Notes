# scp

Copying files between different Linux, macOS and Windows machines can be done with the `scp` command. Thus, you can use `scp` to transport data between CSC and your local computer, or between different file systems at CSC.

## local -> remote
The basic syntax for copying data from a local machine to a remote server is:  

```sh
scp /path/to/file username@server:/path/to/remote/destination
```

举个例子，可以这样把文件拷贝到开发服务器的指定目录下：  
```sh

> scp /path/in/local \
> user@host_ip:/path/to/upload/

```
## remote -> local

And correspondingly the syntax to copy files from a remote server to a local machine is:  

```sh
scp username@server:/path/to/file /path/to/local/destination
```

## refs

https://docs.csc.fi/data/moving/scp/
