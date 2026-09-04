# strace

`strace` 是一个利用 Linux `ptrace` 实现的用户态工具，用于拦截并记录一个进程所调用的 `syscall` 和接收到的 `signals`。

## 适用场景

| 场景 | 关注点 |
| --- | --- |
| 程序启动失败 | `execve()`、动态库加载、配置文件访问 |
| 文件权限问题 | `openat()` / `access()` 返回的 errno |
| 进程卡住 | 阻塞在哪个 syscall，如 `futex()`、`poll()`、`read()` |
| 网络问题 | `socket()`、`connect()`、`sendto()`、`recvfrom()` |
| 信号行为 | signal 递送、syscall restart、退出原因 |

## 输出解释

这里以运行 `strace ls` 的输出为例，解释 `strace` 输出的含义。

```text
/*
 * 每一行包括一个系统调用名，随后是括号中的参数和返回值
 */
execve("/usr/bin/ls", ["ls"], 0x7ffe2d5b0e10 /* 26 vars */) = 0
brk(NULL)                               = 0x64eacb6ad000
mmap(NULL, 8192, PROT_READ|PROT_WRITE, MAP_PRIVATE|MAP_ANONYMOUS, -1, 0) = 0x7b1c5ab8f000
/*
 * 错误返回 error symbol 和 error string
 */
access("/etc/ld.so.preload", R_OK)      = -1 ENOENT (No such file or directory)

......

exit_group(0)                           = ?
+++ exited with 0 +++
```

当使用 `kill <pid>` 杀死一个 `strace sleep 666` 进程时，可以看到：

```text
/*
 * signal symbol 和 siginfo structure 的内容会被打印
 */
clock_nanosleep(CLOCK_REALTIME, 0, {tv_sec=666, tv_nsec=0}, {tv_sec=655, tv_nsec=219876115}) = ? ERESTART_RESTARTBLOCK (Interrupted by signal)
--- SIGTERM {si_signo=SIGTERM, si_code=SI_USER, si_pid=13621, si_uid=1000} ---
+++ killed by SIGTERM +++
Terminated
```

当一个 `syscall` 正在调用时，另一个被追踪的进/线程被调用，`strace` 会 *try to preserve* 事件的时序：用 `unfinished` 标注尚未完成的 `syscall`，用 `resumed` 标注恢复并且执行完毕的 `syscall`。

```text
[pid 28772] select(4, [3], NULL, NULL, NULL <unfinished ...>
[pid 28779] clock_gettime(CLOCK_REALTIME, {tv_sec=1130322148, tv_nsec=3977000}) = 0
[pid 28772] <... select resumed>)     = 1 (in [3])
```

当一个 `syscall` 被 signal 打断，`syscall` 可能 restart 或返回错误，这里以 restart 为例：

```text
read(0, 0x7ffff72cf5cf, 1)            = ? ERESTARTSYS (To be restarted)
--- SIGALRM {si_signo=SIGALRM, si_code=SI_KERNEL} ---
rt_sigreturn({mask=[]})               = 0
read(0, "", 1)                        = 0
```

`strace` 会尝试解引用指针并 decode 结构体，使其更易阅读。对于未知的 `syscall`，`strace` 将**以十六进制形式打印，并加上 `syscall_` 前缀**：

```text
syscall_0xbad(0x1, 0x2, 0x3, 0x4, 0x5, 0x6) = -1 ENOSYS (Function not implemented)
```

1. 结构体使用 `{}` 表示
2. 普通数组使用 `[]`，元素之间逗号分隔
3. bit-sets 也用 `[]`，但元素之间用空格分隔
4. `[]` 表示空集
5. `~[]` 表示空集的补集

## strace attach

`ptrace attach` 一个 process，指的是：一个进程通过 `ptrace()` 系统调用，接管并跟踪另一个已经运行的进程或线程。

典型调用：

```c
ptrace(PTRACE_ATTACH, pid, NULL, NULL);
```

执行成功后，大致会发生以下过程：

1. 内核建立 tracer 与目标线程之间的 ptrace 跟踪关系。
2. `PTRACE_ATTACH` 会使目标线程收到 SIGSTOP 并进入暂停状态。
3. tracer 通过 `waitpid()` 等待并确认目标已经停止。
4. 目标停止后，tracer 可以读取或修改其寄存器、访问进程地址空间、设置断点、单步执行、跟踪系统调用等。
5. tracer 使用 `PTRACE_CONT` 让目标继续运行，或者使用 `PTRACE_DETACH` 解除跟踪关系。

## 常用选项

| 选项 | 作用 |
| --- | --- |
| `-f` | 跟踪 fork/clone 出来的子进程或线程 |
| `-p <pid>` | attach 到已有进程 |
| `-o <file>` | 输出到文件 |
| `-tt` / `-ttt` | 输出更精确的时间戳 |
| `-T` | 显示每个 syscall 耗时 |
| `-e trace=<set>` | 只跟踪指定 syscall 集合，如 `file`、`network`、`process` |
| `-e fault=<syscall>` | 注入 syscall 错误，常用于测试错误路径 |
| `-s <size>` | 调整字符串打印长度 |
| `-yy` | 更详细地解析文件描述符路径 |

常见排查命令：

```sh
strace -f -tt -T -s 256 -o trace.log command args
strace -p <pid> -f -tt -T
strace -e trace=file command
strace -e trace=network command
```
