# Linux 日志体系技术总结

## 一、概述

Linux 日志体系是问题诊断与调试的核心基础设施。完整的日志与环境快照有助于定位启动失败、运行时异常、内核崩溃和关机故障。本文梳理常见日志来源、收集方法、排障流程与 bug report 规范。

---

## 二、Linux 日志体系与数据流

Linux 日志不是单一文件，而是由“日志生产者、内核缓冲区、采集服务、持久化存储和查询工具”组成的链路。典型数据流如下：

```mermaid
flowchart LR
    K["内核 printk()"] --> R[内核 ring buffer]
    R --> D[dmesg]
    R --> M[/dev/kmsg]
    M --> J[systemd-journald]
    A[应用 stdout/stderr] --> J
    S[syslog API / socket] --> J
    J --> JC[journalctl]
    J --> RS[rsyslog]
    S --> RS
    RS --> F["/var/log/messages、syslog 等"]
```

因此，`dmesg`、`journalctl` 和 `/var/log/messages` 的内容可能重叠，但三者并不等价：`dmesg` 只读取当前内核环形缓冲区；journal 可保存内核及用户态结构化日志；传统日志文件则是 rsyslog 按规则筛选、格式化后的文本结果。

### 2.1 `/var/log/messages` 与 `/var/log/syslog`

常见路径如下，具体结果取决于发行版及 `/etc/rsyslog.conf`、`/etc/rsyslog.d/*.conf` 的配置：

- RHEL、CentOS、Rocky Linux、AlmaLinux、SUSE：常用 `/var/log/messages`。
- Debian、Ubuntu：常用 `/var/log/syslog`。
- 仅启用 systemd-journald、未安装或未配置 rsyslog 的系统，可能没有上述文件。

rsyslog 使用 `facility.priority` selector 分流日志。例如 `kern.*` 表示所有内核消息，`*.info` 表示各 facility 中 `info` 及更高严重级别的消息（但通常不含被单独排除的 facility）。传统 syslog 文本一般包含时间戳、主机名、程序名或 tag、PID（可选）和正文：

```text
Sep 04 10:15:32 server01 sshd[2145]: Failed password for invalid user test from 192.0.2.10 port 52144 ssh2
```

常用查询示例：

```bash
# 查看最近 100 行并持续跟踪
sudo tail -n 100 -F /var/log/messages

# 搜索内核错误、警告和调用栈
sudo grep -Ei 'kernel:.*(error|warning|bug|call trace|hardware error)' /var/log/messages
```

文本日志便于直接读取和被传统工具处理，但字段结构较弱，且内容已受 rsyslog 路由规则影响。文件通常由 `logrotate` 轮转，历史日志可能带日期、数字或 `.gz` 后缀。

### 2.2 systemd journal 与 `journalctl`

systemd-journald 收集内核消息、systemd 服务的标准输出/错误、syslog 消息及部分 audit 记录，并保存 `_SYSTEMD_UNIT`、`_PID`、`_UID`、`_COMM`、`PRIORITY` 等结构化字段。`journalctl` 是查询 journal 的客户端，不是日志文件或守护进程。

journal 的存储位置通常为：

- `/run/log/journal/`：易失存储，重启后丢失。
- `/var/log/journal/`：持久存储，可跨启动查询。

`Storage=auto` 是常见默认值：存在 `/var/log/journal/` 时持久化，否则写入 `/run/log/journal/`。如需明确启用持久化，可设置：

```ini
# /etc/systemd/journald.conf
[Journal]
Storage=persistent
SystemMaxUse=1G
```

修改后执行 `sudo systemctl restart systemd-journald`，并用 `sudo journalctl --flush` 将运行时 journal 刷入持久目录。常用查询如下：

```bash
journalctl -b                         # 当前启动
journalctl -b -1                      # 上一次启动
journalctl -k -p warning              # 当前启动的内核 warning 及更严重消息
journalctl -u sshd.service --since -1h
journalctl --since "2026-09-04 10:00:00" --until "2026-09-04 11:00:00"
journalctl -o verbose _PID=2145       # 查看指定 PID 及完整结构化字段
```

可见范围由权限控制：root 通常可读取全部日志；普通用户一般只能读取自身日志，属于 `systemd-journal`、`adm` 或 `wheel` 等授权组时可读取更多系统日志，具体由发行版策略决定。

