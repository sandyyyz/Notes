# ftrace

`ftrace` 是 Linux 内核内建 tracing 框架及相关 utilities 的统称，其控制接口位于 `/sys/kernel/tracing` 或 `/sys/kernel/debug/tracing`。它适合观察内核函数调用、tracepoint 事件、调度延迟和中断/抢占关闭时间等问题。

## 能力边界

| 能力 | 说明 |
| --- | --- |
| function tracing | 记录函数入口，适合快速定位调用路径 |
| function graph tracing | 记录函数进入/返回和耗时，适合分析调用栈与延迟 |
| event tracing | 基于静态 tracepoint，语义稳定、开销更可控 |
| latency tracing | 记录 irq/preempt/wakeup 等最大延迟路径 |
| filter/trigger | 按函数、PID、事件条件动态缩小追踪范围 |

## 使用方法

> 依据 [ftrace — Linux Kernel Documentation](https://docs.kernel.org/trace/ftrace.html)，时间单位均为微秒。

### 架构总览

所有操作均通过 tracefs 文件系统完成：写入控制文件选择 tracer 与过滤条件，内核将事件写入 per-CPU ring buffer，再经输出文件读取。

```text
              tracefs (/sys/kernel/tracing)
                          │
      ┌───────────────────┼────────────────────┐
      ▼                   ▼                    ▼
  tracer 选择          事件控制             过滤 / 触发
  current_tracer      events/, set_event    set_ftrace_filter
  available_tracers   set_event_pid         set_ftrace_pid
      │                   │                  set_graph_function
      └─────────┬─────────┴──────────────────┘
                ▼
      ring buffer（per-CPU，可配 snapshot 备份）
                │
      ┌─────────┴──────────┐
      ▼                    ▼
  trace（静态快照）    trace_pipe（流式消费读）
```

### 典型工作流

```sh
cd /sys/kernel/tracing

echo 0 > tracing_on                      # 1. 先暂停写入 ring buffer
cat available_tracers                     # 2. 查看内核已编译的 tracer
echo function_graph > current_tracer      # 3. 选定 tracer（切换会清空 buffer）
echo 'schedule' > set_ftrace_filter       # 4. 限定追踪的函数（可选）
echo 1 > tracing_on                       # 5. 开始追踪，运行目标负载
echo 0 > tracing_on                       # 6. 停止追踪
cat trace                                 # 7. 读取结果
```

### 常用 tracer

| Tracer | 用途 |
| --- | --- |
| `function` | 追踪所有内核函数调用 |
| `function_graph` | 在函数入口与返回处探测，输出类似 C 源码的调用图与耗时 |
| `irqsoff` | 记录关中断最长的一次 latency 及其 trace |
| `preemptoff` | 类似 `irqsoff`，但追踪抢占被禁用的时长 |
| `preemptirqsoff` | 追踪中断和/或抢占被禁用的最长时长 |
| `wakeup` / `wakeup_rt` / `wakeup_dl` | 记录任务（任意 / RT / `SCHED_DEADLINE`）被唤醒到实际调度之间的最大 latency |
| `hwlat` | 硬件延迟检测器 |
| `mmiotrace` | 追踪模块对硬件的二进制 I/O 读写 |
| `branch` | 追踪 `likely`/`unlikely` 分支预测命中情况 |
| `blk` | 块层 tracer，供 `blktrace` 使用 |
| `nop` | 不追踪任何事件，用于清除 tracer |

### 关键控制文件

| 文件 | 作用 |
| --- | --- |
| `current_tracer` | 设置或显示当前 tracer |
| `available_tracers` | 内核已编译的 tracer 列表 |
| `tracing_on` | ring buffer 写入开关（`0` 禁用 / `1` 启用） |
| `trace` | 人类可读的 trace 输出（静态，非消费读） |
| `trace_pipe` | 流式实时输出（消费读，读后即清除） |
| `trace_options` / `options/` | 控制输出内容与 tracer 行为（如 `sym-offset`、`latency-format`） |
| `set_ftrace_filter` | 限定 `function`/`function_graph` 追踪的函数 |
| `set_ftrace_notrace` | 排除指定函数（与 filter 冲突时优先） |
| `set_ftrace_pid` / `set_event_pid` | 仅追踪指定 PID 的线程（函数 / 事件） |
| `set_graph_function` | 限定 function graph 追踪的函数及其调用链 |
| `available_filter_functions` | 可写入上述 filter 文件的函数列表 |
| `tracing_max_latency` | 当前记录的最大 latency；写入数值可设阈值 |
| `tracing_thresh` | latency tracer 仅记录超过该阈值的延迟 |
| `buffer_size_kb` | 每 CPU buffer 大小（KB） |
| `trace_clock` | 时间戳时钟源（`local`/`global`/`counter`/`x86-tsc` 等） |
| `trace_marker` | 用户空间写入标记，用于与内核事件对齐时间线 |
| `snapshot` | 对当前 trace 做快照到备份 buffer |
| `events/` / `set_event` | 静态 tracepoint 事件目录与使能接口 |
| `instances/` | 创建多个独立 trace buffer 实例 |

### Filter commands

写入 `set_ftrace_filter` 的命令格式为 `<function>:<command>:<parameter>`：

| 命令 | 作用 | 示例 |
| --- | --- | --- |
| `mod` | 按模块过滤函数 | `echo 'write*:mod:ext3' > set_ftrace_filter` |
| `traceon` / `traceoff` | 命中函数时开启/停止追踪（可限次数） | `echo '__schedule_bug:traceoff:5' > set_ftrace_filter` |
| `snapshot` | 命中函数时触发快照 | `echo 'native_flush_tlb_others:snapshot' > set_ftrace_filter` |
| `enable_event` / `disable_event` | 命中函数时使能/禁用 trace 事件 | `echo 'try_to_wake_up:enable_event:sched:sched_switch:2' > set_ftrace_filter` |
| `dump` | 命中函数时将 ring buffer 全部输出到控制台 | — |
| `cpudump` | 同上，但仅输出当前 CPU 的 buffer | — |
| `stacktrace` | 命中函数时记录栈回溯 | — |

命令为累积式；删除时加 `!` 前缀并去掉次数参数，如 `echo '!__schedule_bug:traceoff' > set_ftrace_filter`。

## 案例：在 RHEL 9.7 上构建 `test_hmm` 模块

### 环境

| 项目 | 值 |
| --- | --- |
| 发行版 | Red Hat Enterprise Linux 9.7 |
| 内核 | 5.14.0-611.5.1.el9_7.x86_64 |

### 检查内核配置

```sh
KREL=$(uname -r)

echo "Kernel: $KREL"

grep -E 'CONFIG_(TEST_HMM|HMM_MIRROR|DEVICE_PRIVATE|TRANSPARENT_HUGEPAGE)=' \
    /boot/config-"$KREL"

find /lib/modules/"$KREL" -name 'test_hmm.ko*'

modinfo test_hmm
```

输出：

```text
Kernel: 5.14.0-611.5.1.el9_7.x86_64
CONFIG_TRANSPARENT_HUGEPAGE=y
CONFIG_HMM_MIRROR=y
CONFIG_DEVICE_PRIVATE=y
CONFIG_TEST_HMM=m
modinfo: ERROR: Module test_hmm not found.
```

### 结论

`CONFIG_TEST_HMM=m` 表明 RHEL 构建配置启用了该模块，但 `modinfo test_hmm` 失败说明当前安装的内核包并未交付它。因此需要获取对应 RHEL 内核源码并单独构建该模块。

### 准备构建环境

安装下载与构建工具：

```sh
dnf install dnf-plugins-core rpm-build rpmdevtools
```

确认已安装的内核包：

```sh
rpm -q --qf '%{NAME}-%{VERSION}-%{RELEASE}.%{ARCH}\n' kernel-core
```

输出：

```text
kernel-core-5.14.0-611.5.1.el9_7.x86_64
kernel-core-5.14.0-503.40.1.el9.x86_64
```

接下来下载 SRPM 包：

```sh

dnf download --source <kernel_version>

```
编译 `lib/` 目录下的内容会形成多个 kernel module，通常无法只对其中一个目标做完全独立构建：

```sh
make -C "$KDIR" \
    M="$PWD" \
    V=1 \
    modules
```

这里实际只需要 `hmm_test.ko` 并将其 install 到当前 kernel module 目录，同时构建 `tools/testing/selftests/mm` 下的测试程序（主要是 `hmm-test`），以保证 `test_hmm.sh` 可以正确运行 HMM 测试。


### 测试流程

1. `test_hmm` kernel module 为每个模拟设备内存注册 `ZONE_DEVICE` 页面以及回调（`dmirror_devmem_ops`），并为每个模拟设备注册字符设备入口（`dmirror_fops`）。
2. `TEST_F` 展开对应测试代码和每个测试实例 private 的 `FIXTURE`，测试体通过 `self` 引用 fixture 状态。
3. 调用 `FIXTURE_SETUP`，该函数会调用 `hmm_test.c` 封装的 `hmm_open`，打开 driver 对应的字符设备并初始化 `self->fd`。
4. 测试流程中调用 `hmm-test.c` 封装的函数，最终进入 `hmm_dmirror_cmd`，底层通过 `ioctl` 向 driver 发送请求。
5. 使用 `hmm-test -l` 列出支持的测例，使用 `hmm-test -r <name>` 指定需要运行的测例。

`dmirror`: Data attached to the open device file, like:  

```c
/*
 * Data attached to the open device file.
 * Note that it might be shared after a fork().
 */
struct dmirror {
	struct dmirror_device		*mdevice;
	struct xarray			pt;
	struct mmu_interval_notifier	notifier;
	struct mutex			mutex;
};
```

#### anon_read

在这个测试流程中，`dmirror`实际上是设备对应的私有内存。而`dmirror->pt`是模拟设备页表
而`bounce->ptr`模拟设备内部的接收缓冲区.
`buffer->ptr`为将被设备读取的system memory
`buffer->mirror`为用户态从设备获取的读取结果

```c

/* hmm_dmirror_cmd */
...
/* Simulate a device reading system memory. */
	cmd.addr = (__u64)buffer->ptr;
	cmd.ptr = (__u64)buffer->mirror;
	cmd.npages = npages;

/* dmirror_fops_unlocked_ioctl */
dmirror = filp->private_data
/*dmirror_bounce_init */
bounce->addr = buffer->ptr

```

## References

- [ftrace — Linux Kernel Documentation](https://docs.kernel.org/trace/ftrace.html)
