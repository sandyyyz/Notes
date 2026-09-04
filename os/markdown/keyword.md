# 待深入的主题

| 主题 | 当前关联笔记 | 后续阅读重点 |
| --- | --- | --- |
| CXL | [cxl.md](./cxl.md) | CXL.cache / CXL.mem 与 DMA、NUMA、内存池化的边界 |
| famfs | - | 面向 fabric-attached memory 的文件系统抽象 |
| HMM | [hmm.md](./hmm.md) | `mmu_notifier`、device private memory、迁移路径 |
| DAX | [IAA.md](./IAA.md) | 绕过 page cache 的直接持久内存/设备内存访问 |
| memcg | - | cgroup 内存记账、回收和 OOM 策略 |
| tiered-memory | - | DRAM、PMEM、CXL memory 之间的分层放置与迁移 |
| folio | - | 替代 page-centric API 的更大粒度内存管理抽象 |
| THP | - | 透明大页的分配、拆分、回收与性能权衡 |
| struct page → memory descriptor | [mm.md](./mm.md) | `struct page` 缩减、metadata 解耦和大内存系统开销 |
| MMIO | - | CPU 访问设备寄存器的内存映射 I/O 语义 |
| IOMMU | - | DMA 地址转换、隔离、PASID/ATS 与设备页表 |
