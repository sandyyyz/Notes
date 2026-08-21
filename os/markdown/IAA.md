# DAX

`A major advancement in SPR is the introduction of Data Accelerator Complex (DAC) [29]. As illustrated in the left part of Fig. 1, a DAC tile integrates four built-in accelerators—QAT, DLB, DSA, and IAA—along with cache-coherent interconnect, and is dedicated to each SPR SoC chiplet.`  

## QPL

`The Intel® Query Processing Library (Intel® QPL) is an open-source library to provide high-performance query processing operations on Intel CPUs. Intel® QPL is aimed to support capabilities of the new Intel® In-Memory Analytics Accelerator (Intel® IAA) available on Next Generation Intel® Xeon® Scalable processors, codenamed Sapphire Rapids processor, such as very high throughput compression and decompression combined with primitive analytic functions, as well as to provide highly-optimized SW fallback on other Intel CPUs. Intel QPL primarily targets applications such as big-data and in-memory analytic databases.`

## IAA

IAA 指`Intel In-Memory Analytics Accelerator`，是一种集成在部分 Intel Xeon 处理器中的片上硬件加速器，用于把压缩、解压缩、扫描、过滤、CRC 等数据密集型操作从通用 CPU 核心卸载出去.
[IAA](https://ieeexplore.ieee.org/document/11096374)

`As IAA is integrated with CPUs as an on-chip accelerator, it can directly access the CPU’s cache and memory in a cache-coherent manner, offering low latency and power consumption with reduced programming complexity compared to off-chip accelerators.`

## Hardware Architecture

![IAA_arch](https://raw.githubusercontent.com/sandyyyz/Image-hosting/main/img/IAA.png)

Single IAA instance consists:  
1. Eight Work queues(WQs), including shared WQ(SWQ),accessible by multiple cients, and Dedicated WQ(DWQ), assigned to a single cient.
2. Eight Engines(ENGs)
3. Analytics/(De)Compression pipe arbiters.
4. Pipes
5. Address Translation Cache.
6. DMA engine.

### workflow
`
The ENGs fetch descriptors from the WQs, with arbiters ensuring Quality of Service (QoS) and fairness. The ENG forwards the job descriptor to the appropriate processing pipe, as determined by the arbiter, and manages the DMA transfer of data between system memory and either the analytics or compression pipe. The fundamental operational unit in IAA is a group, which can include any combination of WQs and ENGs, up to the maximum capacity supported by the IAA.`

## Software Architecture
`
Like DSA, IAA uses the Intel Data Accelerator Driver (IDXD), a Linux kernel module responsible for detecting and initializing IAA devices. IDXD manages essential control operations and exposes them to user-space applications via the libaccel-config API library, simplifying configuration tasks such as setting up groups.`  

`
When creating job descriptors, QPL provides three execution paths: (1) the hardware path, which executes jobs on IAA; (2) the software path, which runs them on a CPU core; and (3) the auto path, which attempts to use IAA but falls back to the CPU in case of failure (e.g., unsupported operations or IAA initialization fails).`

## Supporting Operations

![IAA-supporting-Operations](https://raw.githubusercontent.com/sandyyyz/Image-hosting/main/img/IAA-support-operations.png)
