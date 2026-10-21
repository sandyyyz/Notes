# Swap 与内存回收（Memory Reclaim）技术总结

> **报告对象**：《Swap and Memory Reclaim — Squeezing Out More RAM》（KR2026）
> **作者**：Kairui Song（腾讯 · Tencent），kasong@tencent.com
> **主题**：Linux 内核 Swap 子系统的现代化改造，以及内存回收（Memory Reclaim / MGLRU）的最新演进
> **一句话概括**：通过重构 Swap 元数据结构 + 优化内存冷热评估算法，让"冷内存"被高效挤出，从而在更少物理内存下归档缓存更多数据。

---

## 一、为什么值得关注

这份 PPT 不是泛泛的技术科普，而是**内核内存管理方向的一手工程实践**。它回答了三个核心问题：

1. **Swap 为什么"又慢又乱"？** —— 历史包袱、多数据源耦合、锁竞争。
2. **怎么把它变干净？** —— 用"swap table"把 1+2+8 字节的零散元数据合并为单条 8 字节项，以 2MB cluster 为管理单元。
3. **怎么找到真正该回收的"冷页"？** —— 从经典 LRU 到 MGLRU，再到作者提出的 MGLRU-FG 频率增强方案。

对从事内核开发、云原生基础设施、数据库/大数据底层优化的工程师，这份内容直接关系**内存效率、吞吐与成本**。

---

## 二、Swap 基础概念梳理

### 2.1 Swap 是什么

Swap 允许**使用超过物理内存的容量**：把存储当 RAM 用，借用 CPU 无法直接寻址的资源（通过缺页中断）。如今日益普遍的是**内存压缩（memory compression）**，即用 CPU 周期换 RAM。它也是内存耗尽时（OOM 前）的最后防线。

### 2.2 Swap 的工作机制

- 用户态使用虚拟地址，CPU 走页表 → PTE 指向物理内存（Folio / 映射页）。
- 内核可以在用户态看到相同虚拟内存的前提下，灵活搬动物理内存。
- **换出（Swap Out）**：
  1. 内核选择"受害 Folio"（victim folio）。
  2. Swap 分配器在交换设备上分配一个 4K slot，用 swap entry（设备号 + 偏移）表示。
  3. 将该 Folio 从页表解除映射，把 swap entry 写入 PTE。
  4. 把内容写回 slot，释放物理 Folio。
- **换入（Swap In）**：
  1. 访问 swap entry 触发缺页中断。
  2. 内核分配新物理 Folio，读回内容，映射回页表，释放 swap slot。

### 2.3 现实的复杂性（为什么"没那么简单"）

- **多对一映射**：多个 PTE 可指向同一 Folio（CoW、KSM），swap slot 同理，需要引用计数。
- **Swap Cache**：用于避免冗余 I/O 与并发同步；换入/换出时 Folio 驻留在 cache 中实现快速恢复。
- **memcg 记账**：每个 slot 需要记录归属的内存 cgroup。
- **高并发高压**：Swap 是 MM 核心，性能敏感、竞争激烈。

**关键痛点（Slide 13）**：历史脏数据越积越多——
| 元数据 | 大小 | 说明 |
|---|---|---|
| swap_map（count） | 1 字节/槽 | 静态，仅 6 bit 可用 + 溢出/同步标志 |
| memcg id | 2 字节/槽 | 静态 |
| swap cache 指针/影子 | 8 字节 | xarray（还有 overflow page、zeromap 等）|

结果：分配只是"扫描静态 map"，扩展性差；多数据源同步导致锁差、性能劣化、bug 多；静态数据空闲内存占用高。

---

## 三、Swap 子系统现代化改造（作者的核心贡献）

改造原文见 LWN：https://lwn.net/Articles/1056405/

### 3.1 第一步：Cluster 分配器

- **旧方案**：围绕静态 swap map 构建，复杂、性能差；可选 2MB clustering，全局扫描、逻辑纠缠（PCP 随机化、SSD/HDD 区别）。
- **新方案**：**强制 2MB swap cluster**，所有 cluster 常驻链表；分配退化为"查链表头"。消除全局操作、重构锁以去除竞争。

### 3.2 第二步：合并元数据 —— 引入 Swap Table

核心洞察：**每个 slot 只可能处于三种状态之一**（Free / Used-uncached / Used-cached，外加 Bad），所以 **1 个 unsigned long（64 位）几乎足够表示一切**。

编码示意：
```
* Free:    |--------------- 0 ---------------|      (空闲)
* Shadow:  |SWAP_COUNT|Z|---- SHADOW_VAL ----|1|   (换出-未缓存)
* PFN:     |SWAP_COUNT|Z|------ PFN ---------|10|  (已缓存)
* Pointer: |----------- Pointer ------------|100|  (保留)
* Bad:     |------------- 1 ----------------|1000| (坏槽)
```

**为什么能塞进去**：
- 未缓存槽存"影子时间戳"，64 位中可腾出 6 bit 作计数。
- 缓存槽直接存 PFN（52 位），上方位足够放计数。
- 既然 cluster 已成管理单位，每个 cluster 只用**一个 unsigned long 数组**同时承担计数与缓存。

