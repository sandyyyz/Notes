# Build kernel
本次采用服务器ubuntu24.04镜像构建container，并在container内部build kernel.
首先是编译一个特定版本的完整内核。
本次编译的是Linux 7.2.0-rc4内核。

## clone kernel code of specific version

首先基于提供的脚本略作修改，创建一个container。具体程序见ubuntu2404.sh。在创建好container后，在container使用git clone将/mnt/repo/下对应的源码目录copy到相应目录下。

## make menuconfig

make menuconfig 提供了一个方便的图形化界面调整内核编译设置。本次编译暂时未作修改。

## make

在调整好编译选项后，在目录下 make 即可。本次使用的命令是：

```sh
make deb-pkg -j20
```
由于没有安装需求，本次暂时没有install.

## 基于buildroot构建测试环境

Buildroot 编译出的 Linux 内核与直接克隆内核仓库编译出的内核，可能基于完全相同的 Kbuild 和源码，但默认不能认为二者相同。 Buildroot 通常会控制源码版本、补丁、配置、交叉工具链、构建变量、设备树、模块安装和 rootfs 集成；直接编译则由开发者手工提供这些条件。

本次构建重心放在这里。按照培训材料中的参考文档，大概有以下几个步骤：

1. 下载 buildroot 源码
2. 通过 `make qemu_x86_64_defconfig` 配置 buildroot，使得编译带有调试符号的 packages
3. 通过 `make linux-menuconfig` 配置编译内核选项，和上面尝试编译一个完整 Linux 内核是一样的。需要打开 *kernel debugging*、*Provide GDB scripts for kernel debugging*、*Generate readable assembler code*、*KGDB: kernel debugger*，以便后续调试
4. make

TODO: 关键的调试配置如下：

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
# Set a new layout with src and asm and regs split horizontally
tui new-layout allsplit \
{-horizontal src 3 asm 3 regs 2} 2 \
status 0 \
cmd 1

# Set a layout with src and asm split horizontally
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
```sh
docker run -d -p 8080:80 --name nginx-1 nginx
```
此时host端的8080端口被映射到container内的80端口。