### 2.3 `dmesg`

`dmesg` 读取内核环形缓冲区，内容来自内核的 `printk()`，覆盖启动探测、驱动加载、设备热插拔、I/O 错误、OOM、soft lockup、Call Trace、Oops 和 panic 等事件。它不包含普通应用日志。

默认时间戳通常是自启动以来的单调时间。`-T` 会换算为本地墙上时间，但系统时间在启动后若被 NTP 或人工调整，换算结果可能不准确；需要关联分析时优先保留原始单调时间，或使用 `journalctl -k`。

```bash
dmesg --level=emerg,alert,crit,err,warn
dmesg -w                             # 持续等待新内核消息
dmesg -x                             # 显示 facility 和 level
dmesg | grep -Ei 'oom|i/o error|call trace|hardware error'
```

内核 ring buffer 容量有限，新消息会覆盖旧消息；重启后通常清空。部分系统设置 `kernel.dmesg_restrict=1`，此时普通用户执行 `dmesg` 会被拒绝，需要 root 或相应 capability。panic 或彻底失去响应时，缓冲区中的最后消息也可能来不及持久化，应结合 pstore、kdump、串口或网络控制台。

### 2.4 `/dev/kmsg` 与 `/proc/kmsg`

两者都是内核消息接口，不是常规日志文件：

- `/proc/kmsg` 是旧式、消费式读取接口，同一时间只允许一个读取者，可能与日志守护进程冲突，不建议直接 `cat`。
- `/dev/kmsg` 是现代字符设备接口，按记录访问并支持独立读取位置，systemd-journald 通常从此处采集内核消息。
- 日常查看应使用 `dmesg` 或 `journalctl -k`，避免与 journald、klogd 等采集进程争用消息。

如需持续观察内核消息，使用：

```bash
sudo dmesg --follow
# 或查询 journal 中持续写入的内核消息
sudo journalctl -k -f
```

---

### 2.5 其他常见日志文件

不同发行版的文件名和分流规则并不完全一致，应先检查 rsyslog 配置及服务自身配置，不应仅凭路径判断日志是否缺失。

| 类别 | RHEL 系常见路径 | Debian 系常见路径 | 主要内容 |
|------|-----------------|-------------------|----------|
| 认证与授权 | `/var/log/secure` | `/var/log/auth.log` | SSH、sudo、PAM 等认证事件 |
| 定时任务 | `/var/log/cron` | `/var/log/syslog` | cron 任务执行记录 |
| 内核文本日志 | `/var/log/messages` | `/var/log/kern.log` | rsyslog 分流后的内核消息 |
| 启动日志 | `/var/log/boot.log` | journal 为主 | 服务启动输出，是否存在取决于配置 |
| 审计日志 | `/var/log/audit/audit.log` | `/var/log/audit/audit.log` | auditd 记录的系统调用与安全事件 |
| 登录历史 | `/var/log/wtmp`、`btmp`、`lastlog` | 同左 | 二进制登录记录，分别用 `last`、`lastb`、`lastlog` 查询 |

服务也可能维护独立日志目录，如 `/var/log/nginx/`、`/var/log/httpd/`、`/var/log/mysql/`。容器环境中，应用通常写到 stdout/stderr，再由容器运行时或集群日志组件采集，不一定写入主机传统日志文件。

```bash
sudo last -n 20
sudo ausearch -m AVC,USER_AUTH -ts today
sudo zgrep -i 'authentication failure' /var/log/secure*
```

### 2.6 日志严重级别

syslog 与内核日志使用 0 至 7 的严重级别，数字越小越严重。执行 `journalctl -p err` 时会显示 `err` 及比它更严重的 `emerg`、`alert`、`crit`，而不只是名称恰好为 `err` 的记录。

| 数值 | 名称 | 含义 |
|------|------|------|
| 0 | `emerg` | 系统不可用 |
| 1 | `alert` | 必须立即处理 |
| 2 | `crit` | 严重故障 |
| 3 | `err` | 错误 |
| 4 | `warning` | 警告 |
| 5 | `notice` | 正常但值得关注 |
| 6 | `info` | 一般信息 |
| 7 | `debug` | 调试信息 |

### 2.7 `sos report`

**用途**：一键收集系统配置、硬件信息、运行状态和各组件日志，适合形成可交付的诊断快照，但不能替代故障发生时的实时日志。