**收益**：
- 仅在使用中的 cluster 才分配表，空闲 cluster 可释放，**内存占用更低**，表精确 4K（8×512）。
- 1 字节 swap_map + 8 字节 swap cache **合并为一条 8 字节 swap table entry**。
- 性能更好、数据源更紧凑、**不再有同步负担与 hacks**。
- memcg 数组拆分为 per-cluster 表，**空闲内存占用趋近于零**。

> **结果**：swap-in 现在完全运行在单一、基于 cluster 的数据源上，消除了历史 workaround，维护开销更低、内存更省、性能更高，内核内部 API 也更干净。

### 3.3 观点：Swap 越来越"有助性能"

- Swap 曾因"慢"而口碑差，但**存储变快、Swap/压缩变快**，情况已改变。
- 内存压缩用 CPU 换 RAM；机器上常有大量**一次性使用的冷匿名内存**。
- **开启 Swap 能让内核缓存更多热数据** —— 能更高效地跑 git log / grep 等 IO 密集任务。

### 3.4 Swap 未来方向

- 更好的 Readahead、更好的 THP 换入/换出
- 在缺页发生前避免缺页
- Tiering（分层）、Resizing、Balancing、Migration、IO 批处理
- 更好的非物理 Swap
- **找到正确的 Folio 去换出**（衔接下一章）

---

## 四、内存回收（Memory Reclaim）与冷热评估

### 4.1 内存回收全景

内存回收比 Swap 更宽泛。用户态内存大致两类：
- **Anon Folio** → Swap 支撑 → 换出
- **File Folio** → Page Cache → 干净则直接丢弃（drop）
- Shmem 及其他

**核心思想："空闲内存是浪费，页缓存留到内存压力到来"**。目标是在压力下找出 RAM 里的"冷部分"来驱逐。

### 4.2 冷热度（Hotness）信息从哪来

- **Mapped（anon/file）**：PTE Access Bit（CPU 访问时置位）
- **Unmapped（file）**：`folio_mark_accessed()`（内核主动调用）
- **时间局部性**（LRU）：最近分配的 Folio 更可能被再用
- **Refault**：被驱逐的 Folio 在原始映射处留下"时间戳"
- 其他：madv、fadv 提示

### 4.3 评估热度的难点

- **PTE Access 是"粘性的"**：布尔位、多次访问难区分；收集成本高（RMAP 反向遍历逐个 PTE，还须修改页表重置）。
- **folio_mark_accessed()** 位于极热路径，必须足够快。
- **LRU 的冷缓存污染（Cold Cache Pollution）**：一次性的冷缓存爆发会把热缓存挤出去。
- **LFU 的陈旧缓存污染（Stale Cache Pollution）**：历史热页滞留过久，工作集无法更新，且扫描排序成本高。

### 4.4 经典方案：CLRU（Active/Inactive 双链表 LRU）

- 经内核数十载打磨的"经典 LRU"。
- 活跃 + 非活跃两条链表区分工作集；一次性 Folio 留在 inactive。
- 需要**两次访问**才提升到 active。
- **缺点**：升降级都需 LRU 锁、两次 RMAP 遍历、只有两级热度、folio_mark_accessed() 与锁的高频开销。

### 4.5 MGLRU（Multi-Gen LRU）—— 框架级方案

**核心设计**：4 个 Gen + 4 个 Tier；Folio flags 中 3(gen)+2(tier) bit；配合**页表遍历器、惰性提升、Rmap Lookaround、Bloom filter、PID feedback**。它是一个可定制策略的**框架**。

**Aging（老化）机制**：
1. 直接遍历页表，批量收集并重置访问位；"惰性提升"（仅标志位、无锁）把访问的 Folio 提升到最新 Gen。
2. 压力下启动 aging，生成新 Gen（嵌入时间戳）。
3. 驱逐只发生在**最老 Gen 的尾部**；被惰性提升的 Folio 看到属于更新 Gen 就"只搬不移"。
4. Gen 耗尽即"丢弃"——零成本，无链表搬移；用**滑动窗口**持续滚动。
5. **应对庞大地址空间**：aging 也是惰性的，可延迟到只剩 2 Gen；用 **Bloom filter** 识别热区，只遍历热区，热点漂移时更新/丢弃对应 bit。
6. RMAP 仍作补充：更新 Bloom filter、对相邻 PTE 做 lookaround（PMD 内空间局部性批量提升）。

**Tiering（分层 / PID 保护）**：
- 用于保护 `folio_mark_accessed()`（无映射文件的访问）。
- 内核感知 refault（被驱逐后返回的 Folio，经 shadow 识别）。
- 某 tier refault 率高（refault/eviction）→ 驱逐时保护，提升 1 Gen；refault 率在 aging 时软重置。

