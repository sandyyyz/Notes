# UEFI 固件架构与技术综述

## 1. UEFI 概述

UEFI（Unified Extensible Firmware Interface）是现代计算机系统固件的标准架构，取代了传统 BIOS。它定义了从硬件复位到操作系统接管之间，固件所必须提供的接口规范与执行框架。UEFI 核心作用包括：

- **硬件初始化**：完成 CPU、内存、总线及外设的早期初始化，构建操作系统可依赖的运行时环境。
- **设备驱动模型**：通过 Handle / Protocol 抽象和 Driver Binding 机制，实现硬件驱动的模块化加载与动态连接。
- **启动管理**：基于 NVRAM 中的启动变量（BootOrder / Boot####），按策略选择并加载操作系统引导程序。
- **安全体系**：提供 Secure Boot 镜像认证机制，确保固件及 OS Loader 的完整性与可信度。
- **运行时服务**：操作系统接管后，仍提供变量读写、时钟、重置等 Runtime Services。

UEFI 规范由 UEFI Forum 维护，平台初始化（Platform Initialization, PI）架构定义了固件内部各阶段的标准化接口。

---

## 2. UEFI 启动阶段总览

UEFI 固件启动流程按执行顺序划分为六个阶段，各阶段职责明确、服务递进：

```
CPU Reset → SEC → PEI → DXE → BDS → TSL → RT → OS
```

| 阶段 | 全称 | 核心职责 |
|------|------|----------|
| SEC | Security | 安全验证、临时 RAM、PEI Foundation 引导 |
| PEI | Pre-EFI Initialization | 早期初始化（DRAM / CPU）、HOB 列表构建 |
| DXE | Driver Execution Environment | 驱动执行、总线枚举、Boot Services 构建 |
| BDS | Boot Device Selection | 控制台初始化、设备连接、启动策略执行 |
| TSL | OS Load | OS Loader 运行、ExitBootServices |
| RT | Runtime | 操作系统接管后，Runtime Services 持续服务 |

---

## 3. 各阶段详细说明

### 3.1 SEC 阶段（Security Phase）

SEC 是 CPU 复位后的首个执行阶段，负责建立最基础的执行环境。

**核心职责**：

- 处理所有平台重启事件（冷启动、暖启动、Sx 状态恢复等）。
- 创建临时内存存储（Cache-as-RAM），在 DRAM 不可用时提供代码和数据存放空间。
- 作为系统信任根（Root of Trust），验证固件完整性。
- 建立 CPU 基本执行模式，切换到 32 位兼容模式或 64 长模式。
- 通过 `EFI_SEC_PEI_HAND_OFF` 结构将控制权和 Hand-Off 信息传递给 PEI Foundation。

SEC 阶段通常以汇编语言编写，环境极为受限，不具备 C 语言运行时支持。

### 3.2 PEI 阶段（Pre-EFI Initialization Phase）

PEI 阶段在临时内存或永久内存中运行，完成从最小化环境到完整内存环境的过渡。

**核心职责**：

- 初始化北桥、内存控制器（MRC），完成 DRAM 发现与训练，安装永久内存。
- 初始化 CPU 基本功能（APIC、缓存策略、微码加载）。
- 通过 PEI Foundation 调度 PEIM（Pre-EFI Initialization Module），利用 PPI（PEIM-to-PEIM Interface）实现模块间通信。
- 构建 HOB（Hand-Off Block）列表，记录 PEI 阶段的初始化结果和资源信息。

**关键机制**：

- **PEI Dispatcher**：根据 PEIM 的依赖表达式（Depex）进行拓扑排序调度，确保模块按依赖关系正确执行。
- **HOB 列表**：PEI 与 DXE 之间的数据传递机制。包括 PHIT HOB（必须是第一个）、资源描述 HOB、内存分配 HOB、固件卷 HOB、CPU HOB 等类型。
- **临时内存切换**：PEI 前期在临时 RAM 运行，DRAM 就绪后调用 `InstallPeiMemory()` 切换到永久内存，临时 RAM 被清除。

