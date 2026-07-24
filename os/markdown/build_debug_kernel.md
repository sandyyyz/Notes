# Build kernel

## clone kernel code of specific version

## make menuconfig

## make

## debug

使用buildroot构建内核。在container内部启动qemu, 并尝试在host端使用gdb对内核进行调试。  
创建并启动container配置参数：  

### host端: ubuntu2404.sh

```sh
#!/bin/bash
# ubuntu2404.sh
docker ps -a | grep ${USER}_ubuntu2404 > /dev/null
if [ $? -eq 0 ]; then
        # the container has been created.
        docker ps -a | grep ${USER}_ubuntu2404 | grep "Exited (" > /dev/null
        if [ $? -eq 0 ]; then
                # The container has been exited, start it
                docker start -i ${USER}_ubuntu2404
        else
                # The container has been started, exec another one
                docker exec -it ${USER}_ubuntu2404 bash
        fi
else
        # create new container
        docker run --rm -it \
                        -u $USER \
                        -e HOME="/mnt/home/${USER}" \
                        -p 127.0.0.1:1234:1234 \
                        -v /mnt/lib:/mnt/lib \
                        -v /mnt/repo:/mnt/repo \
                        -v /mnt/home/$USER:/mnt/home/$USER \
                        --name ${USER}_ubuntu2404 \
                        ubuntu:24.04 bash
fi
```

### host-gdb: .gdbinit

```gdb
# Linux kernel GDB initialization for QEMU
# Kernel image: /home/huangzs/data/workspace/buildroot/output/build/linux-6.18.7/vmlinux
# QEMU gdbstub: 127.0.0.1:1234

set $VMLINUX = "/home/huangzs/data/workspace/buildroot/output/build/linux-6.18.7/vmlinux"
set $KERNEL_SRC = "/home/huangzs/data/workspace/buildroot/output/build/linux-6.18.7"

# Basic interaction settings
set confirm off
set pagination on
set height 25
set width 0
set breakpoint pending on
set history save on
set history filename ~/.gdb_history
set history size 10000
set verbose off

# Output and source display
set print pretty on
set print object on
set print array on
set print array-indexes on
set print elements 0
set print repeats 0
set print frame-arguments all
set listsize 20
set disassemble-next-line auto

# Do not let a bad pointer read abort a command too early
set unwindonsignal on

# Load the uncompressed kernel image and symbols
file /home/huangzs/data/workspace/buildroot/output/build/linux-6.18.7/vmlinux

# Permit and load Linux kernel GDB helper commands, such as lx-symbols,
# lx-dmesg, lx-ps, lx-lsmod and lx-version.
add-auto-load-safe-path /home/huangzs/data/workspace/buildroot/output/build/linux-6.18.7/scripts/gdb/vmlinux-gdb.py
source /home/huangzs/data/workspace/buildroot/output/build/linux-6.18.7/scripts/gdb/vmlinux-gdb.py

# Connect to the QEMU gdbstub. Start QEMU with -S -gdb tcp::1234
# (or the equivalent -s option for port 1234).
target remote 127.0.0.1:1234

# Convenient aliases
command alias -a c = continue
command alias -a si = stepi
command alias -a ni = nexti
command alias -a bt = backtrace
command alias -a i = info

# Reconnect after QEMU has been restarted.
define reconnect
    dont-repeat
    disconnect
    target remote 127.0.0.1:1234
end
document reconnect
Disconnect from and reconnect to the QEMU gdbstub at 127.0.0.1:1234.
end

# Show the current instruction and a compact register set.
define kcontext
    dont-repeat
    printf "\\n--- Backtrace ---\\n"
    backtrace
    printf "\\n--- Current instruction ---\\n"
    x/10i $pc
    printf "\\n--- Registers ---\\n"
    info registers
end
document kcontext
Show the current kernel backtrace, nearby instructions, and registers.
end

# Load symbols for currently loaded kernel modules after the guest has booted.
define kmodules
    dont-repeat
    lx-symbols
end
document kmodules
Load symbols for the running kernel and currently loaded modules using lx-symbols.
end

# Enable GDB TUI mode
tui enable

# Top: source + assembly
# Bottom: command + general-purpose registers
# BUG!! cannot split registers and commandline
# tui new-layout kall {-horizontal src 1 asm 1} 2 status 0 {-horizontal cmd 1 regs 1} 1

# layout kall
# Set a new layout with src and asm and regs split horizonatally
tui new-layout allsplit \
{-horizontal src 3 asm 3 regs 2} 2 \
status 0 \
cmd 1

# Set a layout with src and asm split horizontailly
tui new-layout hsplit \
{-horizontal src 1 asm 1} 2 \
status 0 \
cmd 1

# show general regs
tui reg general
# Display source and assembly simultaneously
# layout split

layout hsplit
# Keep command input focus in the command window
focus cmd

# Use Intel syntax on x86/x86_64.
# For ARM, AArch64 or RISC-V, remove this line.
set disassembly-flavor intel

# Automatically display the next instruction while stepping
set disassemble-next-line on

# Display source line information mixed with assembly
set print asm-demangle on
# Stop at useful early kernel entry points. Run manually when needed:
break start_kernel
#   break rest_init
#   break panic
#   break __warn

printf "Loaded Linux kernel symbols from %s\\n", $VMLINUX
# printf "Connected to QEMU gdbstub at %s\\n", $POR
# printf "Useful commands: kcontext, kmodules, lx-dmesg, lx-ps, lx-lsmod, reconnect\\n"
```
### container: start-qemu-gdb.sh
``` sh
#!/bin/sh
# start-qemu-gdb.sh
set -x
BINARIES_DIR="${0%/*}/"
# kernel command line
KERNEL_CMDLINE="rootwait root=/dev/vda console=tty1 console=ttyS0"
KERNEL_CMDLINE="${KERNEL_CMDLINE} nokaslr norandmaps"
# shellcheck disable=SC2164
cd "${BINARIES_DIR}"

mode_serial=false
mode_sys_qemu=false
while [ "$1" ]; do
    case "$1" in
    --serial-only|serial-only) mode_serial=true; shift;;
    --use-system-qemu) mode_sys_qemu=true; shift;;
    --) shift; break;;
    *) echo "unknown option: $1" >&2; exit 1;;
    esac
done

if ${mode_serial}; then
    EXTRA_ARGS='-nographic'
else
    EXTRA_ARGS='-serial stdio'
fi

if ! ${mode_sys_qemu}; then
    export PATH="/mnt/home/huangzs/workspace/buildroot/output/host/bin:${PATH}"
fi

# 这里通过-gdb参数指定监听来自所有ip地址的1234端口的连接请求
exec qemu-system-x86_64 -S -gdb tcp:0.0.0.0:1234 -M pc -kernel bzImage -drive file=rootfs.ext2,if=virtio,format=raw -append "${KERNEL_CMDLINE}" -net nic,model=virtio -net user  ${EXTRA_ARGS} "$@"
```