host-gdb:
![host-gdb](https://raw.githubusercontent.com/sandyyyz/Image-hosting/main/img/host-gdb.png)

container-qemu:
![container-qemu](https://raw.githubusercontent.com/sandyyyz/Image-hosting/main/img/container-qemu.png)

## Q&A

Q: 这里有一个关键问题, container通过namespace机制和外界隔离，拥有独立的网络视图，那么此时host-gdb该如何访问container qemu所监听的网络接口呢？
A: 参见[port_publishing](https://docs.docker.com/engine/network/port-publishing/),docker允许“publish a container's port(s) to the host".为了实现这个功能，需要在docker run时通过-p指定需要publish的端口。
其语法格式如下：

```sh
docker run -p [host_ip]:host_port:container_port
```

这里的 port 是针对 tcp 连接而言的，官方还提供了 publish UDP 端口的方法，在此不赘述。

Q: 为什么这里是 "publish a container's port"，而不是 "publish a container's ip:port"？
A: 容器端不需要在 -p 中写 IP，并不只是因为创建时 IP 尚未确定，而是因为目标容器和目标网络端点已经由 Docker 配置上下文确定。不需要显式指定。

Q: 在"publish a container's port"之后，container's qemu为什么监听的是"0.0.0.0:1234",即允许来自所有ip地址的port 1234的连接？
A: 容器连接多个网络后，会在同一个容器网络命名空间中拥有多个接口和多个本地 IP。若应用监听 0.0.0.0:PORT，它会匹配这个网络命名空间中所有 IPv4 本地地址上的该端口，因此可能同时接收来自不同 Docker 网络、宿主机发布端口以及容器自身回环之外可达接口的流量。publish 只增加从宿主机地址到容器端口的转发路径，不会将该端口限制为只能接收发布路径的流量，也不会把一次连接复制到所有容器接口。若要限制服务只接收某个网络的流量，应绑定该网络接口的具体容器 IP，或者配置网络及防火墙访问控制。
目前我对docker网络栈还不够熟悉，不太清楚具体运作的逻辑。在我看来这样监听的确有可能同时接收来自不同接口的流量。
如果需要修改的话，是否需要显式指定container-ip? 如何指定？

Q: "publish container's port"时map的host端ip地址可以是回环地址之外的吗？
A: HOST_IP 完全可以是回环地址之外的宿主机地址。常用回环地址并非 Docker 的技术限制，而是一种最小暴露面的安全选择.

## yocto

正常编译内核只是生成 Linux 内核及其模块，而 Yocto 用来从源码构建一套完整、可定制、可重复生成的嵌入式 Linux 系统. Yocto Project 不是一个 Linux 发行版，也不只是一个编译器。它是一套用于构建定制 Linux 发行版的框架，主要面向嵌入式设备、工业设备、汽车系统和专用硬件。最终输出通常不只是一个 Image 或 vmlinuz，而是一套能够直接启动或烧写到目标设备上的完整镜像

## rpm


### start from *.src.rpm

在尝试使用命令`rpmbuild -ba SPECS/kernel.spec`构建rpm包时，container依赖不满足：

```text
bash-5.1# ls
BUILD  BUILDROOT  RPMS  SOURCES  SPECS  SRPMS
bash-5.1# rpmbuild -ba S
SOURCES/ SPECS/   SRPMS/
bash-5.1# rpmbuild -ba SOURCES/
error: File /mnt/home/huangzs/workspace/rpmbuild/SOURCES/ is not a regular file.
bash-5.1# rpmbuild -ba SOURCES/
Makefile.rhelver
Module.kabi_aarch64
Module.kabi_dup_aarch64
Module.kabi_dup_ppc64le
Module.kabi_dup_s390x
Module.kabi_dup_x86_64
Module.kabi_ppc64le
Module.kabi_s390x
Module.kabi_x86_64
README.rst
check-kabi
cpupower.config
cpupower.service
dracut-virt.conf
filter-aarch64.sh.rhel
filter-armv7hl.sh.rhel
filter-modules.sh.rhel
filter-ppc64le.sh.rhel
filter-s390x.sh.rhel
filter-x86_64.sh.rhel
gating.yaml
generate_all_configs.sh
kernel-aarch64-64k-debug-rhel.config
kernel-aarch64-64k-rhel.config
kernel-aarch64-debug-rhel.config
kernel-aarch64-rhel.config
kernel-aarch64-rt-debug-rhel.config
kernel-aarch64-rt-rhel.config
kernel-abi-stablelists-5.14.0-284.187.1.el9_2.tar.bz2
kernel-abi-stablelists-5.14.0-503.40.1.el9_5.tar.bz2
kernel-kabi-dw-5.14.0-284.187.1.el9_2.tar.bz2
kernel-kabi-dw-5.14.0-503.40.1.el9_5.tar.bz2
kernel-local
kernel-ppc64le-debug-rhel.config
kernel-ppc64le-rhel.config
kernel-s390x-debug-rhel.config
kernel-s390x-rhel.config
kernel-s390x-zfcpdump-rhel.config
kernel-x86_64-debug-rhel.config
kernel-x86_64-rhel.config
kernel-x86_64-rt-debug-rhel.config
kernel-x86_64-rt-rhel.config
kernel.changelog
kvm_stat.logrotate
linux-5.14.0-284.187.1.el9_2.tar.xz
linux-5.14.0-503.40.1.el9_5.tar.xz
linux-kernel-test.patch
merge.pl
mod-denylist.sh
mod-extra.list.rhel
mod-internal.list
mod-kvm.list
mod-partner.list
mod-sign.sh
nvidiagpuoot001.x509
parallel_xz.sh
partial-kgcov-snip.config
patch-5.14-redhat.patch
process_configs.sh
rheldup3.x509
rhelima.x509
rhelima_centos.x509
rhelimaca1.x509
bash-5.1# rpmbuild -ba SPECS/kernel.spec
setting SOURCE_DATE_EPOCH=1786320000
error: Failed build dependencies:
        (systemd-boot-unsigned or (systemd-udev >= 250-13 and systemd-udev < 252-8)) is needed by kernel-5.14.0-284.187.1.el9.x86_64
        WALinuxAgent-cvm is needed by kernel-5.14.0-284.187.1.el9.x86_64
        asciidoc is needed by kernel-5.14.0-284.187.1.el9.x86_64
        audit-libs-devel is needed by kernel-5.14.0-284.187.1.el9.x86_64
        binutils-devel is needed by kernel-5.14.0-284.187.1.el9.x86_64
        clang is needed by kernel-5.14.0-284.187.1.el9.x86_64
        dracut is needed by kernel-5.14.0-284.187.1.el9.x86_64
        gcc-plugin-devel is needed by kernel-5.14.0-284.187.1.el9.x86_64
        glibc-static is needed by kernel-5.14.0-284.187.1.el9.x86_64
        hmaccalc is needed by kernel-5.14.0-284.187.1.el9.x86_64
        java-devel is needed by kernel-5.14.0-284.187.1.el9.x86_64
        kabi-dw is needed by kernel-5.14.0-284.187.1.el9.x86_64
        kernel-rpm-macros >= 185-9 is needed by kernel-5.14.0-284.187.1.el9.x86_64
        kmod is needed by kernel-5.14.0-284.187.1.el9.x86_64
        libbabeltrace-devel is needed by kernel-5.14.0-284.187.1.el9.x86_64
        libbpf-devel >= 0.6.0-1 is needed by kernel-5.14.0-284.187.1.el9.x86_64
        libcap-ng-devel is needed by kernel-5.14.0-284.187.1.el9.x86_64
        libmnl-devel is needed by kernel-5.14.0-284.187.1.el9.x86_64
        libnl3-devel is needed by kernel-5.14.0-284.187.1.el9.x86_64
        libtraceevent-devel is needed by kernel-5.14.0-284.187.1.el9.x86_64
        libtracefs-devel is needed by kernel-5.14.0-284.187.1.el9.x86_64
        lld is needed by kernel-5.14.0-284.187.1.el9.x86_64
        llvm is needed by kernel-5.14.0-284.187.1.el9.x86_64
        lvm2 is needed by kernel-5.14.0-284.187.1.el9.x86_64
        net-tools is needed by kernel-5.14.0-284.187.1.el9.x86_64
        newt-devel is needed by kernel-5.14.0-284.187.1.el9.x86_64
        numactl-devel is needed by kernel-5.14.0-284.187.1.el9.x86_64
        pciutils-devel is needed by kernel-5.14.0-284.187.1.el9.x86_64
        perl-generators is needed by kernel-5.14.0-284.187.1.el9.x86_64
        python3-devel is needed by kernel-5.14.0-284.187.1.el9.x86_64
        python3-docutils is needed by kernel-5.14.0-284.187.1.el9.x86_64
        python3-setuptools is needed by kernel-5.14.0-284.187.1.el9.x86_64
        systemd-udev >= 252-1 is needed by kernel-5.14.0-284.187.1.el9.x86_64
        tpm2-tools is needed by kernel-5.14.0-284.187.1.el9.x86_64
        xmlto is needed by kernel-5.14.0-284.187.1.el9.x86_64
```

解决办法:配置dnf代理，并且用`dnf builddep`安装依赖项:

```sh
# set proxy for dnf
grep -q '^proxy=' /etc/dnf/dnf.conf &&
    sed -i 's#^proxy=.*#proxy=http://proxy_ip:port#' /etc/dnf/dnf.conf ||
    echo 'proxy=http://proxy_ip:port' >> /etc/dnf/dnf.conf

# enable crb

dnf config-manager --set-enabled baseos
dnf config-manager --set-enabled appstream
dnf config-manager --set-enabled crb

# build dependencies

dnf builddep -y --spec SPECS/kernel.spec

```

随后重新使用`rpmbuild -ba SPECS/kernel.spec`构建rpm包

尝试为`rhel9.2 - container almalinux9.5` 使用`rpmbuild`构建rpm包时：

```text
在编译 RTLA 的 src/osnoise_hist.c 时，该文件通过系统头文件间接获得了 /usr/include/linux/sched/types.h 中的 struct sched_attr 定义，同时又通过 src/utils.h 获得了 RTLA 自己的同名定义。两个完整定义出现在同一个编译单元中，导致 GCC 报结构体重定义，继而使 src/osnoise_hist.o、RTLA 的 Make 任务以及 RPM %build 阶段依次失败。

~/workspace/rpmbuild/BUILD/kernel-5.14.0-284.187.1.el9_2/linux-5.14.0-284.187.1.el9.x86_64
+ pushd tools/tracing/rtla
~/workspace/rpmbuild/BUILD/kernel-5.14.0-284.187.1.el9_2/linux-5.14.0-284.187.1.el9.x86_64/tools/tracing/rtla ~/workspace/rpmbuild/BUILD/kernel-5.14.0-284.187.1.el9_2/linux-5.14.0-284.187.1.el9.x86_64
+ CFLAGS='-O2  -fexceptions -g -grecord-gcc-switches -pipe -Wall -Werror=format-security -Wp,-D_FORTIFY_SOURCE=2 -Wp,-D_GLIBCXX_ASSERTIONS -specs=/usr/lib/rpm/redhat/redhat-hardened-cc1 -fstack-protector-strong -specs=/usr/lib/rpm/redhat/redhat-annobin-cc1  -m64 -march=x86-64-v2 -mtune=generic -fasynchronous-unwind-tables -fstack-clash-protection -fcf-protection'
+ LDFLAGS='-Wl,-z,relro -Wl,--as-needed  -Wl,-z,now -specs=/usr/lib/rpm/redhat/redhat-hardened-ld -specs=/usr/lib/rpm/redhat/redhat-annobin-cc1 '
+ /usr/bin/make -s 'HOSTCFLAGS=-O2  -fexceptions -g -grecord-gcc-switches -pipe -Wall -Werror=format-security -Wp,-D_FORTIFY_SOURCE=2 -Wp,-D_GLIBCXX_ASSERTIONS -specs=/usr/lib/rpm/redhat/redhat-hardened-cc1 -fstack-protector-strong -specs=/usr/lib/rpm/redhat/redhat-annobin-cc1  -m64 -march=x86-64-v2 -mtune=generic -fasynchronous-unwind-tables -fstack-clash-protection -fcf-protection' 'HOSTLDFLAGS=-Wl,-z,relro -Wl,--as-needed  -Wl,-z,now -specs=/usr/lib/rpm/redhat/redhat-hardened-ld -specs=/usr/lib/rpm/redhat/redhat-annobin-cc1 ' -s
In file included from src/osnoise_hist.c:17:
src/utils.h:47:8: error: redefinition of 'struct sched_attr'
   47 | struct sched_attr {
      |        ^~~~~~~~~~
In file included from /usr/include/bits/sched.h:60,
                 from /usr/include/sched.h:43,
                 from src/osnoise_hist.c:15:
/usr/include/linux/sched/types.h:98:8: note: originally defined here
   98 | struct sched_attr {
      |        ^~~~~~~~~~
make: *** [<builtin>: src/osnoise_hist.o] Error 1
error: Bad exit status from /var/tmp/rpm-tmp.tlANQd (%build)




RPM build errors:
    Bad exit status from /var/tmp/rpm-tmp.tlANQd (%build)
```
尝试使用`rhel9.5`, 问题依旧出现。

原因：  

```
系统 kernel-headers 已提供 struct sched_attr
+
glibc 的 sched.h 将其暴露给用户程序
+
旧 RTLA 又自行定义 struct sched_attr
=
重复定义
```

检查两个文件中的定义：(container -almalinux 9.5, src.rpm rhel 9.5)

```c

bash-5.1# grep -n -A 20 -B 5 \
    'struct sched_attr' \
    /usr/include/linux/sched/types.h
93- * A task with a max utilization value smaller than 1024 is more likely
94- * scheduled on a CPU with no more capacity than the specified value.
95- *
96- * A task utilization boundary can be reset by setting the attribute to -1.
97- */
98:struct sched_attr {
99-     __u32 size;
100-
101-    __u32 sched_policy;
102-    __u64 sched_flags;
103-
104-    /* SCHED_NORMAL, SCHED_BATCH */
105-    __s32 sched_nice;
106-
107-    /* SCHED_FIFO, SCHED_RR */
108-    __u32 sched_priority;
109-
110-    /* SCHED_DEADLINE */
111-    __u64 sched_runtime;
112-    __u64 sched_deadline;
113-    __u64 sched_period;
114-
115-    /* Utilization hints */
116-    __u32 sched_util_min;
117-    __u32 sched_util_max;
118-
bash-5.1# grep -n -A 25 -B 5 'struct sched_attr' tools/tracing/rtla/src/utils.h
44-update_sum(unsigned long long *a, unsigned long long *b)
45-{
46-     *a += *b;
47-}
48-
49:struct sched_attr {
50-     uint32_t size;
51-     uint32_t sched_policy;
52-     uint64_t sched_flags;
53-     int32_t sched_nice;
54-     uint32_t sched_priority;
55-     uint64_t sched_runtime;
56-     uint64_t sched_deadline;
57-     uint64_t sched_period;
58-};
59-
60:int parse_prio(char *arg, struct sched_attr *sched_param);
61-int parse_cpu_set(char *cpu_list, cpu_set_t *set);
62:int __set_sched_attr(int pid, struct sched_attr *attr);
63:int set_comm_sched_attr(const char *comm_prefix, struct sched_attr *attr);
64-int set_comm_cgroup(const char *comm_prefix, const char *cgroup);
65-int set_pid_cgroup(pid_t pid, const char *cgroup);
66-int set_cpu_dma_latency(int32_t latency);
67-int auto_house_keeping(cpu_set_t *monitored_cpus);
68-
69-#define ns_to_usf(x) (((double)x/1000))
70-#define ns_to_per(total, part) ((part * 100) / (double)total)
bash-5.1#
```

检索到上游有相关的 patches 修复了对应的问题：[collision rtla -glibc](https://lore.kernel.org/all/?q=%22tools/rtla:%20fix%20collision%20with%20glibc%22)
尝试使用b4下载原始mbx文件:
`b4 am "20241204155003.2213733-4-sashal@kernel.org"`
由于该系列补丁包含15个patches, 我们需要的是第四个patch， 使用 `git mailsplit`提取邮件。

```sh
git mailsplit \
-o/tmp/rtla-mails \
path/to/*.mbx
```
然后寻找目标邮件：

```sh
grep -l \
    'tools/rtla: fix collision with glibc' \
    /tmp/rtla-mails/*

grep -E '^(From:|Date:|Subject:|Message-ID:)' \
    /tmp/rtla-mails/0004

grep -n '^diff --git' \
    /tmp/rtla-mails/0004

```

随后在`/path/to/rpmbuild/linux*/`目录下，构建一个git 仓库。

```sh
git init
git add .
git commit -m "xxx"
```

最后应用对应目标邮件：

```sh

git am /tmp/rtla-mails/0004

```

此时产生冲突：

```sh
bash-5.1# git am /tmp/rtla-mails/0004
Applying: tools/rtla: fix collision with glibc sched_attr/sched_set_attr
error: patch failed: tools/tracing/rtla/src/utils.h:54
error: tools/tracing/rtla/src/utils.h: patch does not apply
Patch failed at 0001 tools/rtla: fix collision with glibc sched_attr/sched_set_attr
hint: Use 'git am --show-current-patch=diff' to see the failed patch
hint: When you have resolved this problem, run "git am --continue".
hint: If you prefer to skip this patch, run "git am --skip" instead.
hint: To restore the original branch and stop patching, run "git am --abort".
hint: Disable this message with "git config set advice.mergeConflict false"
```

解决冲突后`git add xx.xx`, `git am --continue`即可应用patch  
单独编译`make -C tools/tracing/rtla V=1`编译成功。  

但是上述的方法有一个问题, `rpmbuild -ba` 会从 `%prep` 阶段重新开始, 直接修改 `BUILD/kernel-.../linux-.../` 只能用于临时验证。正式构建时，必须把 `RTLA` 修改保存成 `patch`，放入 `SOURCES/`，并让 `kernel.spec` 在 `%prep` 阶段自动应用。  

RPM构建目录：  

```
SOURCES/     永久输入：源码压缩包、补丁、配置文件
SPECS/       永久规则：如何解包、打补丁、编译和打包
BUILD/       临时工作区：每次 %prep 都可能删除重建
BUILDROOT/   临时安装根目录
RPMS/        最终二进制 RPM
SRPMS/       最终源码 RPM

```

方法一， 直接从原始邮件提取patch，不过如果源码上下文不一致的话，无法应用。  

尝试使用`git mailinfo`将mbx文件提取说明和纯diff  

```sh

git mailinfo \
    /tmp/rtla-message.txt \
    /tmp/rtla-sched-attr.patch \
    < /tmp/rtla-mails/0004
```

随后进入解压后的Linux源码根目录，检查是否能应用该patch:  

```sh
git apply --check --verbose /tmp/rtla-sched-attr.patch
```

在这里是不可以的。

方法二，手动修改源码，并且构建 patch：

为了构建 patch，需要保存修改前的文件，将当前需要修改的源码放到任意目录下：

```text
/tmp/utils.c.orig
/tmp/utils.h.orig
```

随后生成 patch：

```sh
{
    diff -u \
        --label a/tools/tracing/rtla/src/utils.c \
        --label b/tools/tracing/rtla/src/utils.c \
        /tmp/utils.c.orig \
        tools/tracing/rtla/src/utils.c || true

    diff -u \
        --label a/tools/tracing/rtla/src/utils.h \
        --label b/tools/tracing/rtla/src/utils.h \
        /tmp/utils.h.orig \
        tools/tracing/rtla/src/utils.h || true
} > ~/workspace/rpmbuild/SOURCES/rtla-sched-attr-compat.patch
```

之后需要检查 patch 是否可以 apply：

```sh
git apply --check --verbose "$patch_file"
```

随后单独编译验证：

```sh
make -C tools/tracing/rtla clean
make -C tools/tracing/rtla V=1
```

随后，将 patch 放入 `SOURCES/`，并修改 `SPECS/kernel.spec`，在其中 patch definition 部分加入一个未使用的编号，并且在对应 applypatch 部分加入要添加的 patch，如：
```
Patch9000: rtla-sched-attr-compat.patch

%if !%{nopatches}

ApplyOptionalPatch rtla-sched_attr_compat.patch

```
在这之后可以用rpmbuild进行构建。  

当然，也可以基于git仓库构建patch。由于源码目录下文件极多，使用git add .太耗时， 可以只针对需要修改的文件构造baseline，修改后使用`git diff`构造patch：  

```sh
git init

git add \
    tools/tracing/rtla/src/utils.c \
    tools/tracing/rtla/src/utils.h

git commit -m "RTLA baseline"

# 修改后...

git diff > /tmp/rtla.patch

```
随后的流程和上述相同.  
现在编译时遇到了新的问题，不过至少说明前面打的patch生效了。  
PF selftests 中故意构造非法输入的负向测试文件 dynptr_fail.c；较新的 Clang 新增或加强了 -Wuninitialized-const-pointer 检查，而 BPF selftest 将警告视为错误，最终导致 RPM %build 失败。

```

dynptr_fail.c 故意构造未初始化 dynptr
              ↓
Clang 21 检查 const pointer 参数
              ↓
产生 -Wuninitialized-const-pointer
              ↓
-Werror 将警告升级为错误
              ↓
dynptr_fail.bpf.o 无法生成
```

```sh
++ pwd
+ export BPFTOOL=/mnt/home/huangzs/workspace/rpmbuild/BUILD/kernel-5.14.0-503.40.1.el9_5/linux-5.14.0-503.40.1.el9.x86_64/tools/bpf/bpftool/bpftool
+ BPFTOOL=/mnt/home/huangzs/workspace/rpmbuild/BUILD/kernel-5.14.0-503.40.1.el9_5/linux-5.14.0-503.40.1.el9.x86_64/tools/bpf/bpftool/bpftool
+ pushd tools/testing/selftests
~/workspace/rpmbuild/BUILD/kernel-5.14.0-503.40.1.el9_5/linux-5.14.0-503.40.1.el9.x86_64/tools/testing/selftests ~/workspace/rpmbuild/BUILD/kernel-5.14.0-503.40.1.el9_5/linux-5.14.0-503.40.1.el9.x86_64
+ /usr/bin/make -s 'HOSTCFLAGS=-O2  -fexceptions -g -grecord-gcc-switches -pipe -Wall -Werror=format-security -Wp,-D_FORTIFY_SOURCE=2 -Wp,-D_GLIBCXX_ASSERTIONS -specs=/usr/lib/rpm/redhat/redhat-hardened-cc1 -fstack-protector-strong -specs=/usr/lib/rpm/redhat/redhat-annobin-cc1  -m64 -march=x86-64-v2 -mtune=generic -fasynchronous-unwind-tables -fstack-clash-protection -fcf-protection' 'HOSTLDFLAGS=-Wl,-z,relro -Wl,--as-needed  -Wl,-z,now -specs=/usr/lib/rpm/redhat/redhat-hardened-ld -specs=/usr/lib/rpm/redhat/redhat-annobin-cc1 ' -j96 ARCH=x86_64 V=1 'TARGETS=bpf cgroup mm livepatch net net/forwarding net/mptcp netfilter tc-testing memfd drivers/net/bonding iommu cachestat' SKIP_TARGETS= FORCE_TARGETS=1 INSTALL_PATH=/mnt/home/huangzs/workspace/rpmbuild/BUILDROOT/kernel-5.14.0-503.40.1.el9.x86_64/usr/libexec/kselftests VMLINUX_H= DEFAULT_INSTALL_HDR_PATH=0 install
Warning: Kernel ABI header at 'tools/include/uapi/linux/bpf.h' differs from latest version at 'include/uapi/linux/bpf.h'
Warning: Kernel ABI header at 'tools/include/uapi/linux/if_xdp.h' differs from latest version at 'include/uapi/linux/if_xdp.h'
progs/dynptr_fail.c:1391:21: error: variable 'ptr' is uninitialized when passed as a const pointer
      argument here [-Werror,-Wuninitialized-const-pointer]
 1391 |         bpf_dynptr_adjust(&ptr, 1, 2);
      |                            ^~~
progs/dynptr_fail.c:1404:22: error: variable 'ptr' is uninitialized when passed as a const pointer
      argument here [-Werror,-Wuninitialized-const-pointer]
 1404 |         bpf_dynptr_is_null(&ptr);
      |                             ^~~
progs/dynptr_fail.c:1417:24: error: variable 'ptr' is uninitialized when passed as a const pointer
      argument here [-Werror,-Wuninitialized-const-pointer]
 1417 |         bpf_dynptr_is_rdonly(&ptr);
      |                               ^~~
progs/dynptr_fail.c:1430:19: error: variable 'ptr' is uninitialized when passed as a const pointer
      argument here [-Werror,-Wuninitialized-const-pointer]
 1430 |         bpf_dynptr_size(&ptr);
      |                          ^~~
progs/dynptr_fail.c:1444:20: error: variable 'ptr1' is uninitialized when passed as a const pointer
      argument here [-Werror,-Wuninitialized-const-pointer]
 1444 |         bpf_dynptr_clone(&ptr1, &ptr2);
      |                           ^~~~
5 errors generated.
make[1]: *** [Makefile:613: /mnt/home/huangzs/workspace/rpmbuild/BUILD/kernel-5.14.0-503.40.1.el9_5/linux-5.14.0-503.40.1.el9.x86_64/tools/testing/selftests/bpf/dynptr_fail.bpf.o] Error 1
make[1]: *** Waiting for unfinished jobs....
make: *** [Makefile:157: all] Error 2
error: Bad exit status from /var/tmp/rpm-tmp.OJn5Wa (%build)
```

根据报错位置追踪`makefile:613`,修改makefile并且生成应用patch(流程同上)  
```sh
BPF_FLAGS = .... -Werror -Wno-error=uninitialized-const-pointer
```

不过即便如此，后续还是会产生非常多的错误。这样看来环境一定是有问题，与其说递归地修复未知问题，不如到此为止，暂且不编译一些工具...
```
cd /mnt/home/huangzs/workspace/rpmbuild/BUILD/kernel-5.14.0-503.40.1.el9_5/linux-5.14.0-503.40.1.el9.x86_64/tools/testing/selftests/bpf && gcc -I. -g -O0 -rdynamic -Wall -Werror -DHAVE_GENHDR   -I/mnt/home/huangzs/workspace/rpmbuild/BUILD/kernel-5.14.0-503.40.1.el9_5/linux-5.14.0-503.40.1.el9.x86_64/tools/testing/selftests/bpf -I/mnt/home/huangzs/workspace/rpmbuild/BUILD/kernel-5.14.0-503.40.1.el9_5/linux-5.14.0-503.40.1.el9.x86_64/tools/testing/selftests/bpf/tools/include -I/mnt/home/huangzs/workspace/rpmbuild/BUILD/kernel-5.14.0-503.40.1.el9_5/linux-5.14.0-503.40.1.el9.x86_64/include/generated -I/mnt/home/huangzs/workspace/rpmbuild/BUILD/kernel-5.14.0-503.40.1.el9_5/linux-5.14.0-503.40.1.el9.x86_64/tools/lib -I/mnt/home/huangzs/workspace/rpmbuild/BUILD/kernel-5.14.0-503.40.1.el9_5/linux-5.14.0-503.40.1.el9.x86_64/tools/include -I/mnt/home/huangzs/workspace/rpmbuild/BUILD/kernel-5.14.0-503.40.1.el9_5/linux-5.14.0-503.40.1.el9.x86_64/tools/include/uapi -I/mnt/home/huangzs/workspace/rpmbuild/BUILD/kernel-5.14.0-503.40.1.el9_5/linux-5.14.0-503.40.1.el9.x86_64/tools/testing/selftests/bpf -c /mnt/home/huangzs/workspace/rpmbuild/BUILD/kernel-5.14.0-503.40.1.el9_5/linux-5.14.0-503.40.1.el9.x86_64/tools/testing/selftests/bpf/prog_tests/d_path.c -lelf  -lz -lrt -lpthread -o d_path.test.o
In file included from /mnt/home/huangzs/workspace/rpmbuild/BUILD/kernel-5.14.0-503.40.1.el9_5/linux-5.14.0-503.40.1.el9.x86_64/tools/testing/selftests/bpf/prog_tests/d_path.c:5:
/mnt/home/huangzs/workspace/rpmbuild/BUILD/kernel-5.14.0-503.40.1.el9_5/linux-5.14.0-503.40.1.el9.x86_64/tools/include/uapi/linux/sched.h:114: error: "SCHED_NORMAL" redefined [-Werror]
  114 | #define SCHED_NORMAL            0
      |
In file included from /usr/include/sched.h:43,
                 from /usr/include/pthread.h:22,
                 from ./test_progs.h:33,
                 from /mnt/home/huangzs/workspace/rpmbuild/BUILD/kernel-5.14.0-503.40.1.el9_5/linux-5.14.0-503.40.1.el9.x86_64/tools/testing/selftests/bpf/prog_tests/d_path.c:3:
/usr/include/bits/sched.h:32: note: this is the location of the previous definition
   32 | # define SCHED_NORMAL           SCHED_OTHER
      |
In file included from /mnt/home/huangzs/workspace/rpmbuild/BUILD/kernel-5.14.0-503.40.1.el9_5/linux-5.14.0-503.40.1.el9.x86_64/tools/testing/selftests/bpf/prog_tests/d_path.c:5:
/mnt/home/huangzs/workspace/rpmbuild/BUILD/kernel-5.14.0-503.40.1.el9_5/linux-5.14.0-503.40.1.el9.x86_64/tools/include/uapi/linux/sched.h:136: error: "SCHED_FLAG_KEEP_ALL" redefined [-Werror]
  136 | #define SCHED_FLAG_KEEP_ALL     (SCHED_FLAG_KEEP_POLICY | \

      |
In file included from /usr/include/sched.h:43,
                 from /usr/include/pthread.h:22,
                 from ./test_progs.h:33,
                 from /mnt/home/huangzs/workspace/rpmbuild/BUILD/kernel-5.14.0-503.40.1.el9_5/linux-5.14.0-503.40.1.el9.x86_64/tools/testing/selftests/bpf/prog_tests/d_path.c:3:
/usr/include/bits/sched.h:51: note: this is the location of the previous definition
   51 | #define SCHED_FLAG_KEEP_ALL             0x18
      |
In file included from /mnt/home/huangzs/workspace/rpmbuild/BUILD/kernel-5.14.0-503.40.1.el9_5/linux-5.14.0-503.40.1.el9.x86_64/tools/testing/selftests/bpf/prog_tests/d_path.c:5:
/mnt/home/huangzs/workspace/rpmbuild/BUILD/kernel-5.14.0-503.40.1.el9_5/linux-5.14.0-503.40.1.el9.x86_64/tools/include/uapi/linux/sched.h:139: error: "SCHED_FLAG_UTIL_CLAMP" redefined [-Werror]
  139 | #define SCHED_FLAG_UTIL_CLAMP   (SCHED_FLAG_UTIL_CLAMP_MIN | \
      |
In file included from /usr/include/sched.h:43,
                 from /usr/include/pthread.h:22,
                 from ./test_progs.h:33,
                 from /mnt/home/huangzs/workspace/rpmbuild/BUILD/kernel-5.14.0-503.40.1.el9_5/linux-5.14.0-503.40.1.el9.x86_64/tools/testing/selftests/bpf/prog_tests/d_path.c:3:
/usr/include/bits/sched.h:52: note: this is the location of the previous definition
   52 | #define SCHED_FLAG_UTIL_CLAMP           0x60
      |
cc1: all warnings being treated as errors
make: *** [Makefile:617: /mnt/home/huangzs/workspace/rpmbuild/BUILD/kernel-5.14.0-503.40.1.el9_5/linux-5.14.0-503.40.1.el9.x86_64/tools/testing/selftests/bpf/d_path.test.o] Error 1
```
这里编译`.../tools/testing/selftests/bpf/prog_tests/d_path.c`产生了同类问题，内核源码树中的用户空间工具同时包含 glibc 头文件和 Linux UAPI 头文件，双方暴露了同名接口，再被 -Werror 提升为编译失败(当然一开始的重定义问题是error)。  

由于`kernel.spec`指定了该如何构建目标，为了将某部分工具从构建内容中排除在外，最直观的方法就是读`kernel.spec`,大致了解其是如何定义构建过程的。  

```
%define pkg_release %{specrelease}

# libexec dir is not used by the linker, so the shared object there
# should not be exported to RPM provides
%global __provides_exclude_from ^%{_libexecdir}/kselftests

%define _with_kabidupchk 1
# The following build options are enabled by default, but may become disabled
# by later architecture-specific checks. These can also be disabled by using
# --without <opt> in the rpmbuild command, or by forcing these values to 0.
#
# standard kernel
%define with_up        %{?_without_up:        0} %{?!_without_up:        1}
# kernel PAE (only valid for ARM (lpae))
%define with_pae       %{?_without_pae:       0} %{?!_without_pae:       1}
# kernel-debug
%define with_debug     %{?_without_debug:     0} %{?!_without_debug:     1}
# kernel-zfcpdump (s390 specific kernel for zfcpdump)
%define with_zfcpdump  %{?_without_zfcpdump:  0} %{?!_without_zfcpdump:  1}
# kernel-64k (aarch64 kernel with 64K page_size)
%define with_arm64_64k %{?_without_arm64_64k: 0} %{?!_without_arm64_64k: 1}
# kernel-rt (x86_64 and aarch64 only PREEMPT_RT enabled kernel)
%define with_realtime  %{?_without_realtime:  0} %{?!_without_realtime:  1}
# kernel-doc
%define with_doc       %{?_without_doc:       0} %{?!_without_doc:       1}
# kernel-headers
%define with_headers   %{?_without_headers:   0} %{?!_without_headers:   1}
%define with_cross_headers   %{?_without_cross_headers:   0} %{?!_without_cross_headers:   1}
# perf
%define with_perf      %{?_without_perf:      0} %{?!_without_perf:      1}
# tools
%define with_tools     %{?_without_tools:     0} %{?!_without_tools:     1}
# bpf tool
%define with_bpftool   %{?_without_bpftool:   0} %{?!_without_bpftool:   1}
# kernel-debuginfo
%define with_debuginfo %{?_without_debuginfo: 0} %{?!_without_debuginfo: 1}
# kernel-abi-stablelists
%define with_kernel_abi_stablelists %{?_without_kernel_abi_stablelists: 0} %{?!_without_kernel_abi_stablelists: 1}
# internal samples and selftests
%define with_selftests %{?_without_selftests: 0} %{?!_without_selftests: 1}
#
# Additional options for user-friendly one-off kernel building:
#
# Only build the base kernel (--with baseonly):
%define with_baseonly  %{?_with_baseonly:     1} %{?!_with_baseonly:     0}

......


```

可以看到，对于所列出的这些build options, 可以使用 `--without <opt>` disable in rpmbuild command.  

加入`--without selftests`之后构建成功.  

### root cause

``` text

1. Linux 内核原本已经有 sched_setattr、sched_getattr 系统调用和 struct sched_attr UAPI。
2. glibc 2.41 新增了对应的 C 库函数包装和公开头文件接口。
3. glibc 优先通过 /usr/include/linux/sched/types.h 使用 Linux UAPI 的 struct sched_attr，保证数据结构布局与内核 ABI 一致；缺失时再提供兼容定义。
4. 旧项目曾自行补齐这些接口，在 glibc 2.41 环境中就会出现重复类型、函数或宏定义。
5. 正确兼容方法是通过 SCHED_ATTR_SIZE_VER0 等能力宏判断接口是否已经存在，而不是无条件重复定义，也优于只检查 glibc 版本号
```

在[glibc-2.41](https://lists.gnu.org/archive/html/info-gnu/2025-01/msg00014.html)中，有关键的一句：  
```
* On Linux, the sched_setattr and sched_getattr functions have been
  added, for supporting parameterized scheduling policies such as
  SCHED_DEADLINE.
```
同时也有[patch](https://lists.gnu.org/archive/html/qemu-devel/2024-10/msg02091.html)提到：  
```
[PATCH] sched_attr: Do not define for glibc >= 2.41
```
这是有关`rtla struct sched_attr`重定义错误可能的原因，但是container中glibc版本似乎<2.41???

排查思路：  

```sh
# 查看软件包版本

bash-5.1# rpm -q \
    --qf '%{NAME}-%{VERSION}-%{RELEASE}.%{ARCH}\n' \
    glibc glibc-headers glibc-devel kernel-headers

glibc-2.34-275.el9_8.x86_64
glibc-headers-2.34-275.el9_8.x86_64
glibc-devel-2.34-275.el9_8.x86_64
kernel-headers-5.14.0-687.38.1.el9_8.x86_64

# 上游基线：glibc 2.34
# 发行版修订：第 275 轮 EL 打包修订
# 目标基线：Enterprise Linux 9.8
# 目标架构：x86-64

# el9_8说明该软件包：

# 在 EL 9.8 对应的软件栈中构建；
# 针对 EL 9.8 的依赖版本验证；
# 使用 EL 9.8 的发行版补丁集合；
# 与 EL 9.8 的 ABI 和软件仓库关系配套；
# 作为 EL 9.8 更新内容发布。

# 2.34 是 GNU glibc 项目发布的上游版本。发行版不会简单地原样编译 glibc 2.34，而是会在其基础上加入自己的内容

# 查看运行时版本

bash-5.1# ldd --version | head -1

ldd (GNU libc) 2.34

# 查看编译期glibc版本宏

bash-5.1# printf '#include <features.h>\n' |
gcc -dM -E -x c - |
grep -E '^#define __GLIBC(_MINOR__)? '

#define __GLIBC_MINOR__ 34

# 检查/usr/include/bits/sched.h 实际内容是否包含相关宏定义,或是引用了linux的types.h

bash-5.1# grep -nE \
    'SCHED_NORMAL|SCHED_FLAG_KEEP_ALL|SCHED_FLAG_UTIL_CLAMP|SCHED_ATTR_SIZE_VER0|linux/sched/types.h' \
    /usr/include/bits/sched.h

32:# define SCHED_NORMAL                SCHED_OTHER
47:#define SCHED_FLAG_UTIL_CLAMP_MIN    0x20
48:#define SCHED_FLAG_UTIL_CLAMP_MAX    0x40
51:#define SCHED_FLAG_KEEP_ALL          0x18
52:#define SCHED_FLAG_UTIL_CLAMP                0x60
57:#  if __has_include ("linux/sched/types.h")
58:/* Some older Linux versions defined sched_param in <linux/sched/types.h>.  */
60:#   include <linux/sched/types.h>
64:# ifndef SCHED_ATTR_SIZE_VER0
66:#  define SCHED_ATTR_SIZE_VER0 48
82:# endif /* !SCHED_ATTR_SIZE_VER0 */

# 检查Linux UAPI
bash-5.1# grep -nE \
    'SCHED_ATTR_SIZE_VER[0-9]|struct sched_attr' \
    /usr/include/linux/sched/types.h

7:#define SCHED_ATTR_SIZE_VER0  48      /* sizeof first published struct */
8:#define SCHED_ATTR_SIZE_VER1  56      /* add: util_{min,max} */
98:struct sched_attr {

# 检查当前内核源码树中的定义

bash-5.1# grep -nE \
    'SCHED_NORMAL|SCHED_FLAG_KEEP_ALL|SCHED_FLAG_UTIL_CLAMP' \
    tools/include/uapi/linux/sched.h

114:#define SCHED_NORMAL                0
122:/* Can be ORed in to make sure the process is reverted back to SCHED_NORMAL on fork */
133:#define SCHED_FLAG_UTIL_CLAMP_MIN   0x20
134:#define SCHED_FLAG_UTIL_CLAMP_MAX   0x40
136:#define SCHED_FLAG_KEEP_ALL (SCHED_FLAG_KEEP_POLICY | \
139:#define SCHED_FLAG_UTIL_CLAMP       (SCHED_FLAG_UTIL_CLAMP_MIN | \
140:                             SCHED_FLAG_UTIL_CLAMP_MAX)
145:                     SCHED_FLAG_KEEP_ALL            | \
146:                     SCHED_FLAG_UTIL_CLAMP)

# 检查是否发生了发行版汇合

bash-5.1# rpm -q --changelog glibc |
grep -iE -B 3 -A 5 \
    'sched_attr|sched_setattr|sched_getattr|SCHED_FLAG' |
head -100
- Fix missing rseq acceleration for sched_getcpu (RHEL-28119)

* Wed Mar 12 2025 Florian Weimer <fweimer@redhat.com> - 2.34-176
- Add sched_setattr, sched_getattr, pthread_gettid_np (RHEL-56627, RHEL-83017)

* Mon Mar 10 2025 Tulio Magno Quites Machado Filho <tuliom@redhat.com> - 2.34-175
- Backport fwrite tests and a fix for BZ 29459 (RHEL-55471)

* Fri Mar 07 2025 Arjun Shankar <arjun@redhat.com> - 2.34-174

# 同样检查头文件包

rpm -q --changelog glibc-headers |
grep -iE -B 3 -A 5 \
    'sched_attr|sched_setattr|sched_getattr|SCHED_FLAG' |
head -100

- Fix missing rseq acceleration for sched_getcpu (RHEL-28119)

* Wed Mar 12 2025 Florian Weimer <fweimer@redhat.com> - 2.34-176
- Add sched_setattr, sched_getattr, pthread_gettid_np (RHEL-56627, RHEL-83017)

* Mon Mar 10 2025 Tulio Magno Quites Machado Filho <tuliom@redhat.com> - 2.34-175
- Backport fwrite tests and a fix for BZ 29459 (RHEL-55471)

* Fri Mar 07 2025 Arjun Shankar <arjun@redhat.com> - 2.34-174

# 用预处理器确认实际包含链

bash-5.1# cat >/tmp/check-sched.c <<'EOF'
#define _GNU_SOURCE
#include <sched.h>
EOF

# 打印真实头文件树

bash-5.1# gcc -H -E /tmp/check-sched.c \
    >/dev/null \
    2>/tmp/check-sched.includes
bash-5.1# grep -E \
    'sched\.h|sched/types\.h' \
    /tmp/check-sched.includes

. /usr/include/sched.h
.. /usr/include/bits/sched.h
... /usr/include/linux/sched/types.h

# 查看 <sched.h> 最终公开了哪些宏

bash-5.1# gcc -dM -E /tmp/check-sched.c |
grep -E \
    'SCHED_NORMAL|SCHED_FLAG_KEEP_ALL|SCHED_FLAG_UTIL_CLAMP|SCHED_ATTR_SIZE'

#define SCHED_FLAG_UTIL_CLAMP 0x60
#define SCHED_FLAG_UTIL_CLAMP_MAX 0x40
#define SCHED_NORMAL SCHED_OTHER
#define SCHED_FLAG_KEEP_ALL 0x18
#define SCHED_FLAG_UTIL_CLAMP_MIN 0x20
#define SCHED_ATTR_SIZE_VER0 48
#define SCHED_ATTR_SIZE_VER1 56

bash-5.1#
```

### 总结

有关头文件:  
```text

glibc 头文件：
/usr/include/*.h
/usr/include/bits/
/usr/include/sys/
由 glibc-headers/glibc-devel 安装
用于普通用户空间 C/POSIX 接口

系统 Linux UAPI：
/usr/include/linux/
/usr/include/asm/
/usr/include/asm-generic/
由 kernel-headers 安装
用于用户空间访问 Linux 内核 ABI

当前内核内部头文件：
include/linux/
arch/x86/include/asm/
用于内核主体和模块，不应作为普通用户空间接口

当前内核 UAPI：
include/uapi/
arch/x86/include/uapi/
由当前源码版本定义，可通过 headers_install 导出

内核 tools 头文件：
tools/include/
tools/include/uapi/
供 perf、bpftool、RTLA 和 selftests 等用户空间工具使用

selftests 头文件：
tools/testing/selftests/usr/include/
供当前 selftests 构建使用

编译选择头文件优先级：  

1. 源文件的 #include 指令决定需要寻找什么名称；
2. Makefile/Kbuild决定传给编译器哪些 -I、-isystem 和 -idirafter；
3. GCC/Clang按照其搜索规则选择第一个匹配文件；
4. glibc 头文件决定继续包含哪些 libc 或 Linux UAPI 头文件；
5. kernel-headers 包提供系统安装版 Linux UAPI；
6. 当前内核源码树提供当前版本的内部头文件和 UAPI；
7. 发行版 RPM 打包规则决定哪些版本被安装到 /usr/include。
```

#### 问题1， RTLA 的 `struct sched_attr`重定义

报错信息：  

```sh
~/workspace/rpmbuild/BUILD/kernel-5.14.0-284.187.1.el9_2/linux-5.14.0-284.187.1.el9.x86_64
+ pushd tools/tracing/rtla
~/workspace/rpmbuild/BUILD/kernel-5.14.0-284.187.1.el9_2/linux-5.14.0-284.187.1.el9.x86_64/tools/tracing/rtla ~/workspace/rpmbuild/BUILD/kernel-5.14.0-284.187.1.el9_2/linux-5.14.0-284.187.1.el9.x86_64
+ CFLAGS='-O2  -fexceptions -g -grecord-gcc-switches -pipe -Wall -Werror=format-security -Wp,-D_FORTIFY_SOURCE=2 -Wp,-D_GLIBCXX_ASSERTIONS -specs=/usr/lib/rpm/redhat/redhat-hardened-cc1 -fstack-protector-strong -specs=/usr/lib/rpm/redhat/redhat-annobin-cc1  -m64 -march=x86-64-v2 -mtune=generic -fasynchronous-unwind-tables -fstack-clash-protection -fcf-protection'
+ LDFLAGS='-Wl,-z,relro -Wl,--as-needed  -Wl,-z,now -specs=/usr/lib/rpm/redhat/redhat-hardened-ld -specs=/usr/lib/rpm/redhat/redhat-annobin-cc1 '
+ /usr/bin/make -s 'HOSTCFLAGS=-O2  -fexceptions -g -grecord-gcc-switches -pipe -Wall -Werror=format-security -Wp,-D_FORTIFY_SOURCE=2 -Wp,-D_GLIBCXX_ASSERTIONS -specs=/usr/lib/rpm/redhat/redhat-hardened-cc1 -fstack-protector-strong -specs=/usr/lib/rpm/redhat/redhat-annobin-cc1  -m64 -march=x86-64-v2 -mtune=generic -fasynchronous-unwind-tables -fstack-clash-protection -fcf-protection' 'HOSTLDFLAGS=-Wl,-z,relro -Wl,--as-needed  -Wl,-z,now -specs=/usr/lib/rpm/redhat/redhat-hardened-ld -specs=/usr/lib/rpm/redhat/redhat-annobin-cc1 ' -s
In file included from src/osnoise_hist.c:17:
src/utils.h:47:8: error: redefinition of 'struct sched_attr'
   47 | struct sched_attr {
      |        ^~~~~~~~~~
In file included from /usr/include/bits/sched.h:60,
                 from /usr/include/sched.h:43,
                 from src/osnoise_hist.c:15:
/usr/include/linux/sched/types.h:98:8: note: originally defined here
   98 | struct sched_attr {
      |        ^~~~~~~~~~
make: *** [<builtin>: src/osnoise_hist.o] Error 1
error: Bad exit status from /var/tmp/rpm-tmp.tlANQd (%build)
```

问题产生原因：  

```text
struct sched_attr 是 Linux extensible scheduling API 的 UAPI 数据结构。
旧 RTLA 为兼容早期用户空间环境，在 utils.h 中自行提供该结构体和 sched_setattr() syscall 包装；
当前 EL 9.8 的 glibc 头文件已经通过 <sched.h> 包含 Linux UAPI 的 sched/types.h，因此 RTLA 的兼容定义变成重复定义。
RTLA 上游修复也明确指出，该冲突由 glibc 对 sched_attr、sched_setattr() 和 sched_getattr() 的正式公开触发。


涉及的包含链：  

RTLA 源文件
  ├─> /usr/include/sched.h
  │     └─> /usr/include/bits/sched.h
  │           └─> /usr/include/linux/sched/types.h
  │                 └─> struct sched_attr
  │
  └─> tools/tracing/rtla/src/utils.h
        └─> struct sched_attr


其中

/usr/include/sched.h
/usr/include/bits/sched.h

由glibc-header提供


而

/usr/include/linux/sched/types.h

由kernel-header提供，是Linux内核UAPI头文件的安装副本

```

#### 问题2， BPF selftest未初始化指针

报错信息:

```sh

++ pwd
+ export BPFTOOL=/mnt/home/huangzs/workspace/rpmbuild/BUILD/kernel-5.14.0-503.40.1.el9_5/linux-5.14.0-503.40.1.el9.x86_64/tools/bpf/bpftool/bpftool
+ BPFTOOL=/mnt/home/huangzs/workspace/rpmbuild/BUILD/kernel-5.14.0-503.40.1.el9_5/linux-5.14.0-503.40.1.el9.x86_64/tools/bpf/bpftool/bpftool
+ pushd tools/testing/selftests
~/workspace/rpmbuild/BUILD/kernel-5.14.0-503.40.1.el9_5/linux-5.14.0-503.40.1.el9.x86_64/tools/testing/selftests ~/workspace/rpmbuild/BUILD/kernel-5.14.0-503.40.1.el9_5/linux-5.14.0-503.40.1.el9.x86_64
+ /usr/bin/make -s 'HOSTCFLAGS=-O2  -fexceptions -g -grecord-gcc-switches -pipe -Wall -Werror=format-security -Wp,-D_FORTIFY_SOURCE=2 -Wp,-D_GLIBCXX_ASSERTIONS -specs=/usr/lib/rpm/redhat/redhat-hardened-cc1 -fstack-protector-strong -specs=/usr/lib/rpm/redhat/redhat-annobin-cc1  -m64 -march=x86-64-v2 -mtune=generic -fasynchronous-unwind-tables -fstack-clash-protection -fcf-protection' 'HOSTLDFLAGS=-Wl,-z,relro -Wl,--as-needed  -Wl,-z,now -specs=/usr/lib/rpm/redhat/redhat-hardened-ld -specs=/usr/lib/rpm/redhat/redhat-annobin-cc1 ' -j96 ARCH=x86_64 V=1 'TARGETS=bpf cgroup mm livepatch net net/forwarding net/mptcp netfilter tc-testing memfd drivers/net/bonding iommu cachestat' SKIP_TARGETS= FORCE_TARGETS=1 INSTALL_PATH=/mnt/home/huangzs/workspace/rpmbuild/BUILDROOT/kernel-5.14.0-503.40.1.el9.x86_64/usr/libexec/kselftests VMLINUX_H= DEFAULT_INSTALL_HDR_PATH=0 install
Warning: Kernel ABI header at 'tools/include/uapi/linux/bpf.h' differs from latest version at 'include/uapi/linux/bpf.h'
Warning: Kernel ABI header at 'tools/include/uapi/linux/if_xdp.h' differs from latest version at 'include/uapi/linux/if_xdp.h'
progs/dynptr_fail.c:1391:21: error: variable 'ptr' is uninitialized when passed as a const pointer
      argument here [-Werror,-Wuninitialized-const-pointer]
 1391 |         bpf_dynptr_adjust(&ptr, 1, 2);
      |                            ^~~
progs/dynptr_fail.c:1404:22: error: variable 'ptr' is uninitialized when passed as a const pointer
      argument here [-Werror,-Wuninitialized-const-pointer]
 1404 |         bpf_dynptr_is_null(&ptr);
      |                             ^~~
progs/dynptr_fail.c:1417:24: error: variable 'ptr' is uninitialized when passed as a const pointer
      argument here [-Werror,-Wuninitialized-const-pointer]
 1417 |         bpf_dynptr_is_rdonly(&ptr);
      |                               ^~~
progs/dynptr_fail.c:1430:19: error: variable 'ptr' is uninitialized when passed as a const pointer
      argument here [-Werror,-Wuninitialized-const-pointer]
 1430 |         bpf_dynptr_size(&ptr);
      |                          ^~~
progs/dynptr_fail.c:1444:20: error: variable 'ptr1' is uninitialized when passed as a const pointer
      argument here [-Werror,-Wuninitialized-const-pointer]
 1444 |         bpf_dynptr_clone(&ptr1, &ptr2);
      |                           ^~~~
5 errors generated.
make[1]: *** [Makefile:613: /mnt/home/huangzs/workspace/rpmbuild/BUILD/kernel-5.14.0-503.40.1.el9_5/linux-5.14.0-503.40.1.el9.x86_64/tools/testing/selftests/bpf/dynptr_fail.bpf.o] Error 1
make[1]: *** Waiting for unfinished jobs....
make: *** [Makefile:157: all] Error 2
error: Bad exit status from /var/tmp/rpm-tmp.OJn5Wa (%build)

```

产生原因:  

```text

负向测试故意使用未初始化 dynptr
             ↓
Clang 21 发出新的严格诊断
             ↓
-Werror 将 warning 提升为 error
             ↓
dynptr_fail.bpf.o 无法生成
             ↓
BPF selftests 构建失败

```

#### 问题3， `BPF selftest` 的 `SCHED_*` 宏重定义

错误信息  
```sh

cd /mnt/home/huangzs/workspace/rpmbuild/BUILD/kernel-5.14.0-503.40.1.el9_5/linux-5.14.0-503.40.1.el9.x86_64/tools/testing/selftests/bpf && gcc -I. -g -O0 -rdynamic -Wall -Werror -DHAVE_GENHDR   -I/mnt/home/huangzs/workspace/rpmbuild/BUILD/kernel-5.14.0-503.40.1.el9_5/linux-5.14.0-503.40.1.el9.x86_64/tools/testing/selftests/bpf -I/mnt/home/huangzs/workspace/rpmbuild/BUILD/kernel-5.14.0-503.40.1.el9_5/linux-5.14.0-503.40.1.el9.x86_64/tools/testing/selftests/bpf/tools/include -I/mnt/home/huangzs/workspace/rpmbuild/BUILD/kernel-5.14.0-503.40.1.el9_5/linux-5.14.0-503.40.1.el9.x86_64/include/generated -I/mnt/home/huangzs/workspace/rpmbuild/BUILD/kernel-5.14.0-503.40.1.el9_5/linux-5.14.0-503.40.1.el9.x86_64/tools/lib -I/mnt/home/huangzs/workspace/rpmbuild/BUILD/kernel-5.14.0-503.40.1.el9_5/linux-5.14.0-503.40.1.el9.x86_64/tools/include -I/mnt/home/huangzs/workspace/rpmbuild/BUILD/kernel-5.14.0-503.40.1.el9_5/linux-5.14.0-503.40.1.el9.x86_64/tools/include/uapi -I/mnt/home/huangzs/workspace/rpmbuild/BUILD/kernel-5.14.0-503.40.1.el9_5/linux-5.14.0-503.40.1.el9.x86_64/tools/testing/selftests/bpf -c /mnt/home/huangzs/workspace/rpmbuild/BUILD/kernel-5.14.0-503.40.1.el9_5/linux-5.14.0-503.40.1.el9.x86_64/tools/testing/selftests/bpf/prog_tests/d_path.c -lelf  -lz -lrt -lpthread -o d_path.test.o
In file included from /mnt/home/huangzs/workspace/rpmbuild/BUILD/kernel-5.14.0-503.40.1.el9_5/linux-5.14.0-503.40.1.el9.x86_64/tools/testing/selftests/bpf/prog_tests/d_path.c:5:
/mnt/home/huangzs/workspace/rpmbuild/BUILD/kernel-5.14.0-503.40.1.el9_5/linux-5.14.0-503.40.1.el9.x86_64/tools/include/uapi/linux/sched.h:114: error: "SCHED_NORMAL" redefined [-Werror]
  114 | #define SCHED_NORMAL            0
      |
In file included from /usr/include/sched.h:43,
                 from /usr/include/pthread.h:22,
                 from ./test_progs.h:33,
                 from /mnt/home/huangzs/workspace/rpmbuild/BUILD/kernel-5.14.0-503.40.1.el9_5/linux-5.14.0-503.40.1.el9.x86_64/tools/testing/selftests/bpf/prog_tests/d_path.c:3:
/usr/include/bits/sched.h:32: note: this is the location of the previous definition
   32 | # define SCHED_NORMAL           SCHED_OTHER
      |
In file included from /mnt/home/huangzs/workspace/rpmbuild/BUILD/kernel-5.14.0-503.40.1.el9_5/linux-5.14.0-503.40.1.el9.x86_64/tools/testing/selftests/bpf/prog_tests/d_path.c:5:
/mnt/home/huangzs/workspace/rpmbuild/BUILD/kernel-5.14.0-503.40.1.el9_5/linux-5.14.0-503.40.1.el9.x86_64/tools/include/uapi/linux/sched.h:136: error: "SCHED_FLAG_KEEP_ALL" redefined [-Werror]
  136 | #define SCHED_FLAG_KEEP_ALL     (SCHED_FLAG_KEEP_POLICY | \

      |
In file included from /usr/include/sched.h:43,
                 from /usr/include/pthread.h:22,
                 from ./test_progs.h:33,
                 from /mnt/home/huangzs/workspace/rpmbuild/BUILD/kernel-5.14.0-503.40.1.el9_5/linux-5.14.0-503.40.1.el9.x86_64/tools/testing/selftests/bpf/prog_tests/d_path.c:3:
/usr/include/bits/sched.h:51: note: this is the location of the previous definition
   51 | #define SCHED_FLAG_KEEP_ALL             0x18
      |
In file included from /mnt/home/huangzs/workspace/rpmbuild/BUILD/kernel-5.14.0-503.40.1.el9_5/linux-5.14.0-503.40.1.el9.x86_64/tools/testing/selftests/bpf/prog_tests/d_path.c:5:
/mnt/home/huangzs/workspace/rpmbuild/BUILD/kernel-5.14.0-503.40.1.el9_5/linux-5.14.0-503.40.1.el9.x86_64/tools/include/uapi/linux/sched.h:139: error: "SCHED_FLAG_UTIL_CLAMP" redefined [-Werror]
  139 | #define SCHED_FLAG_UTIL_CLAMP   (SCHED_FLAG_UTIL_CLAMP_MIN | \
      |
In file included from /usr/include/sched.h:43,
                 from /usr/include/pthread.h:22,
                 from ./test_progs.h:33,
                 from /mnt/home/huangzs/workspace/rpmbuild/BUILD/kernel-5.14.0-503.40.1.el9_5/linux-5.14.0-503.40.1.el9.x86_64/tools/testing/selftests/bpf/prog_tests/d_path.c:3:
/usr/include/bits/sched.h:52: note: this is the location of the previous definition
   52 | #define SCHED_FLAG_UTIL_CLAMP           0x60
      |
cc1: all warnings being treated as errors
make: *** [Makefile:617: /mnt/home/huangzs/workspace/rpmbuild/BUILD/kernel-5.14.0-503.40.1.el9_5/linux-5.14.0-503.40.1.el9.x86_64/tools/testing/selftests/bpf/d_path.test.o] Error 1

```

产生原因：  

```text

编译 tools/testing/selftests/bpf/prog_tests/d_path.c 时出现：

"SCHED_NORMAL" redefined [-Werror]
"SCHED_FLAG_KEEP_ALL" redefined [-Werror]
"SCHED_FLAG_UTIL_CLAMP" redefined [-Werror]

原因是同一个编译单元同时包含两套调度宏定义：  

第一套来自glibc:

d_path.c
  -> test_progs.h
  -> pthread.h
  -> /usr/include/sched.h
  -> /usr/include/bits/sched.h

第二套来自正在构建的内核源码树：  

d_path.c
  -> tools/include/uapi/linux/sched.h

因此 GCC 发出宏重定义 warning，并被 -Werror 提升为 error

glibc侧：
/usr/include/sched.h
/usr/include/bits/sched.h

系统内核UAPI：
/usr/include/linux/sched/types.h

当前内核源码UAPI副本：
tools/include/uapi/linux/sched.h

需要注意，此问题不是 glibc 单独包含了源码树中的 tools/include/uapi/linux/sched.h。
实际情况是 d_path.c 的两个包含分支分别引入 glibc <sched.h> 和源码树 <linux/sched.h>，最终在同一个编译单元汇合。
```

当然，为了验证是rhel合入glibc 2.34之后的更新而导致的问题，最严谨的方法应该是检索其commit记录，找到提交点。  

## make rpm-pkg
清理objtool的宿主工具产物：  
```sh
cd /mnt/home/huangzs/workspace/linux

make -C tools/objtool clean

```
随后`make rpm-pkg -j20`
成功：  
```sh
Checking for unpackaged file(s): /usr/lib/rpm/check-files /mnt/home/huangzs/workspace/linux/rpmbuild/BUILDROOT/kernel-7.2.0_rc4_00102_g4539944e5151-7.el9.x86_64
Wrote: /mnt/home/huangzs/workspace/linux/rpmbuild/SRPMS/kernel-7.2.0_rc4_00102_g4539944e5151-7.el9.src.rpm
Wrote: /mnt/home/huangzs/workspace/linux/rpmbuild/RPMS/x86_64/kernel-headers-7.2.0_rc4_00102_g4539944e5151-7.el9.x86_64.rpm
Wrote: /mnt/home/huangzs/workspace/linux/rpmbuild/RPMS/x86_64/kernel-7.2.0_rc4_00102_g4539944e5151-7.el9.x86_64.rpm
Wrote: /mnt/home/huangzs/workspace/linux/rpmbuild/RPMS/x86_64/kernel-devel-7.2.0_rc4_00102_g4539944e5151-7.el9.x86_64.rpm
Executing(%clean): /bin/sh -e /var/tmp/rpm-tmp.alJMN9
+ umask 022
+ cd /mnt/home/huangzs/workspace/linux
+ rm -rf /mnt/home/huangzs/workspace/linux/rpmbuild/BUILDROOT/kernel-7.2.0_rc4_00102_g4539944e5151-7.el9.x86_64
+ RPM_EC=0
++ jobs -p
+ exit 0
```

### install kernel by rpms

`dnf install xx.rpm` or `rpm -ivh <--oldpackage>`

验证：  
```sh
[root@localhost rpms]# rpm -q kernel kernel-core kernel-modules-core kernel-modules
kernel-5.14.0-611.5.1.el9_7.x86_64
kernel-5.14.0-503.40.1.el9.x86_64
kernel-core-5.14.0-611.5.1.el9_7.x86_64
kernel-core-5.14.0-503.40.1.el9.x86_64
kernel-modules-core-5.14.0-611.5.1.el9_7.x86_64
kernel-modules-core-5.14.0-503.40.1.el9.x86_64
kernel-modules-5.14.0-611.5.1.el9_7.x86_64
kernel-modules-5.14.0-503.40.1.el9.x86_64
```

检查默认启动内核：  
```sh

[root@localhost rpms]# grubby --default-kernel
/boot/vmlinuz-5.14.0-503.40.1.el9.x86_64

# 查看kernel

grubby --info ALL | grep "^kernel"

# 所有信息

[root@localhost rpms]# grubby --info ALL
index=0
kernel="/boot/vmlinuz-5.14.0-611.5.1.el9_7.x86_64"
args="ro crashkernel=1G-2G:192M,2G-64G:256M,64G-:512M resume=/dev/mapper/rhel00-swap rd.lvm.lv=rhel00/root rd.lvm.lv=rhel00/swap rhgb quiet $tuned_params"
root="/dev/mapper/rhel00-root"
initrd="/boot/initramfs-5.14.0-611.5.1.el9_7.x86_64.img $tuned_initrd"
title="Red Hat Enterprise Linux (5.14.0-611.5.1.el9_7.x86_64) 9.7 (Plow)"
id="69dd623190cb45aabfed1570bd80b5eb-5.14.0-611.5.1.el9_7.x86_64"
index=1
kernel="/boot/vmlinuz-5.14.0-503.40.1.el9.x86_64"
args="ro crashkernel=1G-2G:192M,2G-64G:256M,64G-:512M resume=/dev/mapper/rhel00-swap rd.lvm.lv=rhel00/root rd.lvm.lv=rhel00/swap rhgb quiet $tuned_params"
root="/dev/mapper/rhel00-root"
initrd="/boot/initramfs-5.14.0-503.40.1.el9.x86_64.img $tuned_initrd"
title="Red Hat Enterprise Linux (5.14.0-503.40.1.el9.x86_64) 9.7 (Plow)"
id="69dd623190cb45aabfed1570bd80b5eb-5.14.0-503.40.1.el9.x86_64"
index=2
kernel="/boot/vmlinuz-0-rescue-69dd623190cb45aabfed1570bd80b5eb"
args="ro crashkernel=1G-2G:192M,2G-64G:256M,64G-:512M resume=/dev/mapper/rhel00-swap rd.lvm.lv=rhel00/root rd.lvm.lv=rhel00/swap rhgb quiet"
root="/dev/mapper/rhel00-root"
initrd="/boot/initramfs-0-rescue-69dd623190cb45aabfed1570bd80b5eb.img"
title="Red Hat Enterprise Linux (0-rescue-69dd623190cb45aabfed1570bd80b5eb) 9.7 (Plow)"
id="69dd623190cb45aabfed1570bd80b5eb-0-rescue"
```

## References

- [Docker: Publish container ports](https://iximiuz.com/en/posts/docker-publish-container-ports/)
- [docker-linux-2.6.26-build](https://github.com/bitristan/docker-linux-2.6.26-build)

## 补充：port publish 的澄清

先来读一段 docker docs 有关 port publish 的文档：

> By default, for both IPv4 and IPv6, the Docker daemon blocks access to ports that have not been published. Published container ports are mapped to host IP addresses. To do this, it uses firewall rules to perform Network Address Translation (NAT), Port Address Translation (PAT), and masquerading.
>
> For example, docker run -p 8080:80 [...] creates a mapping between port 8080 on any address on the Docker host, and the container's port 80. Outgoing connections from the container will masquerade, using the Docker host's IP address.
>
> When you create or run a container using docker create or docker run, all ports of containers on bridge networks are accessible from the Docker host and other containers connected to the same network. Ports are not accessible from outside the host or, with the default configuration, from containers in other networks.
>
> Use the --publish or -p flag to make a port available outside the host, and to containers in other bridge networks.

之前一直以为 host 无法访问 container 的网络端口，事实上通过显式指定 container ip:port 是可以访问的。
而 port publish 实际上解决的问题是"访问 container outside the host"，后续实验通过 1234:1234，将 host:1234 和 container:1234 做映射。
而后在本地 wsl（outside the host）成功访问了 container 的 qemu 服务。
这点需要澄清。
