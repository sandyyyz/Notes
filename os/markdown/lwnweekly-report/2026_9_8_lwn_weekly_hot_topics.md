# LWN 每周热点议题技术摘要

> **观察周期：** 2026-09-01 至 2026-09-08  
> **整理时间：** 2026-09-08  
> **范围说明：** 以 LWN 首页、2026-09-03 Weekly Edition 及随后发布的重要条目为主，优先选取 Linux 内核、内存管理与基础设施方向。部分 LWN 深度文章可能需要订阅后阅读全文。

## 1. Linux 7.3-rc2：合并窗口后修复量偏大

Linux 7.3-rc2 于 2026 年 9 月 6 日由 Linus Torvalds 发布，LWN 于 9 月 7 日跟进报道。rc2 通常是合并窗口结束后相对安静的候选版本，维护者会在此阶段开始发现并修复回归；但本次 rc2 明显偏“厚”，Linus 将其称为一个 “full fat” rc。增量并非来自单一异常子系统：文件系统、DRM、网络、BPF 以及多个驱动树都集中提交了修复；一笔错过合并窗口的 EDAC 拉取请求只占很小部分。除通常占主导地位的驱动外，工具代码约占补丁总量的 20%，主要来自 `sched_ext` 和内核自测试，其后依次是文件系统、核心内核和网络。