**MGLRU 的已知问题（Slide 49）**：
- Unmapped file cache 极常见，PID 保护是它们唯一的提升途径，但只 +1 Gen 而 mapped 直接提到最新 Gen → **文件页被过度回收**，破坏 LRU 规则，造成陈旧缓存污染。
- 访问 ≥8 次的 Folio 无法再区分。
- 对 anon/mapped Folio 适配不佳，页表遍历器没有很好利用 tier。

### 4.6 MGLRU-FG（作者的频率增强扩展）

**思路**：把惰性主动提升也应用到 `folio_mark_accessed()`/tier，让 tiering 成为**统一的热度基线**，并与频率结合。
- **冷缓存污染**：冷缓存停留在低 Gen，永不污染新 Gen。
- **热缓存污染**：aging 以零成本降级所有 Folio；驱逐纯按 LRU 顺序，新提升/新分配的 Folio 总是最后被回收。
- 初步测试效果很好，RFC 已发布。

### 4.7 内存回收的其他部分与议题

| 议题 | 说明 |
|---|---|
| **Swappiness** | Anon 与 File 分属两条 LRU；CLRU 按 swappiness 平衡回收，MGLRU 对两类同步 Gen、回收 refault 率最低的最老 Gen。swappiness 改进进行中。|
| **避免 Thrashing** | 及时唤醒 OOM Killer；MGLRU 用时间戳做 TTL。|
| **Refault Distance** | 用 shadow 里的"时间戳"补充热度（被驱逐出内存多久/多远）；MGLRU 改用 Gen 编号估计，但 Refault Distance 也可用于 MGLRU（RFC 已发布）。|
| **Throttling / Cgroup Balancing** | 限流与 cgroup 均衡。|

---

## 五、技术演进趋势与我的思考

### 5.1 趋势一：从"向外借内存"到"向上挤内存"

Swap 的本质正从"救命的二次存储器"演变为"**主动的压缩冷存储层**"。叠加内存压缩，趋势是：
- 冷匿名页被压缩后驻留内存，而非写回磁盘 → **速度与容量兼得**。
- 开启 Swap + 良好回收策略，对 IO 密集应用（git log / grep / 大数据）是**性能净增益**，而非传统的谈之色变。

### 5.2 趋势二：元数据从"多处零散"走向"单源紧凑"

作者用 Swap Table 把 1+2+8 字节的碎片化元数据合并为单条 64 位项，以 2MB cluster 为管理单元，做到"只在用的时候才占用、空闲趋零"。这是一条可复用的工程范式：
> **合并麻雀式数据结构 → 以较大管理单元摊销固定开销 → 按需分配释放**。

内核内存管理的许多子系统（如内存压测、热页追踪）都在沿这一方向收敛。

### 5.3 趋势三：冷热评估从"两级粗粒度"走向"多代多级 + 频率"

- CLRU 只有 Active/Inactive 两级，MGLRU 引入 4 Gen + 4 Tier，再到 **MGLRU-FG 叠加频率（frequency）**。
- 语义上就是从"是否热"走向"多热、热了多久、被访问多少次"。
- 关键创新点：**惰性提升（lazy promotion）、页表直扫（避免 RMAP）、Bloom filter 定位热区、refault 反馈闭环** —— 用"少扫描、多推测、反馈校正"换取性能。

### 5.4 趋势四：个性化策略 vs 通用默认的平衡

- MGLRU 是"框架"，允许自定义策略，但**不可能为每个应用单独打磨策略**。
- 因此作者强调**改进默认实现**（`/sys/kernel/debug/lru_gen_full` 可观测调参），这也是内核演进的主流哲学：默认稳健 + 可调优 + 可观测。

### 5.5 我的几点判断

1. **"空闲内存是浪费，冷内存也是浪费"** 是全文的价值观内核。未来云原生/容器密度提升，很大程度上要靠更聪明的内存回收而非单纯加内存。
2. Swap 的"污名"正在被性能数据扭转，但**正确的驱逐策略**（MGLRU-FG 这类频率感知）仍是决定收益的关键变量 —— 选错 victim 反而拖累。
3. 元数据紧凑化（swap table）带来的不只是内存节省，更是**锁竞争与同步复杂度的下降**，这在多核高并发下是隐性但巨大的吞吐红利。
4. 内存回收正从"LRU 经验主义"走向"可反馈、可观测、可学习的自适应系统"（refault/PID 反馈 + Bloom filter + 时间戳）。未来可能与内核外（DAMON 等主动式）能力进一步融合。

---

## 六、金句摘录

> "All problems in computer science can be solved by another level of indirection, except for the problem of too many layers of indirection."
> —— 讽刺旧 Swap-in 栈层层包裹的 workaround

> "Free memory is wasted memory. Cold memory is wasted memory."
> —— 全文要义：榨出更多可用 RAM

> "Archive more using less memory!"
> —— Swap + 内存回收的最终价值主张

---

## 七、延伸阅读

- LWN 文章：Modernizing the Swap Subsystem — https://lwn.net/Articles/1056405/
- Linux 内核 MGLRU（`mm/vmscan.c`、`lru_gen_*`）实现文档
- `/sys/kernel/debug/lru_gen_full` 可观测接口

