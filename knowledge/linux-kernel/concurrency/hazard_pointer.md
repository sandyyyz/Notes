# Hazard Pointer

与 RCU 类似，hazard pointer 用于在对象可能被释放时持有其短期引用。RCU 保护的代码必须禁用抢占，而 hazard pointer 的设计则允许抢占，尽管这种用法未必最优。

## Linux 内核 Hazard Pointer 提案概述

> 本文总结 LWN.net 文章《Hazard pointers for the kernel》所讨论的 Linux 内核 Hazard Pointer 提案。该方案旨在补充 RCU、SRCU 和引用计数等现有对象生命周期管理机制。目前相关补丁仍处于 RFC 阶段，并非稳定内核接口。

## 1. 要解决的问题

无锁数据结构的读者通常先读取一个共享指针，再访问它所指向的对象：

```c
obj = shared_ptr;
use(obj);
```

问题在于，更新者可能在这两步之间将对象从数据结构中删除并释放。读者随后继续访问 `obj` 时，就会产生 use-after-free。

传统引用计数要求读者增加对象引用，但“读取对象指针”和“增加引用计数”本身并非一个不可分割的操作：

```text
读者读取 obj
    ↓
更新者删除并释放 obj
    ↓
读者尝试增加 obj 的引用计数
```

此时引用计数已经位于被释放的内存中。因此，仅调用 `refcount_inc()` 并不能自动解决无锁查找与对象销毁之间的竞态。

RCU 可以解决这一问题。更新者先从共享数据结构中移除对象，再等待一个 grace period，确认旧读者全部离开临界区后才释放对象。RCU 的读侧开销很低，但对象回收可能被较长的宽限期延迟；当大量待回收对象积压时，还可能造成较高的内存占用。

## 2. Hazard Pointer 的基本思想

Hazard Pointer 让每个读者公开声明：

> 我当前正在使用这个对象，在该声明撤销之前不要释放它。

读者的大致操作流程如下：

```text
读取共享指针 P
    ↓
将 P 发布到自己的 hazard slot
    ↓
重新读取共享指针
    ↓
如果共享指针已改变，则重试
    ↓
安全访问 P
    ↓
清除 hazard slot
```

发布 hazard pointer 后必须重新读取共享指针，因为对象可能在“第一次读取”和“发布 hazard pointer”之间被更新者移除。只有在发布后重新检查共享指针仍然指向同一对象，读者才能确认该对象在保护建立之前没有失效。

更新者的大致流程如下：

```text
从共享数据结构中移除对象 P
    ↓
扫描所有 hazard slot
    ↓
如果仍有 slot 指向 P，则暂缓释放
    ↓
如果没有 slot 指向 P，则释放对象
```

因此，Hazard Pointer 将“谁仍可能访问对象”从 RCU 的隐式临界区，转换为可枚举的显式指针集合。

## 3. Hazard Pointer 与 RCU 的核心差异

两者都允许读者在更新并发发生时继续访问旧对象，但判断对象是否可以释放的方法不同：

```text
RCU：
等待所有旧读者经过 quiescent state，
然后认为旧对象不再被访问。

Hazard Pointer：
检查所有读者公开的 hazard slot，
确认没有 slot 指向待回收对象。
```

RCU 的回收时间取决于 grace period。某个迟迟不经过静止状态的 CPU、任务或虚拟 CPU，可能延迟一批对象的回收。Hazard Pointer 只保护读者明确发布的对象，因此可以更有针对性地判断某个对象是否能够释放。

Hazard Pointer 也并非没有代价：

- 读者必须发布 hazard slot；
- 读者必须执行必要的内存顺序操作；
- 发布后需要重新验证共享指针；
- 更新者或回收者必须扫描 slot；
- 内核还必须管理抢占、迁移和不同执行上下文中的 slot 生命周期。

因此，对于持续时间短、数量巨大且不允许阻塞的读侧临界区，普通 RCU 通常仍然更合适。

## 4. 为什么内核实现比较复杂

用户空间的 Hazard Pointer 通常将 slot 绑定到线程，但 Linux 内核中的执行上下文更加复杂：

- 任务可能被抢占并迁移到其他 CPU；
- 读者可能睡眠或长期阻塞；
- 获取与释放可能发生在不同执行上下文；
- 中断处理程序也可能使用 hazard pointer；
- hazard context 可能分配在栈上；
- CPU 热插拔和任务退出不能留下失效 slot；
- 模块卸载前必须确认相关异步回收已经完成。

当前 RFC 方案为每个 CPU 提供预分配 slot，并在这些 slot 不足时退回到备用 slot。为了处理抢占和任务迁移，当任务发生上下文切换时，仍在使用的 per-CPU hazard pointer 需要迁移到与具体 context 关联的备用位置，以避免被抢占任务长期占用或错误引用某个 CPU 的 slot。