**原文：** [Linux 7.3-rc2 发布邮件（LWN 镜像）](https://lwn.net/Articles/1092756/) · [LWN 简讯](https://lwn.net/Articles/1092757/)

从风险判断看，补丁分布较广，但 Linus 尚未观察到异常模式或系统性问题；目前更像是多个子系统的修复恰好集中到 rc2，而不是某一基础机制失控。修复内容包括文件系统错误路径、DRM 显示与内存迁移、BPF 验证器和自测试、网络协议状态机、存储及 USB/平台驱动等，既包含功能回归，也包含 use-after-free、越界访问、竞态和资源泄漏修复。由于这些变化横跨核心代码、硬件驱动和工具链，后续候选版本的风险不能仅由补丁数量衡量，还要观察是否出现同一子系统连续回滚或成组修复。

**原文：** [Linux 7.3-rc2 完整补丁列表](https://lwn.net/Articles/1092756/) · [The rest of the 7.3 merge window](https://lwn.net/Articles/1089791/)

Linux 7.3 合并窗口共进入 15,267 个非合并提交，是内核历史上提交数量第二高的 `-rc1` 周期，仅次于包含近 3,000 个 bcachefs 历史提交的 6.7-rc1。如此大的合并基数扩大了跨架构、跨驱动和跨工作负载的回归暴露面；同时，7.3 中还合入了 `sched_ext` 子调度器、BPF 能力扩展、DAMON 监控改进、文件系统与块层变更，以及 Rust 内核支持等较大范围的基础设施更新，因此稳定化阶段的测试重点应覆盖新旧路径的交互，而不是只验证新增功能本身。

**原文：** [The rest of the 7.3 merge window](https://lwn.net/Articles/1089791/) · [Linux 7.3-rc2](https://lwn.net/Articles/1092756/)

**关注意义：** Linux 7.3 已进入稳定化阶段，内核与发行版团队应扩大跨架构启动、文件系统压力、图形栈、网络协议、BPF/sched_ext、自测试和平台驱动组合测试。厂商内核若准备回移 7.3 特性，应按子系统拆分变更并持续跟踪 rc3 及后续版本中的 `Fixes:`、回滚和稳定版候选补丁，尤其关注存储、内存管理、DRM、网络/BPF 与驱动相关回归。

**参考：** [LWN Kernel coverage](https://lwn.net/Kernel/) · [Linux 7.3-rc2](https://lwn.net/Articles/1092756/)

## 2. 内存分层与 CXL 页面放置：从冷热迁移走向层级感知

现代服务器可能同时拥有本地 DRAM、高带宽内存以及容量更大但延迟更高的 CXL 内存。不同介质在延迟、带宽、容量和访问拥塞方面存在差异，页面放置会直接影响工作负载的访存延迟、CPU 停顿和总体吞吐。Linux 现有内存分层主要通过 demotion 将较冷页面从快层迁移到慢层，通过 promotion 将位于慢层但仍被频繁访问的页面迁回快层；前者类似换出，判断相对直接，而后者需要在慢层识别热页，容易出现漏升温页或误提升页，导致性能收益不稳定。

**原文：** [Recent work in memory tiering](https://lwn.net/Articles/1092001/) · [Linux 内存管理文档](https://docs.kernel.org/mm/index.html)

Bharata B. Rao 提出的 `pghot` 机制试图整合多种热页来源：内核可以通过暂时标记页面不可访问并观察缺页，也可以利用 CXL 设备提供的访问追踪与报告信息，从而减少完全依赖 CPU 扫描的开销。该方案引入 `kmigrated` 内核线程，根据聚合后的活动度数据将最热页面提升到更快内存。近期版本还加入 AMD Instruction-Based Sampling 数据源和 precision mode：默认每个低层页面使用 1 字节跟踪信息，精确模式提高到 4 字节，并额外记录访问页面的 NUMA 节点，使页面不仅能被提升，还可以尽量提升到实际访问它的节点。

**原文：** [Recent work in memory tiering](https://lwn.net/Articles/1092001/) · [pghot 热页提升补丁讨论](https://lwn.net/ml/all/20260728054356.291998-1-bharata@amd.com)

该方向同时暴露出 Linux 现有抽象的边界。DAMON 已经能够监测内存访问模式，社区因此讨论是否应扩展 DAMON 来承担热页发现，而不是新增一套并行基础设施；支持者则认为 `pghot` 能够融合多个硬件和软件数据源，并在 NUMA 节点选择上提供专门能力。维护者尚未就两者的职责边界和使用场景达成共识，`pghot` 也仍远未达到可合并状态。这说明问题不只是“如何迁移冷热页面”，还包括内核如何表达层级性能、如何验证硬件提供的拓扑信息，以及如何避免多个监控与迁移机制重复扫描和相互竞争。

**原文：** [Recent work in memory tiering](https://lwn.net/Articles/1092001/) · [DAMON 文档](https://docs.kernel.org/mm/damon/index.html)

页面放置还涉及 cgroup 级别的资源公平性。当前 memory controller 可以限制一个 cgroup 使用的总内存量，却不能直接限制其在 DRAM、CXL 等不同层级中的占比。Joshua Hahn 的方案按系统各内存类型的容量比例为每个 cgroup 分配层级额度，例如系统由 25% DRAM 和 75% CXL 内存组成时，cgroup 的内存限制也按该比例划分；分配、定向回收、页面迁移和 promotion 都需要检查对应层级是否达到上限。Qiqi Liu 的另一套方案也设置每层额度，但允许管理员动态调整比例，主要依赖回收机制执行限制。两种方案都试图避免早启动工作负载耗尽快层、导致后续工作负载只能使用慢层，但在低限额语义、可配置性和回收复杂度上存在取舍。

**原文：** [Recent work in memory tiering](https://lwn.net/Articles/1092001/) · [Linux memory cgroup 文档](https://docs.kernel.org/admin-guide/cgroup-v2.html)

**关注意义：** 对数据库、内存计算和 AI/HPC 工作负载而言，CXL 提供容量扩展并不等于获得与本地 DRAM 等价的内存。评估内存分层方案时，应同时采集各 NUMA/CXL 节点的实测延迟与带宽、热页识别准确率、promotion/demotion 速率、页面扫描与迁移开销、cgroup 回收行为以及业务尾延迟，并验证固件提供的 NUMA 距离是否与实测性能一致。内核侧的关键任务是建立稳定、可解释、能表达多维硬件特征的层级模型，在通用迁移机制与 DAMON、硬件访问追踪、用户空间编排策略之间明确边界。

**参考：** [LWN Kernel coverage](https://lwn.net/Kernel/) · [Recent work in memory tiering](https://lwn.net/Articles/1092001/) · [CXL 内存设备文档](https://docs.kernel.org/driver-api/cxl/memory-devices.html)

## 本周总体判断

本周两个重点议题共同指向 Linux 内核在异构硬件和高并发系统中的稳定性边界。Linux 7.3-rc2 的修复量偏大，反映出大规模合并窗口对稳定化阶段测试和维护者响应能力的压力；内存分层与 CXL 页面放置则进一步表明，传统 NUMA 和冷热页启发式正在面对多维性能差异、硬件辅助追踪以及 cgroup 公平性的新要求。前者需要通过更完整的回归矩阵控制复杂度，后者需要在通用抽象、硬件特性和用户策略之间形成可验证的接口。

对内核工程人员而言，近期最值得跟踪的是 7.3 后续候选版本中 DRM、文件系统、网络/BPF、存储和内存管理修复的分布，以及 `pghot`、DAMON 和 tier-aware memcg 方案是否形成明确的合并路径。对发行版和硬件厂商而言，应避免仅依据 CXL 可见容量或 NUMA 距离配置评估性能，而要以真实工作负载测量页面迁移成本、层级争用和尾延迟，再决定是否启用自动 promotion/demotion 或采用用户空间编排。

**来源汇总：** [LWN 首页](https://lwn.net/) · [LWN Kernel coverage](https://lwn.net/Kernel/) · [Linux 7.3-rc2](https://lwn.net/Articles/1092756/) · [Recent work in memory tiering](https://lwn.net/Articles/1092001/)
