# CXL

CXL（Compute Express Link）将跨设备访问提升为硬件缓存一致的内存语义，使 CPU 和设备能够按 cache line 共享数据，减少显式复制、双份 buffer 和软件同步；DMA 仍然适合批量、显式的数据搬运。

## 协议分层

| | `CXL.io` | `CXL.cache` | `CXL.mem` |
| --- | --- | --- | --- |
| 作用 | 设备发现、配置、MMIO、DMA、中断 | 设备一致地访问并缓存 Host Memory | Host 以内存语义访问 Device Memory |
| 方向 | — | Device → Host Memory | Host → Device Memory |
| 内存位置 | — | Home: Host | Device |
| 设备角色 | — | Caching Agent | — |
| 一致性 | 不提供 CXL Cache Coherence | 硬件缓存一致 | 硬件缓存一致 |
| 基础 | PCIe I/O 语义 | — | — |
| 适用 | 所有 CXL 设备都需要 | Type-1、Type-2 | Type-2、Type-3 |

## 与 DMA 的区别

| 机制 | 数据访问方式 | 一致性语义 | 典型用途 |
| --- | --- | --- | --- |
| DMA | 软件提交描述符，设备批量读写内存 | 需要驱动和 IOMMU/cache maintenance 配合 | 大块 I/O、网卡、存储、传统加速器 |
| `CXL.cache` | 设备以一致性 agent 身份按需访问 Host Memory | 由 CXL/CPU coherency fabric 维护 | Type-1/Type-2 设备直接读取主机数据结构 |
| `CXL.mem` | Host 以 load/store 访问 Device Memory | Host cache 与设备内存之间保持一致 | Type-3 内存扩展、内存池化 |

一句话概括：DMA 更像“显式搬运数据”，CXL 更像“把远端设备内存或主机内存纳入一致性访问模型”。
