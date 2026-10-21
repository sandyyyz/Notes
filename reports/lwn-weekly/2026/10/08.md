# LWN 每周热点议题技术摘要（内核专题）

> **观察周期：** 2026-09-18 至 2026-10-08  
> **整理时间：** 2026-10-08  
> **范围说明：** 以 LWN 内核专题页面、Kernel Recipes 2026 大会报道及该周期内全部内核方向条目为主。本报告中，9 月 18 日之前的条目仅作为上下文引用。部分 LWN 深度文章可能需要订阅后阅读全文。

## 1. io_uring 线程身份切换：以激进方案消除异步阻塞开销

io_uring 子系统的设计核心是不阻塞应用线程——除非应用显式要求阻塞。然而维持这一"永不阻塞"保证一直颇具挑战，因为内核中大量代码路径并非为异步执行而设计。当前实现中，任何可能阻塞的操作都会被提前分配到独立的工作线程执行，即使该操作实际上并不会阻塞，这种"提前放弃"的代价是显著的性能开销。

**原文：** [Thread-identity switcheroo for io_uring](https://lwn.net/Articles/1094303/) · [RFC 补丁集](https://lwn.net/ml/all/20260911154148.644489-1-axboe@kernel.dk)

Jens Axboe 提出的方案核心在于"线程身份交接"（thread identity handoff）。实现方式是在 `task_struct` 中引入新标志 `PF_IO_HANDOFF`，并通过调度器挂钩实现阻塞检测：当设置了该标志的线程即将进入阻塞状态时，调度器调用 `io_uring_task_sleeping()` 通知 io_uring 子系统。io_uring 随后从线程池中选出一个工作线程，**交换两个线程的身份**——工作线程获得原始线程的 ID、信号处理上下文等全部属性，继续处理提交环；而原始线程则获得工作线程的身份并进入阻塞。关键安全机制在于：身份交换前必须确保内核中没有其他引用指向这两个 `task_struct`，否则会导致严重的安全隐患。

该方案设置了严格的交换前置条件检查（`thread_handoff_allowed()` / `thread_handoff_compatible()`），包括 ptrace 追踪、perf 事件、futex 所有权、实时调度器、核心调度 cookie、`vfork()` 等场景均禁止交换。社区反馈显示，这是该补丁集最脆弱的部分——`task_struct` 在内核中被广泛引用，穷尽所有可能引用的可能性本身就是一个持续的挑战。

性能数据方面，在 tmpfs 上执行的 `fsync()` 基准测试显示近 700% 的提升；但高队列深度场景下可能出现回归，因为提前分配工作线程允许并行执行，而身份交接将工作序列化到阻塞点。

**关注意义：** 该方案若成功合并，将是 io_uring 自诞生以来最重要的架构演进之一。风险在于 `task_struct` 身份交换的长期维护成本。Peter Zijlstra 指出 shadow stack 的存在可能使大多数已部署系统无法使用该特性，Axboe 则认为 shadow stack 可以随身份一起迁移。

**参考：** [LWN io_uring coverage](https://lwn.net/Kernel/Index/#io_uring) · [task_struct 定义](https://elixir.bootlin.com/linux/v7.2.5/source/include/linux/sched.h#L826)

## 2. BPF 驱动 blk-iocost：为固态 I/O 调度注入可编程成本模型

块 I/O 调度在旋转磁盘时代以请求排序为核心，而在 SSD 时代，调度器的主要职责是在高速设备（每秒可执行数百万 I/O 操作）上维持竞争用户间的公平性。blk-iocost I/O 控制器通过为不同 cgroup 分配"成本"来控制 I/O 速率，核心机制是每设备虚拟时钟（vtime）和每 cgroup vtime 的差异化推进——只有当 cgroup 的 vtime 落后于设备 vtime 足够多时，才允许 dispatch 新请求。

**原文：** [Adding BPF to blk-iocost](https://lwn.net/Articles/1093661/) · [补丁集](https://lwn.net/ml/all/20260914073356.791518-1-cui.tao@linux.dev)

Tao Cui 的补丁集通过引入新的 `struct_ops` 程序类型 `iocost_model_ops`，使 BPF 程序可以自定义 I/O 成本计算函数。核心接口 `calc_cost()` 接收操作标志（读/写/flush 等）、字节数、扇区位置、cgroup 引用和合并标志，返回该请求的成本值。此外还提供了可选的 `blkcg_online()` / `blkcg_offline()` 生命周期钩子。

当前 blk-iocost 的成本模型存在两个固有缺陷：其一，多进程并发执行顺序 I/O 时，交织的请求模式会被误判为随机 I/O（随机成本是顺序的 112 倍），导致该 cgroup 受到不公正惩罚；其二，小窗口内的随机 I/O 可能被误判为顺序 I/O，造成反向不公。补丁集附带的示例 BPF 程序使用 BPF map 追踪最多 4 个独立 I/O 流，在流内判断顺序性，有效缓解了多进程顺序 I/O 被误判的问题。

从架构角度看，BPF 的引入将 blk-iocost 从静态启发式升级为可编程成本引擎。BPF 程序可以直接读取设备统计、队列深度、请求类型和时序信息，从而计算比固定权重更精细的成本值——例如根据 QLC NAND 写放大动态调整写入成本，或根据设备温度降速保护硬件。关键约束是 BPF 成本函数必须在每次 I/O 调用中执行，复杂度必须严格控制以避免成为调度瓶颈。

**关注意义：** 对多租户存储、容器化平台和高性能数据库而言，可定制的 I/O 成本模型意味着更精确的公平性控制和 QoS 保障。建议在测试环境中使用 `bpftrace` 的 `kprobe` 验证 BPF 成本函数的执行延迟。

**参考：** [blk-iocost kernel documentation](https://docs.kernel.org/admin-guide/cgroup-v1/blkiocost.html) · [BPF struct_ops](https://lwn.net/Articles/811631/)

## 3. Sashiko：LLM 驱动的内核补丁审查系统进展

补丁审查长期是 Linux 内核项目（以及多数开源项目）的瓶颈——提交代码的增长速度远超可用审查人力。Sashiko 系统利用大型语言模型自动生成补丁审查意见，为这一困境提供了缓解路径。

**原文：** [An update on the Sashiko patch-review system](https://lwn.net/Articles/1096963/) · [Kernel Recipes 2026](https://kernel-recipes.org/en/2026/)

Sashiko 的工作流程包含三个阶段：首先是补丁预处理，将邮件列表中的补丁序列化为 LLM 可理解的格式；其次是 LLM 推理，利用训练好的模型生成关于代码风格、潜在 bug、API 一致性和性能影响的审查意见；最后是结果后处理，将 LLM 输出格式化为符合内核邮件列表规范的审查邮件。

关键设计决策在于 Sashiko 不替代人类审查者，而是生成初步审查意见供维护者参考。系统当前改进方向包括：提高对子系统特定知识的理解能力、减少误报率、以及更好的上下文感知——例如识别补丁所属的更大功能集的背景，而非孤立审查单个补丁。Sashiko 已经在内核开发流程中成为重要组成部分，特别是在处理大量驱动补丁和自测试代码时。

**关注意义：** LLM 辅助审查的核心价值不在于替代人类判断，而在于将维护者从重复性的模式匹配工作中解放出来。对于其他大型开源项目，Sashiko 的架构模式——预处理、LLM 推理、后处理和人类终审——提供了可参考的实施路径。

**参考：** [Kernel Recipes 2026](https://kernel-recipes.org/en/2026/) · [Sashiko 项目](https://github.com/romang/sashiko)

## 4. 应对 LLM 引发的内核安全漏洞潮

大语言模型降低了安全漏洞发现的技术门槛，几乎所有自由软件项目都面临着由 AI 辅助生成的海量漏洞报告。在 Kernel Recipes 2026 大会上，Greg Kroah-Hartman 分享了内核安全团队应对这一洪流的经验，其核心信息是"don't panic"。

**原文：** [Coping with the onslaught of kernel security bugs](https://lwn.net/Articles/1096908/) · [Kernel Recipes 2026](https://kernel-recipes.org/en/2026/)

LLM 生成的漏洞报告呈现两个显著特征：一是数量呈数量级增长，单个维护者每天可能收到数十份报告；二是质量参差不齐——大量报告存在误报、重复描述或无法复现的问题。内核安全团队建立的应对策略包括：自动化报告分类，将明显误报自动归档；建立优先级排序机制，根据漏洞类型、影响范围和可利用性对报告分级；以及引入人工复核环节，确保每一份报告都经过验证后再分配给子系统维护者。

**关注意义：** 安全团队需要建立自动化分诊流程来处理 AI 生成的漏洞报告潮。建议采用"自动化过滤 + 人工复核"的二级策略，同时关注 LLM 报告的特征变化——随着模型能力提升，未来报告的准确率可能提高，分诊策略需要动态调整。

**参考：** [LWN 报道](https://lwn.net/Articles/1096908/) · [Kernel Recipes 2026](https://kernel-recipes.org/en/2026/)

## 5. LAVD 调度器：从游戏低延迟到通用服务器场景

基于 `sched_ext` BPF 可扩展调度器框架，LAVD（Latency-criticality Aware Virtual Deadline）调度器最初为 Linux 游戏工作负载设计，旨在改善交互性和减少画面卡顿。Changwoo Min 和 Gavin Guo 在 Kernel Recipes 2026 大会上分享了该调度器从游戏场景扩展为通用服务器调度器的演进历程。

**原文：** [Evolving the LAVD scheduler from gaming to servers](https://lwn.net/Articles/1097209/) · [scx_lavd](https://github.com/sched-ext/scx/tree/main/scheds/rust/scx_lavd)

LAVD 的核心思想是量化任务的延迟敏感度，并将该信息用于动态调整截止时间（deadline）和时间片。调度器分为 BPF 内核态组件（负责所有调度决策）和 Rust 用户态组件（提供 CPU 拓扑信息、加载 BPF 程序和处理采样输出）。与传统的 CFS 调度器不同，LAVD 不是基于优先级或运行时长，而是根据任务的实际延迟需求来分配 CPU 资源。

调度器为每个 LLC、每个核心类型（Intel P/E 核、ARM big/LITTLE）和每个 NUMA 域创建独立的调度域，这意味着默认配置下即可在多核异构平台上获得较好的性能。LAVD 目前主要针对单 CCX/单路系统优化，在多路服务器上的跨 NUMA 调度策略仍有改进空间。

**关注意义：** `sched_ext` 生态正在快速成熟，LAVD 的演进路径展示了 BPF 调度器从"特定场景实验"走向"生产可用"的过程。对于需要在同一物理机上混合运行延迟敏感和吞吐型工作负载的场景，LAVD 提供了一种比传统 cgroup 静态隔离更自适应的替代方案。

**参考：** [sched_ext 项目](https://github.com/sched-ext/scx) · [LAVD README](https://github.com/sched-ext/scx/blob/main/scheds/rust/scx_lavd/README.md)

## 6. gccrs 编译内核：名称解析与 core crate 攻坚

gccrs 项目（GCC 的 Rust 前端）的目标是使 GCC 能够独立编译内核中的 Rust 代码。在 RustConf 2026 和 Kangrejos 2026 上，Pierre-Emmanuel Patry 和 Arthur Cohen 汇报了进展：当前目标是让 gccrs 能够编译内核 Rust 代码的基础依赖——`core` crate。

**原文：** [Compiling the kernel with gccrs](https://lwn.net/Articles/1095553/) · [gccrs 项目](https://rust-gcc.github.io/)

名称解析是过去三年的主要攻坚方向。Rust 的名称解析涉及多个独立命名空间（函数/常量、类型、标签、生命周期），且名称解析与宏扩展必须以不动点（fix-point）方式交替运行——重复执行直到所有名称被发现。Cohen 最初估计此项工作耗时三周，实际耗时近三年。引入缓存后，`core` crate（约 85,000 行代码）的编译时间从 42 分钟降至 3 分钟（rustc 为 30 秒）。

其他进展包括：声明式宏扩展已工作、内联汇编支持和 `lang_items` 系统基本可用、`Drop` trait 处理（GSoC 参与者 Janet Chien 负责）已覆盖常见用例。下一步是向上推进依赖图编译 `alloc` crate，然后追赶稳定版 Rust 的语言特性，包括 trait upcasting、`use<...>` 语法和 RPITIT（return-position impl Trait in traits）。

**关注意义：** gccrs 的成功将使内核能够仅使用 GCC 完成全部编译，减少对 rustc 的依赖。对于支持更多后端架构的场景（GCC 覆盖的架构远超 rustc），这是重要的工程目标。

**参考：** [gccrs 项目](https://rust-gcc.github.io/) · [内核 Rust core crate](https://rust.docs.kernel.org/core/index.html)

## 7. PostgreSQL 视角下的内核痛点与机会

Andres Freund 在 Kernel Recipes 2026 上系统分享了 PostgreSQL 与 Linux 内核交互中遇到的痛点和改进机会。核心问题集中在可扩展性、内存管理和 I/O 子系统三个方向。

**原文：** [The kernel from a PostgreSQL point of view](https://lwn.net/Articles/1096827/) · [演讲视频](https://www.youtube.com/watch?v=isATpooTax8)

可扩展性方面，Freund 展示了 PostgreSQL 查询处理能力随客户端数量增长的非线性变化——在特定区间性能会骤降并进入平台期，直到负载足够大能将 CPU 维持在高功率状态才恢复。禁用 `cpuidle` 子系统可以"解决"该问题，说明 CPU 空闲状态管理与工作负载的交互是根本原因。

内存管理方面，透明大页（THP）不支持程序文本是一个长期痛点——`READ_ONLY_THP_FOR_FS` hack 帮助有限且正在被移除。OOM 处理在 cgroup 中行为不一致：`vm.overcommit_memory=2` 模式在 cgroup 内仅在系统整体内存耗尽时才生效，使 cgroup 对禁用超分的应用管理员基本失效。

I/O 子系统方面，PostgreSQL 正在向异步 I/O 模型演进，io_uring 是当前重点方向。但 io_uring reserved buffers 存在 1GB 限制，强制 PostgreSQL 使用更小的写入。futex 仅 32 位应用信息空间不足，hash 查找在部分场景下消耗 25% CPU。1GB 大页因 folio head 争用反而可能导致性能减半。

**关注意义：** PostgreSQL 遇到的许多内核问题并非特定于数据库，而是具有普遍性。writeback 和 reclaim 已有 2-4 倍的改进，`RWF_ATOMIC` 的加入是重大进步。但可扩展性和内存管理方面仍有大量工作需要内核和应用层协作。

**参考：** [演讲幻灯片](https://anarazel.de/talks/2026-09-23-kernel-recipes-postgres-linux/linux-postgres.pdf) · [atomic writes kernel index](https://lwn.net/Kernel/Index/#Atomic_IO_operations)

## 8. 内核构建加速：23 个补丁的 LLM 辅助系统性优化

内核构建系统复杂度极高，Lorenzo Stoakes 在 LLM 辅助下对构建流程进行了系统性优化，通过 23 个补丁实现了显著的加速效果：allmodconfig 构建最多提速 36%，增量构建最多提速约 70%，noop 构建最多提速约 90%。

**原文：** [Accelerating the kernel's build process](https://lwn.net/Articles/1093398/) · [补丁集](https://lwn.net/ml/all/20260908-build-speedup-v1-0-5dc1ac01672d@kernel.org)

具体优化方向包括：`kallsyms` 压缩算法优化（追踪 token 出现位置避免无效替换，+2-6%）、`kallsyms` 直接输出二进制数据替代 37MB 汇编文件（+11%）、`nm` 排序去除（构建过程不需要排序输出）、链接阶段不生成重定位数据、`depcheck` 工具替代 make 的单线程依赖检查、编译器功能探测结果缓存、`modpost` 哈希并行化和 per-file 处理、模块最终化步骤批处理、Rust crate 并行编译（利用 `rustc -Zthreads`）、以及使用 `pigz` 并行压缩内核镜像。

值得注意的是，Linus Torvalds 对部分优化提出了更激进的建议：`kallsyms` 应直接输出 ELF 对象文件，完全跳过汇编器；依赖检查的许多 hack 来自 25 年前，可能已无需保留。社区对构建系统工具本身的讨论也引发了关于 GNU Make 在现代构建中角色的辩论。

**关注意义：** 这些优化不仅在开发者机器上有意义，对全球无数 CI 系统的碳足迹也有直接影响。Stoakes 的系统表明 LLM 在理解和优化复杂遗留系统方面具有实际价值。

**参考：** [Kernel kbuild documentation](https://docs.kernel.org/kbuild/kbuild.html) · [kallsyms 源码](https://elixir.bootlin.com/linux/v7.2.2/source/scripts/kallsyms.c)

## 9. RSEQ 操作与 TCMalloc 回归修复

重启序列（restartable sequences）特性为无锁用户态操作提供了被抢占通知机制。6.19 版本中对 rseq 的性能优化意外破坏了 TCMalloc 分配器——该分配器利用了 rseq API 的一个未记录行为（向文档标注为只读的 `cpu_id_start` 字段写入哨兵值）。

**原文：** [Fixing the TCMalloc regression with RSEQ operations](https://lwn.net/Articles/1092555/) · [RFC 补丁集](https://lwn.net/ml/all/20260828153349.8061-1-odion@efficios.com)

Olivier Dion 提出的解决方案是"RSEQ 操作"机制——允许用户态注册一组操作，内核在每次返回用户态时执行。三种操作类型包括：`RSEQ_OP_RESET`（将内存字重置为指定值）、`RSEQ_OP_RESET_WITH_STRIDE_CPUID`（按 CPU ID 索引重置数组）和 `RSEQ_OP_RESET_WITH_STRIDE_MMCID`（按 vCPU ID 索引）。操作描述结构通过 `prctl()` 的 `PR_RSEQ_OP` 注册，以双向链表组织，上限 2,048 个操作。

一个有趣的设计决策是：操作描述结构保留在用户态内存中，内核通过用户态内存访问原语操作它。Dmitry Vyukov 建议将结构移到内核侧，Florian Weimer 则担忧这会演变为"重新实现 BPF"。Thomas Gleixner 提出了替代方案，将更多工作推向用户态而非在内核中添加新的解释器。

**关注意义：** 该问题展示了内核 API 优化与用户态兼容性的经典矛盾。最终方案的选择将影响 rseq 子系统未来的演进方向。

**参考：** [rseq 内核文档](https://docs.kernel.org/userspace-api/rseq.html) · [TCMalloc 项目](https://github.com/google/tcmalloc)

## 10. Linux 7.3 稳定化进展与内核动态

7.3-rc6 于 10 月 5 日发布。Linus Torvalds 提到下周将举行年度维护者峰会和 Linux Plumbers 会议，他本人将在路上，这可能会影响 -rc7 的补丁统计。下一个合并窗口可能因他的年度家庭假期而有所变化。

**原文：** [7.3-rc6 报道](https://lwn.net/Articles/1098476/)

10 月 3 日，Greg Kroah-Hartman 发布了 7.2.9、6.18.55、6.12.112、6.6.158、6.1.189、5.15.222 和 5.10.271 共 7 个稳定内核版本，每个版本均包含大量重要修复。

**原文：** [7 个稳定内核版本](https://lwn.net/Articles/1098404/)

Linux Test Project 发布了 2026 年 9 月稳定版，包含 382 个补丁和 41 位作者的贡献。

**原文：** [LTP 9 月发布](https://lwn.net/Articles/1098313/)

## 本周总体判断

本周期内核议题呈现三条主线。

其一，io_uring 和 BPF 生态持续深化。io_uring 的线程身份切换方案虽然激进，但代表了 Linux 异步 I/O 基础设施向"零代价不阻塞"目标的又一次推进；BPF 驱动 blk-iocost 则将可编程调度从 CPU 层面扩展到了 I/O 层面，进一步巩固了 BPF 作为内核可编程框架的核心地位。

其二，内核工具链和基础设施正在经历现代化改造。gccrs 在名称解析上的三年攻坚终于接近 `core` crate 可编译的阶段；构建系统的 LLM 辅助优化证明遗留代码的现代化可以借助 AI 工具加速完成；Sashiko 将 LLM 引入补丁审查流程，代表了内核开发流程本身的智能化。

其三，应用层与内核的协作边界正在重新定义。PostgreSQL 团队在 Kernel Recipes 上的系统性反馈表明，数据库内核交互痛点已经从"可用"走向"调优"；TCMalloc 与 rseq 的兼容性冲突则展示了内核 API 演化中"用户态利用未记录行为"这一经典难题。

对内核工程人员而言，最值得持续跟踪的是 io_uring 线程身份切换方案的社区反馈和安全审计进展、LAVD 在多路服务器上的调度策略演化、以及 gccrs 从 core crate 可编译到实际可启动内核的下一阶段目标。

**来源汇总：** [LWN Kernel coverage](https://lwn.net/Kernel/) · [Kernel Recipes 2026](https://kernel-recipes.org/en/2026/) · [RustConf 2026](https://rustconf.com/) · [Kangrejos 2026](https://kangrejos.com/)
