# 系统启动流程

## UEFI

系统上电后，跳转到一条固定地址执行，该地址存放了uefi-firmware程序，UEFI固件将完成CPU初始化、RAM初始化、pcie设备枚举等工作，尝试读取ESP中的efi程序，随后把该程序加载到内存进行执行。  
在x86_64平台上，UEFI约定默认启动文件路径为：
```
\EFI\BOOT\BOOTX64.EFI
```

## shim

UEFI开启Secure Boot后，不会执行任意.efi文件，而只会执行签名能够被固件信任数据库验证的EFI程序。多数PC出厂时预置了Microsoft UEFI CA等证书，但通常没有Ubuntu、Fedora、Debian等Linux发行版自己的证书。  
如果要求每个用户手动把发行版证书写入主板固件，部署和维护会非常困难。

Shim采用两级验证方式解决这一问题：  
```
UEFI Firmware
    │
    │ 使用固件db中的证书验证
    ▼
shimx64.efi
    │
    │ 使用Shim内置的发行版证书或MOK验证
    ▼
grubx64.efi
    │
    │ 验证并加载
    ▼
Linux Kernel
```
发行版首先构建一个体积较小、功能有限的shimx64.efi，在其中嵌入自己的公钥，然后让Shim本身获得固件能够信任的签名。  
UEFI验证并执行Shim后，Shim不再要求后续程序必须直接受固件信任，而是使用自己内置的发行版证书或用户注册的MOK来验证grubx64.efi。  
这样，固件只需要信任Shim，发行版就可以自行管理GRUB及后续组件的签名。  
Shim不是GRUB的必备前级，也不是Secure Boot本身，而是Linux发行版常用的一种Secure Boot适配方案。它的本质作用可以概括为：  
```
让UEFI先信任Shim，
再由Shim信任发行版或用户签名的GRUB，
从而把固件的Secure Boot信任链延伸到Linux启动链。
```

## bootloader

bootloader的职责是找到kernel与initrd,并且将他们装入内核。在bootloader被载入内存执行后，首先需要初始化自己的执行环境，包括一个脚本解释器，之后会在固定的目录下寻找自己的配置文件，如/boot/grub/grub.cfg..  
GRUB在自身启动并完成基本初始化后，通过prefix定位并执行$prefix/grub.cfg；  
它从中获得启动菜单、Kernel和initramfs的位置、Kernel Command Line及相关加载策略。  
读取某个名为grub.cfg的外部文件并非协议上的硬性要求，但GRUB必须以某种方式获得等价的启动命令；外部grub.cfg只是通用系统中最灵活、最常用的实现方式。  
随后，由bootloader的脚本解释器解析执行该配置文件。该配置文件实际上记录了kernel、initrd的路径，以及向kernel传递的参数等重要信息。当bootloader成功将kernel与initrd载入内存后，将执行流切换至内核。

## kernel

kernel首先完成内存、中断、调度、设备模型、驱动等初始化，此时内核可以正确管理CPU和内存。但是，由于驱动包含：  

1. 编译进vmlinuz的驱动(built-in),在载入内核后可以执行。
2. 以module形式存在于rootfs内的驱动,需要从rootfs内载入内存后执行。

此时由于缺少必要的nvme等磁盘驱动，很可能还无法访问rootfs。  

---
Q: 为什么不直接将必要的驱动提前编译进内核？  
A: 因为仅靠内建驱动无法优雅地解决通用硬件适配、模块化维护以及复杂存储初始化问题。固定硬件、简单根设备的系统可以将必要驱动内建并省略initramfs；通用发行版则通常采用“较通用的内核＋模块化驱动＋initramfs早期用户空间”，以获得更好的通用性、灵活性和可维护性。

---

## initrd/initramfs

initrd和initramfs实际上是两个为了实现相同目的而设计的不同机制。  
initrd-initial ram disk, 将文件系统镜像放入内存并模拟成块设备，内核需要具体文件系统驱动将其挂载。  
而initramfs-initial ram filesystem,将文件系统通过CPIO归档，内核可以将其解包到内存中的rootfs， 不需要经过块设备层。  
目前initrd基本已经由initramfs代替。  
initramfs本质上是一个能够独立运行的、位于内存中的最小用户空间，其内容只需要满足一个目标：让内核能够找到、准备并挂载真正的RootFS，然后把启动流程交给真实根文件系统中的PID 1。  

