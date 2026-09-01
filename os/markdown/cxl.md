# CXL

CXL 将跨设备访问提升为硬件缓存一致的内存语义，使 CPU 和设备能够按 Cache Line 共享数据，减少显式复制、双份 Buffer 和软件同步，同时保留 DMA 作为大块数据搬运路径。

| | `CXL.io` | `CXL.cache` | `CXL.mem` |
| --- | --- | --- | --- |
| 作用 | 设备发现、配置、MMIO、DMA、中断 | 设备一致地访问并缓存 Host Memory | Host 以内存语义访问 Device Memory |
| 方向 | — | Device → Host Memory | Host → Device Memory |
| 内存位置 | — | Home: Host | Device |
| 设备角色 | — | Caching Agent | — |
| 一致性 | 不提供 CXL Cache Coherence | 硬件缓存一致 | 硬件缓存一致 |
| 基础 | PCIe I/O 语义 | — | — |
| 适用 | 所有 CXL 设备都需要 | Type-1、Type-2 | Type-2、Type-3 |