### docker port publish

这张图很好地展示了流程：  
![container port publish](https://iximiuz.com/docker-publish-container-ports/docker-engine-port-publishing-2000-opt.png)
启动参数为：  
```cmd
$ docker run -d -p 8080:80 --name nginx-1 nginx
```
此时host端的8080端口被映射到container内的80端口。  

## Q&A

Q: 这里有一个关键问题, container通过namespace机制和外界隔离，拥有独立的网络视图，那么此时host-gdb该如何访问container qemu所监听的网络接口呢？  
A: 参见[port_publishing](https://docs.docker.com/engine/network/port-publishing/),docker允许“publish a container's port(s) to the host".为了实现这个功能，需要在docker run时通过-p指定需要publish的端口。  
其语法格式如下：  
docker run -p [host_ip] : host_port : container_post.  
这里的port是针对tcp连接而言的，官方还提供了publish UDP端口的方法，在此不赘述。  

Q: 为什么这里是"publish a container's port", 而不是"publish a constainer's ip:port"?  
A: 容器端不需要在 -p 中写 IP，并不只是因为创建时 IP 尚未确定，而是因为目标容器和目标网络端点已经由 Docker 配置上下文确定。不需要显式指定。

Q: 在"publish a container's port"之后，container's qemu为什么监听的是"0.0.0.0:1234",即允许来自所有ip地址的port 1234的连接？  
A: 容器连接多个网络后，会在同一个容器网络命名空间中拥有多个接口和多个本地 IP。若应用监听 0.0.0.0:PORT，它会匹配这个网络命名空间中所有 IPv4 本地地址上的该端口，因此可能同时接收来自不同 Docker 网络、宿主机发布端口以及容器自身回环之外可达接口的流量。publish 只增加从宿主机地址到容器端口的转发路径，不会将该端口限制为只能接收发布路径的流量，也不会把一次连接复制到所有容器接口。若要限制服务只接收某个网络的流量，应绑定该网络接口的具体容器 IP，或者配置网络及防火墙访问控制。  
目前我对docker网络栈还不够熟悉，不太清楚具体运作的逻辑。在我看来这样监听的确有可能同时接收来自不同接口的流量。  
如果需要修改的话，是否需要显式指定container-ip? 如何指定？

Q: "publish container's port"时map的host端ip地址可以是回环地址之外的吗？  
A: HOST_IP 完全可以是回环地址之外的宿主机地址。常用回环地址并非 Docker 的技术限制，而是一种最小暴露面的安全选择.  

## ref
read this :  
https://iximiuz.com/en/posts/docker-publish-container-ports/  

https://github.com/bitristan/docker-linux-2.6.26-build