**收集命令**：`sudo sos report --all-logs`。旧版本也接受 `sosreport` 命令。

归档通常输出到 `/var/tmp/`，实际位置以命令结束时的提示为准。归档可能包含 IP、账号、配置和业务信息，对外提供前应审查或脱敏。

**拓展**：sosreport 支持插件机制，可收集特定服务（如网络、存储、虚拟化）的深度信息。可用 `--plugin-disable` 跳过不需要的插件以加速收集。

---

### 2.8 kdump 与 vmcore

**工作原理**：系统保留一块内存区域（`crashkernel=`），当内核遇到致命错误时，跳转到第二内核（kdump kernel），由 kdump initramfs 将第一个内核的内存现场 dump 到磁盘。

是否默认安装或启用取决于发行版版本、安装方案和预留内存，不能仅依据发行版判断。应执行 `systemctl status kdump`（部分 Debian 系为 `kdump-tools`）及 `cat /proc/cmdline`，确认服务状态和 `crashkernel=` 参数。

**输出文件**（`/var/crash/` 下）：
- `vmcore` — 完整内存镜像，用于后期分析
- `vmcore-dmesg.txt` — crash 时刻的环形缓冲区内容

**拓展**：vmcore 文件可能达数十 GB，可用 `makedumpfile` 过滤或压缩，并配置本地、NFS 或 SSH 目标。通常使用与崩溃内核严格匹配且包含调试符号的 `vmlinux` 配合 `crash` 分析；直接使用 GDB 的能力较有限。生产环境需权衡预留内存、转储时间与调试能力。

---

### 2.9 Magic SysRq

**用途**：内核级调试手段，在系统 hang 机时通过命令或组合键触发内核操作。

**使能方法**：
```bash
# 临时使能（重启失效）
echo 1 > /proc/sys/kernel/sysrq

# 永久使能
# /etc/sysctl.conf
kernel.sysrq=1

# 内核 cmdline 参数
sysrq_always_enabled
```

**常用命令**：

| 命令 | 功能 |
|------|------|
| `p` | 打印寄存器、段信息 |
| `t` | 打印所有 task 状态 |
| `m` | 打印内存信息 |
| `w` | 打印阻塞 task 信息 |
| `l` | 打印所有活动 CPU 的栈回溯 |
| `d` | 显示已持有的锁（需内核支持） |
| `s` | 同步文件系统 |
| `u` | 以只读方式重新挂载文件系统 |
| `c` | 触发 crash；配置 kdump 时可生成 vmcore |
| `b` | 强制重启 |

可通过 `echo t | sudo tee /proc/sysrq-trigger` 触发指定动作。故障采集时通常先执行 `t`、`w`、`m`、`l` 获取现场；确需重启时，先执行 `s` 和 `u`，确认控制台输出完成后再执行 `b`。`b` 不执行文件系统同步，可能造成数据损坏。

**注意事项**：部分 BMC 虚拟键盘不能正确发送 SysRq 组合键；应提前验证，并准备 IPMI SOL、串口或直接写 `/proc/sysrq-trigger` 等替代入口。

**拓展**：`kernel.sysrq` 可设为十进制位掩码，仅开放所需功能；例如 `16` 只允许 sync，并非触发 panic。通过 `/proc/sysrq-trigger` 触发操作通常仍对 root 可用，因此还应结合 sudo、主机访问和控制台权限进行限制。

---

### 2.10 串口日志

**核心价值**：在系统启动失败、关机异常等场景下，本机日志服务可能尚未启动或无法落盘。串口日志由外部终端持续接收，是捕获早期启动和崩溃现场的重要渠道，可与 pstore、netconsole、kdump 互补。

**配置流程**：
1. UEFI 中使能串口（Console Redirection）
2. 内核 cmdline 添加 `console=ttySx,115200n8`
3. 通过物理串口线或 IPMI SOL 收集

**grub 修改方式**：
- 临时：启动时在 grub 界面编辑 cmdline
- 永久：修改 `/etc/default/grub`；RHEL 系通常执行 `grub2-mkconfig`，Debian 系通常执行 `update-grub`，目标路径和命令应以发行版文档为准

**拓展**：`console=` 参数可指定多个输出，如 `console=tty0 console=ttyS0,115200n8`，同时输出到显示器和串口。`loglevel=` 参数可控制输出级别，调试时建议设为 8。

