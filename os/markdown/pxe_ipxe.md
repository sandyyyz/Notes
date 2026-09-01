# PXE - iPXE

类比[system_boot](./system_boot.md)中提到的系统启动方式。  
PXE与iPXE启动Linux安装环境时，最终需要的Kernel、initramfs和安装RootFS通常没有本质区别；  
区别主要集中在谁承担网络Bootloader角色、如何获取启动配置、支持哪些网络协议，以及是否需要额外链式加载GRUB。  
网络传输改变的是这些文件的来源和装载方式，而不是Kernel与initramfs进入内存后的执行机制。  

## PXE boot

### uefi

当选择通过pxe引导时，uefi firmware会尝试通过网卡向dhcp服务器发送请求，获取ip地址、网关、dns、tftp服务器ip地址等信息。  
dhcp服务器在响应dhcp请求时，会在响应中包含tftp服务器的ip地址和引导⽂件的名称和路径等信息

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

PXE通常先由UEFI或网卡PXE固件通过DHCP获得客户端地址、TFTP服务器地址和NBP文件名，再通过TFTP下载并执行NBP，例如grubx64.efi、pxelinux.0或其他网络启动加载程序；  
NBP随后读取配置，继续获取Kernel和initramfs。  
PXE所定义的主要是“如何发现网络启动服务器并取得第一个可执行程序”，并不重新定义Linux Kernel和initramfs的内容.  

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

iPXE可以看作功能更强的网络启动程序。它既可以直接集成到网卡或固件中，也可以由原生PXE先通过TFTP下载，再通过chainload执行。  
进入iPXE后，通常使用iPXE脚本直接描述Kernel、initramfs和命令行的位置，并通过HTTP、HTTPS、FTP、iSCSI等协议获取这些内容。  
一个 .ipxe 脚本：

```sh
#!ipxe
kernel http://server/linux/vmlinuz \
initrd=initrd.img \
inst.repo=http://server/repo
initrd http://server/linux/initrd.img
boot
```

此时，iPXE相当于直接承担了网络bootloader的工作。此时的启动流程为：  
```
UEFI → PXE Firmware → iPXE → Kernel → initramfs
```
当然，iPXE也可以加载grubx64.efi, 此时的启动流程为：  
```
UEFI → PXE Firmware → iPXE → GRUB → Kernel → initramfs
```

## 总结

Q: 安装 rootfs 不一定一次性完整下载到内存？

PXE 和 iPXE 是两种允许计算机通过网络远程加载并启动系统的协议。相较于从本地加载启动系统，这二者主要改变了文件的数据来源和装载方式，并没有改变装载 initramfs 和 kernel 之后的行为。

与此同时，这二者还有不同：

1. 第一，初始网络启动程序不同。传统 PXE 必须先取得一个 NBP，可能是 grubx64.efi 或 pxelinux.0；iPXE 场景通常需要 ipxe.efi 或其他 iPXE 构建产物，除非 iPXE 已经集成在固件中。因此，最终 Kernel 和 initramfs 可以相同，但前置启动文件不完全相同。
2. 第二，配置文件形式不同。GRUB 一般读取 grub.cfg，iPXE 则执行 .ipxe 脚本。它们表达的信息基本相同，都是 Kernel 位置、initramfs 位置和 Kernel Command Line，但语法和执行模型不同。
