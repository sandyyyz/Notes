# PXE - iPXE

类比 [system_boot](./system_boot.md) 中提到的系统启动方式。
PXE 与 iPXE 启动 Linux 安装环境时，最终需要的 Kernel、initramfs 和安装 RootFS 通常没有本质区别；区别主要集中在谁承担网络 bootloader 角色、如何获取启动配置、支持哪些网络协议，以及是否需要额外 chainload GRUB。
网络启动改变的是这些文件的来源和装载方式，而不是 Kernel 与 initramfs 进入内存后的执行机制。

## PXE 与 iPXE 对照

| 维度 | PXE | iPXE |
| --- | --- | --- |
| 固件支持 | 多数网卡/UEFI 原生支持 | 可集成进固件，也可由 PXE chainload |
| 首个加载文件 | NBP，如 `grubx64.efi`、`pxelinux.0` | `ipxe.efi` 或嵌入式 iPXE |
| 常见传输协议 | DHCP + TFTP | HTTP/HTTPS/FTP/iSCSI/NFS 等 |
| 配置形式 | GRUB/PXELINUX 配置 | `.ipxe` 脚本 |
| 优势 | 兼容性好、部署基础简单 | 协议能力强、脚本表达灵活、适合大规模安装 |

## PXE boot

### uefi

当选择通过 PXE 引导时，UEFI firmware 会尝试通过网卡向 DHCP 服务器发送请求，获取 IP 地址、网关、DNS、TFTP 服务器地址等信息。
DHCP 服务器在响应请求时，会返回 TFTP server 地址以及引导文件名称和路径。

### shim

uefi 尝试向 tftp 服务器获取 shim.efi（在这里是 bootx64.efi）。
有关 shim.efi 的功能，详见 [system_boot](./system_boot.md) 中有关 shim 一节。
在这里，bootx64.efi 将从 tftp 服务器获取对应的 grub.efi 文件。

NBP, Network Bootstrap Program，网络引导程序。  
它是客户端在PXE启动过程中通过网络下载并执行的第一个可执行文件，其作用是接替固件中能力有限的PXE环境，继续加载启动配置、Kernel和initramfs，或者链式加载另一个Bootloader。

### bootloader

和在本地引导一样，当 grub 完成必要的初始化时，将尝试解析 grub.cfg 文件。
只不过此时 client 需要从 tftp 服务器获取对应的 grub.cfg 文件。
后续 grub 也需要将对应的 kernel 和 initramfs 载入内存，只不过此时这些文件的来源是 tftp 服务器，而非本地。当成功载入 kernel 与 initramfs，并且一号进程启动后，就可以通过网络向 tftp 服务器获取系统文件，并安装系统。

PXE 通常先由 UEFI 或网卡 PXE 固件通过 DHCP 获得客户端地址、TFTP 服务器地址和 NBP 文件名，再通过 TFTP 下载并执行 NBP，例如 `grubx64.efi`、`pxelinux.0` 或其他网络启动加载程序。
NBP 随后读取配置，继续获取 Kernel 和 initramfs。
PXE 所定义的主要是“如何发现网络启动服务器并取得第一个可执行程序”，并不重新定义 Linux Kernel 和 initramfs 的内容。

总体流程：

```text
传统PXE：

UEFI/PXE Firmware
    ↓ DHCP
获得IP地址、TFTP服务器和NBP文件名
    ↓ TFTP
下载grubx64.efi或pxelinux.0
    ↓
读取GRUB/PXELINUX配置
    ↓ TFTP或其他协议
下载Kernel和initramfs
    ↓
Kernel执行initramfs中的/init
    ↓ HTTP/NFS/NBD
访问安装RootFS或软件包仓库
```
![pxe_boot_process](https://raw.githubusercontent.com/sandyyyz/Image-hosting/main/img/pxe_process.png)

## iPXE boot

iPXE 可以看作功能更强的网络启动程序。它既可以直接集成到网卡或固件中，也可以由原生 PXE 先通过 TFTP 下载，再通过 chainload 执行。
进入 iPXE 后，通常使用 iPXE 脚本直接描述 Kernel、initramfs 和命令行的位置，并通过 HTTP、HTTPS、FTP、iSCSI 等协议获取这些内容。
一个 .ipxe 脚本：

```sh
#!ipxe
kernel http://server/linux/vmlinuz \
initrd=initrd.img \
inst.repo=http://server/repo
initrd http://server/linux/initrd.img
boot
```

此时，iPXE 相当于直接承担了网络 bootloader 的工作，启动流程为：
```
UEFI → PXE Firmware → iPXE → Kernel → initramfs
```
当然，iPXE 也可以加载 `grubx64.efi`，此时的启动流程为：
```
UEFI → PXE Firmware → iPXE → GRUB → Kernel → initramfs
```

## 总结

Q: 安装 rootfs 不一定一次性完整下载到内存？

PXE 和 iPXE 都允许计算机通过网络加载并启动系统。相较于本地启动，它们主要改变文件来源和装载方式，并不改变装载 initramfs 和 Kernel 之后的执行语义。

与此同时，这二者还有不同：

1. 第一，初始网络启动程序不同。传统 PXE 必须先取得一个 NBP，可能是 grubx64.efi 或 pxelinux.0；iPXE 场景通常需要 ipxe.efi 或其他 iPXE 构建产物，除非 iPXE 已经集成在固件中。因此，最终 Kernel 和 initramfs 可以相同，但前置启动文件不完全相同。
2. 第二，配置文件形式不同。GRUB 一般读取 grub.cfg，iPXE 则执行 .ipxe 脚本。它们表达的信息基本相同，都是 Kernel 位置、initramfs 位置和 Kernel Command Line，但语法和执行模型不同。