---

## 三、日志收集方法体系

### 3.1 通用流程（diff 法）

```bash
# 测试前记录时间点；RFC 3339 格式便于直接传给 journalctl
start_time=$(date --rfc-3339=seconds)

# 执行测试后，按同一时间窗口收集相关来源
sudo journalctl --since "$start_time" -o short-iso > journal-test.log
sudo journalctl -k --since "$start_time" -o short-monotonic > kernel-test.log
sudo dmesg > dmesg-after.log
```

若必须比较文本文件，可在测试前后分别复制一份快照，再执行 `diff -u`。测试期间可能发生日志轮转，直接按固定行号或文件大小截取并不可靠；journal 可按时间、boot ID 和字段过滤，通常比快照差分更准确。

**核心原则**：不删除、不清空、不改写 `/var/log/` 下的任何文件。

### 3.2 基础环境信息

日志必须和主机、内核、启动批次及时区关联，否则时间线容易错位。建议同步收集：

```bash
uname -a
cat /etc/os-release
uptime -s
timedatectl
journalctl --list-boots
```

### 3.3 按问题类型选择日志

| 问题类型 | 必须 log | 辅助手段 |
|---------|---------|---------|
| 启动失败 | 串口日志、`journalctl -b -1` | 固件事件、屏幕信息、pstore |
| 运行时异常 | `journalctl`、`dmesg`、`sos report` | 按时间窗口过滤 |
| 关机问题 | 串口日志、`journalctl -b -1` | 服务超时及 shutdown 时间线 |
| 重启问题 | vmcore + vmcore-dmesg.txt | 串口 log |
| 无响应问题 | SysRq 输出、vmcore、串口日志 | ping、SSH、BMC 和硬件状态交叉判断 |

---

## 四、真假 hung 机判定流程

```
机器"卡住" → ping IP地址
    ├─ 能 ping → 网络栈仍有响应，继续尝试 SSH、控制台和业务探针
    │   ├─ 能登录 → 检查负载、I/O、内存、进程及服务状态
    │   └─ 不能登录 → 检查 sshd、资源耗尽或局部内核阻塞，并用 SysRq 采集现场
    └─ 不能 ping → 检查链路、路由、防火墙、电源及 BMC 控制台
        ├─ 控制台可响应 → 用 SysRq 采集 task、阻塞和内存信息
        └─ 控制台无响应 → 等待 watchdog/kdump，结合 BMC、串口、pstore 或 vmcore 分析
```

ping 失败只能说明 ICMP 路径没有响应，不能直接推断 CPU 不响应中断；SSH 失败也不能单独证明内核异常。应使用多个独立观测点逐步缩小范围。

---

## 五、Bug Report 规范

### 5.1 标题格式

**kernel WARNING**：直接用 log 内容
```
WARNING: CPU: 0 PID: 1 at arch/x86/events/intel/core.c:4695 intel_pmu_init+0x1245/0x144b
```

**kernel BUG**：
```
"BUG: unable to handle kernel NULL pointer dereference at 0000000000000000" triggered by "RIP: 0010:sysrq_handle_crash+0x12/0x20"
```

**Call Trace**：
```
"Call Trace" issue was triggered by __handle_sysrq+0x7b/0x140
```

**Hardware Error**：
```
[Hardware Error]: Hardware error from APEI Generic Hardware Error Source: 512
```

### 5.2 报告必备信息

- 问题描述（清晰、可复现步骤）
- 环境详情（CPU、内存、磁盘硬件配置；UEFI/BMC固件版本；驱动信息；内核版本）
- 期望结果 vs 实际结果
- 附件（截图、录像、对应类型的 log 文件）

### 5.3 判定原则

- 同设备、短时间内（如 5 秒内）的相邻 log 合并为一个 case
- 日志级别不等同于影响程度；应用报错即使暂未表现为功能异常，也应结合上下文、频率和基线判断，不宜直接忽略
- 使用 `journalctl -p err` 初筛高优先级事件，使用 `journalctl -k` 或 `_TRANSPORT=kernel` 明确筛选内核日志
- 保留故障前后完整时间窗口，不只截取关键字命中的单行；Call Trace、OOM 和 I/O 错误通常需要上下文

---

## 六、最佳实践与拓展建议

### 6.1 测试前准备