RFC v2 还增加了 `hazptr_detach()`，允许 hazard pointer 的 acquire 和 release 发生在不同执行上下文。例如，一个任务建立保护后，可以将释放工作交给另一个任务或 IPI handler。在 detach 过程中，保护状态从 per-CPU slot 转移到 context 的备用 slot，并依靠 acquire/release 内存顺序保证回收扫描不会在迁移窗口中遗漏该指针。

## 5. 当前补丁系列的主要内容

截至 2026 年 7 月 15 日，Paul McKenney 发布的 RFC v2 包含 24 个补丁，主要涉及：

- Hazard Pointer 基础实现；
- `refscale` 性能测试；
- 独立的 `hazptrtorture` 压力测试；
- 栈上 `hazptr_ctx` 测试；
- 读者睡眠、CPU 超额配置和上下文迁移测试；
- 中断上下文中的 acquire 和 release；
- 延迟释放和跨 CPU 释放；
- `hazptr_detach()`；
- `CONFIG_HAZPTR_DEBUG` 误用检测；
- ownership 问题修复；
- 内核文档和测试参数。

该系列中相当一部分内容用于 torture testing，而不是核心 API 本身。这表明当前评审重点已经从“接口能否工作”转向以下正确性问题：

- 抢占后保护是否仍然有效；
- 任务迁移时 slot 是否安全；
- 中断上下文能否正确建立和解除保护；
- acquire 与 release 跨上下文时所有权是否明确；
- 错误使用能否被调试配置检测；
- 极端并发下是否可能提前释放对象。

## 6. 可能适合的场景

Hazard Pointer 更适合同时具有以下特征的场景：

1. 读路径需要良好的多核可扩展性；
2. 不能为每次访问都争用共享引用计数缓存行；
3. 读者保护时间可能没有明确上限；
4. 读者可能睡眠或跨越调度；
5. 对象需要比 RCU grace period 更及时地回收；
6. 每个读者同时保护的对象数量较少。

早期 RFC 将 Hazard Pointer 概括为一种具有 RCU 式 API 的可扩展引用保护机制，并给出了较好的读侧微基准结果。但这些结果依赖具体硬件、配置和负载，不能直接推导出 Hazard Pointer 在所有实际场景中都优于 RCU。

## 7. 与现有机制的定位对比

```text
refcount：
适合表达显式所有权，但共享计数器可能产生缓存行争用；
无锁获取引用还可能遇到对象已先被释放的问题。

RCU：
读侧开销很低，但对象回收必须等待 grace period；
读者必须遵守相应的临界区规则。

SRCU：
允许更灵活的读侧行为，但仍以宽限期为核心。

Hazard Pointer：
读者显式公布正在访问的对象；
回收者可以针对具体对象判断其是否可释放；
代价是读侧发布、slot 扫描和执行上下文管理更加复杂。
```

Hazard Pointer 的目标不是成为“更快的 RCU”，而是补齐引用计数、RCU 和 SRCU 之间的适用空白。它更可能作为一种有针对性的补充机制，而不是内核中通用的默认对象回收方案。

## 8. 当前状态与阅读时的注意事项

相关补丁仍标记为 RFC，说明接口、实现和正确性模型仍处于讨论与验证阶段。当前方案涉及调度器、per-CPU 状态、内存顺序、跨上下文所有权和测试基础设施，而且补丁系列仍在修复 ownership 等问题。

因此，阅读该文章和补丁时应区分：

- Hazard Pointer 的一般算法原理；
- 当前 RFC 提出的 Linux 内核实现；
- 邮件讨论中的备选方案；
- 已经通过测试的行为；
- 尚未进入主线的实验性接口。

不能将 RFC 中的 API 或实现细节直接视为当前稳定内核的既定行为。

## 总结

RCU 通过等待旧读者全部结束来保证对象安全回收，而 Hazard Pointer 让读者显式公布自己正在使用的对象，使回收者能够更精确、更及时地判断某个对象是否可以释放。

这种机制可能适合读者可阻塞、保护时长无明确上限且对象需要及时回收的场景，但它将复杂度转移到了 slot 管理、内存顺序、任务迁移、跨上下文释放和回收扫描上。当前 Linux 内核实现仍处于 RFC 阶段，开发者正在重点验证抢占、中断、迁移、ownership 和 torture testing 等正确性问题。

## 参考资料

- LWN.net, *Hazard pointers for the kernel*: <https://lwn.net/Articles/1084015/>
- RFC v2, *Simple hazard-pointer implementation and torture tests*: <https://lwn.net/Articles/1083227/>
- 早期 RFC, *Add hazard pointers to kernel*: <https://lkml.org/lkml/2024/9/17/602>
