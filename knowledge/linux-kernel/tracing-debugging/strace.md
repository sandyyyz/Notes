# strace

`strace` 是一个利用 Linux `ptrace` 实现的用户态工具，用于拦截并记录一个进程所调用的 `syscall` 和接收到的 `signals`。

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

### 1. 指定跟踪对象

| 选项 | 作用 | 示例 |
| --- | --- | --- |
| `-p <pid>` | attach 到已运行的进程。可重复指定以跟踪多个进程。 | `strace -p 1234` |
| `-f` | 跟踪 `fork`、`vfork`、`clone` 创建的子进程和线程。 | `strace -f ./server` |
| `-ff` | 跟踪子进程，并为每个进程分别写入输出文件。 | `strace -ff -o trace ./server` |

附加到进程通常需要相应权限。跟踪多线程程序时应使用 `-f`，否则可能遗漏线程发起的系统调用。

### 2. 筛选系统调用

| 选项 | 作用 | 示例 |
| --- | --- | --- |
| `-e trace=<set>` | 只跟踪指定类别或名称的系统调用。 | `strace -e trace=file ls` |
| `-e trace=<call>` | 只跟踪一个或多个具体调用。 | `strace -e trace=openat,read ls` |
| `-e signal=<set>` | 只显示指定信号相关事件。 | `strace -e signal=SIGTERM -p 1234` |
| `-e trace=%network` | 跟踪网络相关系统调用。 | `strace -e trace=%network ./client` |
| `-e trace=%process` | 跟踪进程创建、执行和退出。 | `strace -e trace=%process ./script` |

常见类别包括 `%file`、`%network`、`%process`、`%memory` 和 `%signal`。可以用 `-e trace=!openat` 排除某个调用，减少无关输出。

### 3. 控制输出内容

| 选项 | 作用 | 示例 |
| --- | --- | --- |
| `-o <file>` | 将输出写入文件，不与被跟踪程序的标准输出混在一起。 | `strace -o trace.log ./app` |
| `-s <n>` | 设置字符串最大打印长度，默认值较短。 | `strace -s 256 ./app` |
| `-y` | 将文件描述符解码为对应的文件或 socket 路径。 | `strace -y -e trace=read,write ./app` |
| `-yy` | 在 `-y` 基础上尽可能显示 socket 的详细信息。 | `strace -yy -e trace=network ./app` |
| `-v` | 更详细地打印结构体字段。可重复使用以增加详细程度。 | `strace -v ./app` |

需要查看完整参数时，可结合使用 `-s` 和 `-yy`。跟踪输出可能包含敏感数据，应妥善保护日志文件。

### 4. 记录时间与耗时

| 选项 | 作用 | 示例 |
| --- | --- | --- |
| `-t` / `-tt` / `-ttt` | 分别以秒、微秒或 Unix 时间戳显示时间。 | `strace -tt ./app` |
| `-T` | 在每个系统调用末尾显示耗时。 | `strace -T ./app` |
| `-r` | 显示相邻输出行之间的相对时间间隔。 | `strace -r ./app` |
| `-w` | 显示系统调用等待时间；通常与 `-c` 结合使用。 | `strace -cw ./app` |

定位耗时较长的系统调用：

```bash
strace -f -ttT -e trace=file -o file.trace ./app
```

### 5. 统计与调用栈

| 选项 | 作用 | 示例 |
| --- | --- | --- |
| `-c` | 汇总系统调用次数、错误数和耗时，不打印逐条调用。 | `strace -c ./app` |
| `-C` | 在打印逐条调用的同时显示统计结果。 | `strace -C ./app` |
| `-k` | 尝试为每个系统调用打印用户态调用栈。 | `strace -k ./app` |

`-c` 用于查看系统调用的总体开销；如果还需要保留调用顺序，应使用 `-C` 或另行记录明细。

### 按场景选择

- **文件访问异常**：`strace -f -e trace=%file -s 256 ./app`
- **网络连接异常**：`strace -f -yy -e trace=%network ./app`
- **定位慢系统调用**：`strace -f -ttT -o trace.log ./app`
- **查看调用开销**：`strace -f -c ./app`
- **分析已运行进程**：`strace -f -p <pid>`

选项可以组合使用。排障时可先用 `-e trace=<set>` 缩小范围，再根据需要增加 `-T`、`-s`、`-y` 或 `-o`。
