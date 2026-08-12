# CXL

CXL 将跨设备访问提升为硬件缓存一致的内存语义，使 CPU 和设备能够按 Cache Line 共享数据，减少显式复制、双份 Buffer 和软件同步，同时保留 DMA 作为大块数据搬运路径。

1. `CXL.io`
    作用：设备发现、配置、MMIO、DMA、中断
    基础：PCIe I/O 语义
    一致性：不提供 CXL Cache Coherence
    所有 CXL 设备都需要

2. `CXL.cache`
    作用：设备一致地访问并缓存 Host Memory
    方向：Device → Host Memory
    Home：Host
    设备角色：Caching Agent
    适用：Type-1、Type-2

3. `CXL.mem`
    作用：Host 以内存语义访问 Device Memory
    方向：Host → Device Memory
    内存位置：Device
    适用：Type-2、Type-3