内核识别initramfs缓冲区，将其中的CPIO归档解压到rootfs，于是initramfs中的目录和文件成为当前可见的根目录.

```
/
├── init
├── bin/
├── sbin/
├── lib/
├── lib64/
├── lib/modules/<kernel-version>/
├── dev/
├── proc/
├── sys/
├── run/
├── etc/
└── usr/
```
其中最关键的是根目录下的/init。它是initramfs阶段的入口程序，内核完成自身初始化后会尝试执行它。  
/init可以是Shell脚本、BusyBox程序，也可以是systemd或dracut提供的初始化程序；它负责组织整个早期用户空间的启动流程。  
bin、sbin和usr中通常包含mount、modprobe、udevadm、blkid、fsck、switch_root等必要工具，很多精简系统使用BusyBox统一提供这些命令；  
lib/modules/<kernel-version>保存访问根设备所需的内核模块，例如NVMe、SCSI、VirtIO、USB存储、RAID、Device Mapper及文件系统模块；  
lib和lib64保存动态链接库以及可能需要的固件；  
etc中则可能包含模块加载配置、udev规则以及用于识别根设备、LVM、RAID和加密卷的配置。  
initramfs也可能包含cryptsetup、LVM、mdadm、multipath、iSCSI和网络配置工具，具体内容取决于真实RootFS的存储组织方式.  
随后，内核结束内核态的初始化，并创建第一个用户进程。  
/init 读取内核命令行，尤其是boot loader通过Linux commandline 传入的参数，根据这些参数确定真正rootfs的位置和访问方式，同时启动udev或等价的设备管理机制，触发设备枚举，并使用modprobe加载对应的内核模块。驱动加载后，内核才能识别磁盘控制器及磁盘设备，并在/dev下产生相应设备节点。  
当目标设备准备完成时，initramfs将真实的rootfs挂载，此时系统中存在两个根文件系统。随后initramfs需要切换根文件系统，并且完成对旧根文件系统的清理。并在同一个PID 1进程上下文中通过execve()执行真实RootFS里的/sbin/init  
整体流程概括如下：  

```
UEFI firmware
    ↓
(shim, optional)
    ↓
Bootloader
    ↓
加载Kernel和initramfs
    ↓
Kernel完成自身初始化
    ↓
Kernel解压initramfs到rootfs
    ↓
Kernel执行/init，产生早期用户空间PID 1
    ↓
挂载/proc、/sys、/dev和/run
    ↓
解析root=等内核命令行参数
    ↓
加载存储及文件系统模块
    ↓
识别磁盘、组装RAID、激活LVM或解锁LUKS
    ↓
将真实RootFS挂载到/sysroot
    ↓
switch_root
    ↓
执行真实RootFS中的/sbin/init
    ↓
systemd作为PID 1继续启动系统服务
```
至此，内核启动完成。

## 补充

“首次安装启动”与“安装后第一次启动”不能混为一谈。  
首次安装启动运行的是安装介质中的临时操作系统，其RootFS通常来自SquashFS、网络镜像或其他只读安装镜像；安装程序在这个临时系统里创建目标磁盘上的新系统。  
安装完成后的第一次重启，才会由目标磁盘上的EFI程序、GRUB、Kernel、initramfs和RootFS组成正常启动链路。  
区别可以概括为：

```
安装阶段：

UEFI
 → 安装介质Bootloader
 → 安装介质Kernel
 → 安装介质initramfs
 → 安装介质临时RootFS
 → 安装程序
 → 创建目标磁盘系统

安装后正常启动：

UEFI
 → 目标磁盘Bootloader
 → 目标磁盘Kernel
 → 目标磁盘initramfs
 → 目标磁盘RootFS
 → systemd

```

Todo:
1. edk2 source code
2. grub source code
3. linux source code (init-initramfs related)