PEI 阶段不依赖 UEFI 服务协议，使用 PEI Services 表（PPI Services、HOB Services、Firmware Volume Services 等）。

### 3.3 DXE 阶段（Driver Execution Environment Phase）

DXE 是 UEFI 固件最核心的阶段，建立了完整的 UEFI 运行环境。

**核心职责**：

- DXE Foundation 解析 PEI 传递的 HOB 列表，构建 EFI 系统表（gST）、Boot Services（gBS）、Runtime Services（gRT）及 DXE Services 表。
- DXE Dispatcher 从固件卷（FV）中扫描、解析 DXE 驱动，根据 Depex 依赖表达式执行拓扑排序调度。
- 枚举 PCIe 总线、发现所有总线设备，分配 Bus Number 和 BAR 资源。
- 加载各类设备驱动（NVMe、USB、SATA、Network 等），初始化外设子系统。
- 生成 ACPI 表和 SMBIOS 表，为操作系统提供硬件描述信息。
- 当 Dispatcher 无更多驱动可调度时，通过 `EFI_BDS_ARCH_PROTOCOL` 将控制权移交 BDS。

**驱动调度机制**：

- **Apriori 文件**：指定必须最先执行的关键驱动（如芯片组驱动），赋予最高调度优先级。
- **Depex 依赖表达式**：驱动内置的 Protocol 依赖声明，使用 AND / OR / NOT 等逻辑运算符组合 Protocol GUID。只有前置依赖满足时，驱动方可执行。
- **Protocol Database**：全局协议注册表，驱动安装的新 Protocol 触发对候选池的新一轮依赖检查。
- **调度流程**：扫描 FV → 解析 Depex → 处理 Apriori → 执行已就绪队列 → 重评估候选池 → 循环直至无新驱动可调度。

### 3.4 BDS 阶段（Boot Device Selection Phase）

BDS 阶段基于 DXE 准备好的服务和驱动，完成启动设备选择并加载操作系统引导程序。

**核心职责**：

- **控制台初始化**：连接 ConIn（键盘）、ConOut（屏幕）、StdErr 设备驱动，更新系统表中的控制台指针。通过 GOP（Graphics Output Protocol）渲染 OEM 启动 Logo。
- **设备连接**：对未连接的 Controller / Device Handle 执行 `ConnectController()`，递归匹配 Driver Binding 的 Supported / Start 流程，加载 Option ROM。
- **启动策略执行**：通过 `PlatformBootManagerLib` 读取 NVRAM 中启动变量，按 BootOrder 排序选择启动项。
- **OS Loader 加载**：通过 Device Path 定位 EFI 文件，调用 `LoadImage()` 加载到内存，再调用 `StartImage()` 执行。
- **系统资产信息收集**：在服务器平台上，收集 BIOS / CPU / DIMM / PCIe 信息并推送给 BMC。

**启动变量体系**：

| 变量 | 类型 | 说明 |
|------|------|------|
| BootOrder | 持久 | 启动优先级数组，每次启动按序尝试 |
| Boot#### | 持久 | 单个启动项，含 EFI_LOAD_OPTION 结构（Attributes、Description、Device Path、OptionalData） |
| BootNext | 一次性 | 优先于 BootOrder，仅对本次启动有效，处理后自动清除 |
| BootCurrent | 只读 | 记录本次实际使用的启动项编号，由固件写入 |

**设备连接链路（以 NVMe 为例）**：

```
PCI 枚举发现 NVMe Controller
  → PciIo Protocol（PCI 层访问）
  → NvmExpressDxe.Start() → BlockIo Protocol（块读写）
  → PartitionDxe.Start() → BlockIo + DevicePath（分区级）
  → FatDxe.Start() → SimpleFileSystem（文件系统）
  → bootmgfw.efi 可打开
```