- 记录测试前基线；不要假设干净安装完全没有 warning 或 error
- 使能 sysrq、配置网络 IP（可 ping 通）、配置串口 log
- 单系统测试（避免多系统引导干扰）

### 6.2 日志管理建议（拓展）

- **集中日志**：生产环境部署 ELK（Elasticsearch + Logstash + Kibana）或 EFK（Fluentd 替代 Logstash）栈，实现日志集中收集、索引和可视化
- **日志监控**：使用 Loki/Promtail、Elasticsearch 或其他日志管道建立检索与告警；Prometheus 更适合指标，Falco 更侧重运行时安全事件
- **审计日志**：使用 `auditd` 记录敏感操作，满足合规需求
- **日志安全**：遵循发行版默认所有权、ACL 与最小权限原则；不要对 journal 或轮转文件盲目执行统一 `chmod`

### 6.3 内核调试进阶（拓展）

- **kprobes/ftrace**：动态追踪内核函数调用，无需修改源码
- **eBPF**：eBPF 于 Linux 3.18 合入，后续版本持续增强；可借助 BCC、bpftrace 或 libbpf 进行低开销观测
- **Kernel Selftests**：利用内核自带测试套件验证功能正确性
- **perf**：系统级性能分析工具，结合 `perf record` / `perf report` 定位热点

### 6.4 日志白名单管理

- 白名单应绑定组件版本、消息来源、匹配条件、风险说明和失效日期，避免永久隐藏新故障
- 只有确认消息无实际影响且已有缺陷记录或产品基线依据时才加入白名单；网络搜索结果不能替代复现与根因分析

---

## 七、总结

### 7.1 常用日志结构对比

| 对象 | 数据来源 | 数据范围 | 格式与位置 | 重启后保留 | 主要优势 | 主要限制 |
|------|----------|----------|------------|------------|----------|----------|
| `dmesg` | 内核 ring buffer | 仅内核 | 内存；命令输出 | 通常否 | 接近内核原始消息，适合驱动和硬件排障 | 容量有限、会覆盖，不含用户态日志 |
| `journalctl -k` | journald 采集的内核消息 | 仅内核 | 二进制 journal | 取决于 journal 是否持久化 | 可按 boot、时间和级别查询 | 采集前或未落盘的消息可能缺失 |
| `journalctl` | 内核、systemd、服务 stdout/stderr、syslog 等 | 系统综合日志 | `/run/log/journal/` 或 `/var/log/journal/` | 取决于配置 | 字段结构化，过滤和跨启动查询能力强 | 需专用工具读取，权限策略较细 |
| `/var/log/messages` | rsyslog 路由结果 | RHEL 系综合日志，常含内核和服务消息 | 文本文件 | 是，受轮转策略限制 | 通用文本工具即可处理 | 内容依赖规则，字段较弱，可能不存在 |
| `/var/log/syslog` | rsyslog 路由结果 | Debian 系综合日志 | 文本文件 | 是，受轮转策略限制 | 易读取、易转发 | 内容依赖规则，可能与 journal 重复 |
| `/var/log/kern.log` | rsyslog 的 `kern.*` 分流 | 内核 | 文本文件 | 是，受轮转策略限制 | 内核消息独立归档 | 并非所有发行版默认生成 |
| `/dev/kmsg`、`/proc/kmsg` | 内核消息接口 | 仅内核 | 字符设备/伪文件 | 否 | 供日志守护进程实时采集 | 不适合日常直接读取，可能干扰消费者 |
| `vmcore-dmesg.txt` | 崩溃内核内存现场 | 崩溃时内核消息 | `/var/crash/` 文本文件 | 是 | 保留 panic 时关键上下文 | 依赖 kdump 正确配置并成功执行 |
| 串口或 netconsole | 内核控制台输出 | 启动、运行及崩溃阶段 | 外部接收端 | 由接收端决定 | 本机存储失效时仍可能保留输出 | 需要提前配置，输出量受 loglevel 影响 |

### 7.2 选择原则

日常服务排障优先使用 `journalctl`，内核和驱动问题同时查看 `dmesg` 与 `journalctl -k`，需要兼容传统工具或集中转发时检查 `/var/log/messages` 或 `/var/log/syslog`。对于 panic、启动失败和完全无响应，应提前部署 kdump、pstore、串口或 netconsole；故障发生后再配置通常无法恢复现场。