**DXE 到 BDS 的移交**：BDS 以 DXE Driver 形式安装 `EFI_BDS_ARCH_PROTOCOL`，DXE Core 通过此协议找到 BDS 并调用 `BdsEntry()`。BDS 接管后不应返回，否则 DXE Core 进入死循环。

### 3.5 TSL 阶段（OS Loader Phase）

OS Loader（如 Windows 的 `bootmgfw.efi`、Linux 的 `grubx64.efi`）由 BDS 加载并执行，负责准备操作系统运行环境。

**核心职责**：

- 调用 `GetMemoryMap()` 获取当前内存布局快照及 MapKey。
- 加载操作系统内核及必需的驱动程序。
- 调用 `ExitBootServices(MapKey)` 完成固件与操作系统的最终交接。

**ExitBootServices 的影响**：

- Boot Services 不可用（包括 LoadImage、ConnectController 等）。
- Runtime Services 仍可用（GetVariable / SetVariable、时钟、ResetSystem、SetVirtualAddressMap）。
- 触发 `EVT_SIGNAL_EXIT_BOOT_SERVICES` 事件。
- OS Loader 为调用者，BDS 的责任止于成功启动 OS Loader。

### 3.6 RT 阶段（Runtime Phase）

操作系统完全接管控制权后，固件进入 Runtime 阶段。

**保留服务**：

- `GetVariable()` / `SetVariable()` — 读写 NVRAM 变量。
- `GetTime()` / `SetTime()` — 硬件时钟操作。
- `ResetSystem()` — 系统重启 / 关机。
- `SetVirtualAddressMap()` — 虚拟地址映射（PAE 到虚拟地址转换）。
- `GetWakeupTime()` / `SetWakeupTime()` — 唤醒时间管理。

Runtime Services 需要在操作系统进入虚拟内存模式后，通过 `SetVirtualAddressMap()` 更新内部地址映射，确保跨模式调用正确。

---

## 4. 核心架构概念

### 4.1 Handle / Protocol 模型

UEFI 的核心抽象机制。Handle 是对象的标识，Protocol 是对象能力的描述。一个 Handle 上安装哪些 Protocol，表达该对象具备哪些能力。Protocol 通过 GUID 唯一标识，驱动间通过 LocateProtocol / InstallProtocolInterface 进行通信。

### 4.2 Driver Binding 机制

`EFI_DRIVER_BINDING_PROTOCOL` 定义了设备与驱动的匹配流程：
- **Supported()**：测试驱动是否支持指定控制器。
- **Start()**：初始化控制器，安装新的 Protocol。
- **Stop()**：停止管理控制器，卸载 Protocol。

`ConnectController()` 遍历所有已注册的 Driver Binding，触发 Supported → Start 匹配流程，形成级联连接。

### 4.3 Secure Boot

安全启动机制集成在 `LoadImage()` 流程中。启用时，固件根据以下密钥数据库验证镜像签名：
- **PK**（Platform Key）：平台根密钥。
- **KEK**（Key Exchange Key）：用于更新 db / dbx。
- **db**：信任签名列表。
- **dbx**：吊销列表。

验证失败则 `LoadImage()` 返回 `EFI_SECURITY_VIOLATION`，该启动项被跳过。

### 4.4 Option ROM

PCIe 设备板卡上的 Flash 芯片，包含设备固件。BDS 在 PCI 枚举阶段通过读取 Expansion ROM BAR 发现并加载。UEFI Image 形式的 Option ROM 可提供 Driver Binding 和 HII 配置界面。常见于 RAID 卡、NIC 网卡等外设。

---

## 5. 附录：参考规范

| 文档 | 说明 |
|------|------|
| UEFI Specification 2.10 | UEFI 接口与服务规范 |
| UEFI PI Specification 1.9 | 平台初始化架构规范（SEC / PEI / DXE 核心接口） |
| EDK II 源码 | 开源 UEFI 实现参考 |

