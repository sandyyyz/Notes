# chat

## 1

Copilot said:

本次对话围绕 Linux 异构内存管理与 CXL 展开：首先明确 HMM 的初衷是消除 GPU 等设备专用分配器造成的 split address space，使普通 malloc、mmap、共享内存和文件映射能够以同一进程虚拟地址被 CPU 与设备访问，避免复杂链表、树和跨库数据因复制而需要重构指针关系；其中 mmu_notifier 负责在 CPU 页表发生解除映射、迁移、写保护等变化时失效设备页表中的旧映射，vmscan 负责系统或 memcg 内存压力下的页面扫描回收，memcg 负责按控制组进行内存记账、限制和定向回收，早期 HMM 补丁中的 “null page” 则表示数据位于无普通 struct page 的设备内存时仍需保留的无页面载体 charge，而 HMM 编码 PFN 中 VALID_PAGE 或 VALID_ZERO 表示该条目可转换为系统 struct page，两者均不存在则可能代表未映射、迁移、Swap、错误或设备私有内存等非普通系统页面状态。随后讨论了 CXL：CXL.io 负责设备枚举、配置、MMIO、DMA 和中断，CXL.cache 允许设备以 Host Physical Address 一致地访问并缓存 Host Memory，设备可借助 PASID、IOMMU、ATS 等将进程虚拟地址转换为 Host 可识别的地址，CXL.mem 则将设备内存映射到 Host 物理地址空间，使 CPU 能以普通 Load/Store 和缓存行语义访问；三者与 DMA 的根本区别是，DMA 是软件配置的显式批量数据复制，而 CXL.cache 是设备对以 Host Memory 为 Home 的缓存行按需填充，CXL.mem 是 CPU 直接访问以 Device Memory 为 Home 的内存，并由硬件维护缓存一致性。讨论中的核心疑惑集中在：设备私有地址如何被 Host 识别、CXL 内存访问为何不同于 DMA、CXL 的缓存行一致性与 HMM 的页表映射一致性有何区别，以及多个多核主机共享 Type-3 内存时如何扩展一致性；结论是 CXL 解决硬件层的物理地址路由、内存语义与 Cache Coherence，HMM 解决操作系统层的进程虚拟地址、页面驻留、迁移和生命周期，两者可组合但不能互相替代，而超大规模多主机共享必须采用主机级目录、Back-Invalidate、一致性域分区和软件同步，不能将整个集群简单视作一个无限扩展的扁平缓存一致性系统。


## 2

OverlayFS 关注“分层文件系统如何合并和写入”，composefs 关注“不可变文件系统如何确定表达、共享和验证”；composefs 建立在 OverlayFS 等现有内核机制之上，而 composefs、镜像化更新和嵌套容器等需求又正在推动 OverlayFS 引入新的层模型、安全接口和管理能力。

## 3

以下概要按“基础概念、问题现象、排查方法、解决方案、实践原则”整理，可作为本次 Linux、Yocto、RPM 内核构建与容器使用过程的简要技术记录。

Linux、Yocto、RPM 内核构建与容器实践概要

一、Linux 发行版与构建系统

Debian 和 Ubuntu 属于 DEB 软件包体系，主要使用 dpkg 和 apt。RHEL、AlmaLinux、Rocky Linux 和 Fedora 属于 RPM 软件包体系，主要使用 rpm 和 dnf。RHEL 面向企业市场，强调官方支持、认证和长期稳定性；AlmaLinux 是面向 RHEL 兼容生态的社区企业发行版；Ubuntu 更适合通用开发、桌面和云环境；Debian 强调社区维护、稳定和较少的发行版定制。

普通 Linux 内核编译主要生成内核镜像、模块和设备树，而 Yocto 是完整的嵌入式 Linux 构建框架，可以统一构建工具链、Bootloader、内核、根文件系统、软件包和最终镜像。Poky 是 Yocto Project 的参考发行版和参考构建环境，BitBake 是其任务调度和构建执行工具。

Poky 的分支名称对应不同 Yocto 发布版本。早期的 1.1_M1、1.1_M2、1.1_M3 等属于开发里程碑，不适合现代环境；dunfell、kirkstone、scarthgap 等是正式发布分支。不同分支绑定不同版本的 BitBake、Python、GCC、glibc 和构建元数据，不能随意混用。切换大版本后应重新创建 build 目录，避免旧的 bblayers.conf、local.conf 和缓存引用旧路径或旧语法。

二、Yocto 构建过程中遇到的问题

Poky clone 后只有 README

原因不是 clone 失败，而是默认 master 分支本身只包含说明文件。实际源码位于对应发布分支。远程分支在 git branch -a 中显示为 remotes/origin/xxx，但切换时应使用 origin/xxx，例如：

git switch --track origin/scarthgap

不能写成：

git switch --track remote/origin/scarthgap

Python 命令不存在

老版本 Poky 使用 Python 2，并通过 /usr/bin/env python 调用解释器。现代系统通常只安装 Python 3，因此会出现：

/usr/bin/env: 'python': No such file or directory

不应直接将 python 链接到 python3，因为老代码可能包含 Python 2 语法。更合理的方案是使用较新的 Poky 分支，或使用与历史版本匹配的旧构建环境。

Locale 缺失

BitBake 要求宿主机存在 en_US.UTF-8。Debian 或 Ubuntu 中可安装 locales 并生成该 locale：

apt install -y locales locale-gen en_US.UTF-8 update-locale LANG=en_US.UTF-8 LC_ALL=en_US.UTF-8

当前 Shell 还需设置：

export LANG=en_US.UTF-8 export LC_ALL=en_US.UTF-8

bblayers.conf 引用旧路径

Yocto 的 bblayers.conf 记录绝对路径。移动源码目录、切换容器或复用旧 build 目录后，可能仍引用旧路径，例如：

/mnt/home/huangzs/workspace/poky/meta-yocto

而当前源码实际位于：

/root/workspace/poky/meta-poky

重新执行 oe-init-build-env 不会覆盖已有配置，因此应删除或改名旧 build 目录，再重新初始化：

mv build build.old . ./oe-init-build-env build

HOSTTOOLS 缺失

BitBake 会检查宿主构建工具，例如 chrpath、diffstat、gawk 和 lz4c。Debian 或 Ubuntu 中软件包名与命令名可能不同，例如 lz4c 通常由 lz4 软件包提供。解决方法是安装对应宿主依赖，并通过 command -v 验证命令是否存在。

三、容器文件系统与用户管理

容器由只读 image 层和容器可写层组成。在容器中执行 apt install、dnf install、locale-gen 等操作，只修改当前容器的可写层，不会自动修改原始 image，也通常不会影响宿主机。

停止和重新启动同一个容器时，修改会保留；删除容器并重新创建时，未挂载的数据会丢失。挂载到宿主机或 Docker volume 的目录具有独立生命周期，删除容器后通常仍然存在。需要长期复现的依赖应写入 Dockerfile，而不是依赖手工安装或 docker commit。

使用 docker run -u username 时，镜像内部必须存在该用户，否则会报：

unable to find user username: no matching entries in passwd file

通用容器脚本应使用宿主用户的数字 UID/GID：

--user "$(id -u):$(id -g)"

这样挂载目录中的文件所有权与宿主用户一致。容器内可能显示 I have no name，因为 /etc/passwd 中没有对应 UID，但通常不影响文件权限和编译。若要求容器内具有完整用户名，应通过 Dockerfile 创建相同 UID/GID 的用户。

容器名称应使用 docker inspect 精确判断，不应通过 docker ps | grep 模糊匹配。容器状态可分为 running、exited 和 created，分别使用 docker exec、docker start -ai 或删除后重建。

四、RPM、DEB、ISO 和 SRPM

RPM 和 DEB 是软件包格式。RPM 主要用于 RHEL 系发行版，DEB 主要用于 Debian 系发行版。ISO 是完整光盘或安装介质镜像，可能包含引导程序、内核、initramfs、安装程序和大量 RPM 或 DEB 软件包。

普通二进制 RPM 包含已经编译的程序、库、配置文件和安装脚本，可以通过 dnf install 安装。SRC RPM 包含上游源码、补丁、配置和 Spec 文件，用于重新构建一个或多个二进制 RPM，不能直接作为可启动内核使用。

安装 SRC RPM：

rpm -ivh kernel-xxx.src.rpm

主要作用是将文件放入 rpmbuild 目录：

BUILD BUILDROOT RPMS SOURCES SPECS SRPMS

其中 SOURCES 保存源码压缩包、补丁和配置；SPECS 保存构建规则；BUILD 是临时源码和编译目录；BUILDROOT 是临时安装根；RPMS 和 SRPMS 是最终产物目录。

五、rpmbuild 构建阶段

命令：

rpmbuild -ba SPECS/kernel.spec

表示根据 kernel.spec 执行完整构建，生成二进制 RPM 和源码 RPM。

常用参数含义：

-bp：执行 %prep，解压源码并应用补丁。 -bc：执行到 %build，完成编译。 -bi：执行到 %install，安装到 BUILDROOT。 -bb：生成二进制 RPM。 -ba：生成二进制 RPM 和源码 RPM。

仅执行：

rpmbuild SPECS/kernel.spec

通常只解析 Spec，没有指定构建阶段，因此不会真正编译。

构建依赖应通过以下方式自动安装：

dnf builddep -y --spec SPECS/kernel.spec

AlmaLinux 需要启用 BaseOS、AppStream 和 CRB。部分 RHEL 内核 SRPM包含 Red Hat 特定或云平台变体依赖，例如 WALinuxAgent-cvm、kabi-dw 和特定 systemd 富依赖，AlmaLinux 公共仓库不一定能够完整满足。此时需要检查 Spec 中的条件宏，按目标关闭不需要的构建变体，或者使用与原始 RHEL 构建环境一致的软件仓库。

六、DNF 网络代理

DNF 的命令行代理仅对当前命令生效：

dnf --setopt=proxy=http://10.99.93.35:8080 makecache

下一条 dnf install 不会自动继承该参数。长期使用应在 /etc/dnf/dnf.conf 的 [main] 段配置：

proxy=http://10.99.93.35:8080 timeout=30 retries=3

也可以通过当前 Shell 环境变量配置：

export http_proxy=http://10.99.93.35:8080 export https_proxy=http://10.99.93.35:8080

代理排查顺序应为：

检查环境变量和 DNF 配置。
测试代理 TCP 端口是否可达。
使用 curl 通过代理访问仓库。
使用 dnf makecache 验证元数据下载。
使用 dnf download 或 dnf install 验证实际 RPM 下载。

执行 su - 会创建 root 登录环境，原用户的代理环境变量可能丢失，因此 root Shell 需要重新配置代理。

七、RTLA 编译冲突问题

构建 RHEL 9 内核 SRPM时，RTLA 编译出现：

redefinition of 'struct sched_attr'

错误链为：

src/osnoise_hist.c 包含 /usr/include/sched.h； sched.h 间接包含 /usr/include/linux/sched/types.h； 系统头文件已经定义 struct sched_attr； RTLA 的 src/utils.h 又定义了同名结构体； 编译器检测到重复完整定义并终止； src/osnoise_hist.o 生成失败； make 返回 Error 1； rpmbuild 报 %build 阶段 Bad exit status。

根因不是 RHEL 9.5 内核才新增了 sched/types.h，而是 Linux UAPI 中长期存在 sched_attr。旧 RTLA 为兼容旧用户空间，自行定义了 struct sched_attr 和 sched_setattr syscall 包装。后来 glibc 正式暴露 sched_attr、sched_setattr 和 sched_getattr 接口，旧 RTLA 的兼容代码与新版 glibc 发生冲突。

上游修复包含两部分：

仅在系统未提供 SCHED_ATTR_SIZE_VER0 时定义本地 struct sched_attr。
将 RTLA 自己的 sched_setattr 包装函数重命名为 syscall_sched_setattr，避免与 glibc 函数同名。

修复后的结构体形式为：

#ifndef SCHED_ATTR_SIZE_VER0 struct sched_attr { ... }; #endif

同时将本地函数和调用改为 syscall_sched_setattr。

八、编译日志的阅读方法

处理 GCC、Make 和 rpmbuild 混合日志时，应从上到下找到第一条具体 error，而不是只看最后的 Error 1 或 Bad exit status。

标准 GCC 错误格式：

文件:行:列: error: 错误内容

例如：

src/utils.h:49:8: error: redefinition of 'struct sched_attr'

紧随其后的 note 通常说明第一次定义、之前声明或候选函数的位置。本例中的：

/usr/include/linux/sched/types.h:98:8: note: originally defined here

直接指出冲突的另一个定义。

In file included from 需要从下向上阅读，以还原头文件包含链。make: Error 1 和 rpmbuild 的 Bad exit status 只是底层编译错误向上层传播后的汇总，不是根本原因。

九、上游邮件补丁的获取与应用

LKML HTML 页面只是邮件展示页，不应直接作为 patch 下载。应优先通过 lore.kernel.org 的 raw 地址、b4 或最终上游 commit 获取原始邮件和补丁。

b4 可以根据 Message-ID 下载完整补丁系列：

b4 am ''

对于包含 15 个补丁的 mbox，可使用 git mailsplit 拆分：

git mailsplit -o/tmp/rtla-mails series.mbx

通过 Subject 查找目标邮件，不应只凭序号判断：

grep -l 'tools/rtla: fix collision' /tmp/rtla-mails/*

从原始邮件提取纯 patch：

git mailinfo /tmp/message.txt /tmp/rtla.patch < /tmp/rtla-mails/0004

然后在源码根目录检查和应用：

git apply --check /tmp/rtla.patch git apply /tmp/rtla.patch

git am 用于保留作者、提交说明和 Signed-off-by 并创建 commit；git apply 只应用文件差异，更适合非 Git 的 RPM BUILD 临时源码树。

普通 patch 应用失败不一定生成冲突标记。只有 git am -3 成功找到补丁的基线 blob 并进入三方合并后，才可能产生 <<<<<<<、=======、>>>>>>> 标记。SRPM 解压目录通常没有完整上游 Git 历史，因此无法进行三方合并时，需要人工 backport。

十、补丁不能直接应用时的处理

git apply --verbose 会显示正在搜索的上下文。如果出现：

error: while searching for: ... patch does not apply

说明当前源码与补丁基线存在实质差异，不是空格问题。应执行：

查看补丁中的目标代码。
查看当前源码中对应函数和结构体。
判断补丁是否已经部分应用。
使用 git apply --reject 保存无法应用的 hunk。
根据上游补丁语义手工移植到当前代码。
利用修改前和修改后的文件生成适配当前 RHEL 源码的 backport patch。
在干净源码树中重新执行 dry-run 验证。

判断补丁状态可使用：

git apply --check patch git apply --reverse --check patch

正向成功表示尚未应用且可以应用；反向成功表示补丁已应用；两者都失败表示源码基线不同或只应用了一部分。

本次 grep 结果只显示 utils.c 中存在 syscall_sched_setattr，但没有显示 utils.h 中的 SCHED_ATTR_SIZE_VER0，说明补丁只应用了一部分。函数重命名已经生效，但结构体条件保护没有生效，因此 struct sched_attr 重定义错误仍然存在。

十一、补丁必须纳入 RPM 构建流程

BUILD 是临时目录，rpmbuild -ba 会重新执行 %prep，并删除旧的 BUILD/kernel-* 目录。因此直接修改 BUILD 只能用于临时验证。

正式流程应为：

将补丁保存到 SOURCES。
在 kernel.spec 中添加 Patch 声明。
在 %prep 阶段、源码解压完成且当前目录为 Linux 源码根目录时应用补丁。
先运行 rpmbuild -bp 验证补丁自动应用。
检查重新生成的源码中是否同时存在 SCHED_ATTR_SIZE_VER0 和 syscall_sched_setattr。
单独编译 RTLA。
最后执行 rpmbuild -ba。

Spec 中可能采用：

patch_command='git apply'

因此应沿用原有机制，在正确目录执行对应 Patch。不能依赖 BUILD 中的手动修改，也不能只在 Spec 中声明 Patch 而不实际应用，除非该 Spec 使用 %autosetup 或 %autopatch。

十二、RTLA 单独编译验证

应用补丁后无需立即重新编译整个内核，可以只构建失败组件：

make -C tools/tracing/rtla clean make -C tools/tracing/rtla V=1

保留日志时应使用 pipefail：

set -o pipefail make -C tools/tracing/rtla V=1 2>&1 | tee /tmp/rtla-build.log

验证条件为：

make 返回 0。
日志中不再出现 sched_attr 重定义。
生成 RTLA ELF 可执行文件。
ldd 不显示缺失动态库。
rtla --help 能正常启动。

容器中实际运行 RTLA tracing 功能还依赖宿主机内核、tracefs 挂载和容器权限。运行失败不一定代表编译失败，需要区分编译验证和运行时功能验证。

十三、内核安装方法与安全原则

内核可以通过以下方式安装：

DNF 安装发行版仓库中的 kernel RPM。
DNF 安装本地构建的二进制内核 RPM。
APT 安装 Debian 或 Ubuntu 的内核 DEB。
从源码 make modules_install 和 make install。
手工复制 vmlinuz、模块、initramfs 和启动配置。
通过 ISO、PXE 或安装程序安装完整系统。

对自定义 RHEL 内核，推荐先构建 RPM，再在测试虚拟机中使用 dnf install 并行安装。不要使用 rpm --force、--nodeps 或模糊的 kernel* 删除命令。

安装前应检查：

系统 EL 大版本和架构； RPM 元数据、文件和脚本； RPM 签名或 SHA-256； /boot 剩余空间； Secure Boot 状态； 旧内核是否仍可启动； DNF --assumeno 的事务计划； 是否具有控制台或带外回退能力。

安装后应检查：

/boot/vmlinuz-； /boot/initramfs-； /lib/modules/； grubby --info=ALL； BLS 启动项； 默认启动内核。

首次测试应保留旧内核，优先从 GRUB 手工选择新内核。容器共享宿主机内核，在容器内安装内核 RPM不会让容器运行新内核。

十四、WSL、SSH 和文件传输

MobaXterm 拖拽文件通常通过 SFTP实现。SSH、SFTP、SCP 和 rsync over SSH 可以共用远程 sshd 的 TCP 22 端口。

Windows 或 WSL 与远程服务器互传文件时，推荐由本地主动连接远程：

scp local-file user@server:/remote/path/ scp user@server:/remote/file local-path/ rsync -avh --progress local-dir/ user@server:/remote-dir/

WSL2 默认使用 NAT，局域网其他设备通常不能直接访问 WSL 的 172.x 地址。外部访问 WSL SSH 时，需要在 Windows 将某个端口通过 portproxy 转发到 WSL 的 22 端口，并配置 Windows 防火墙。WSL 地址可能在重启后变化，因此转发规则需要动态更新。

十五、tmux 和 Vim 使用

tmux 用于在远程会话中复用多个 Shell。常用命令：

tmux new -s session tmux ls tmux attach -t session tmux kill-session -t session tmux kill-server

Ctrl+b d 用于分离并保留任务；exit 或 kill-session 会关闭会话及其进程。

tmux 可配置 Vim 风格面板切换：

Ctrl+h：左 Ctrl+j：下 Ctrl+k：上 Ctrl+l：右

需要注意 Ctrl+l 原本是 Shell 清屏快捷键，配置后会被 tmux 截获。

tmux 和 Vim 启用鼠标后，普通拖动会被程序捕获。若需要复制到 Windows 系统剪贴板，可按住 Shift 后使用鼠标拖动，再使用 Ctrl+Shift+C；粘贴使用 Ctrl+Shift+V 或 Shift+Insert。远程服务器通常不能直接访问 Windows 剪贴板，因此由最外层终端完成复制最可靠。

Vim 中完整匹配单词：

/<kernel>

区分大小写：

/\C<kernel>

完整匹配整行：

/^kernel$/

跳转到某行应使用：

vim +233 file

不能写成：

vim file 233

后者会把 233 当作第二个文件名。

十六、总体排查思路

本次问题处理体现了以下通用方法：

区分表面错误和根因。Error 1、Bad exit status 和依赖失败通常只是上层汇总。
从第一条具体 error 开始，读取文件、行号、列号和 note。
根据 include 链、调用链和工具目录确定失败组件及编译环境。
区分直接证据和推断，用 grep、预处理输出、版本查询和单组件构建验证推断。
区分临时验证和正式修复。BUILD 中的修改适合试验，SOURCES 和 Spec 才能实现可重复构建。
使用上游最终 commit、b4 和 lore raw 邮件，不从 HTML 手工复制补丁。
补丁无法直接应用时，根据语义做 backport，并在干净源码基线上重新验证。
将大构建拆成 %prep、单组件编译和完整打包三个阶段，缩短反馈周期。
所有最终修改都应能通过从干净源码重新执行 rpmbuild 复现。
对自定义内核始终保留旧内核和可恢复启动路径，先在虚拟机验证，再考虑部署到实际系统。

文档整理说明

本概要将对话中的零散命令和故障现象按环境、构建阶段和问题类型重新组织，重点突出可重复构建、证据驱动排查、补丁 backport 和安全回退四条主线。

## 4

RHEL/AlmaLinux 内核构建问题技术概览
一、背景与核心疑问

本次工作围绕 RHEL 9 内核 SRPM 的提取、修改、重新构建及安装验证展开，主要疑问包括：

如何下载、传输并验证内核源码 RPM。
rpm -ivh、rpmbuild、make rpm-pkg 分别适用于什么场景。
为什么 RHEL 9.5 内核源码在 AlmaLinux 容器中反复出现 tools 编译错误。
glibc、kernel-headers、当前内核源码树头文件如何共同参与用户空间工具编译。
如何定位并应用上游补丁，以及如何避免每次重新完整构建。
如何在调试阶段排除不必要的 tools/ 和 kselftests 目标。
如何安全安装和验证自行构建的内核 RPM。
二、环境与版本判断

当前构建环境中确认的软件包包括：

glibc-2.34-275.el9_8.x86_64
glibc-headers-2.34-275.el9_8.x86_64
glibc-devel-2.34-275.el9_8.x86_64
kernel-headers-5.14.0-687.38.1.el9_8.x86_64
clang-21.1.8


正在构建的内核源码为：

kernel-5.14.0-503.40.1.el9_5


因此更准确的环境描述是：

使用包含 EL 9.8 基线 glibc-headers、kernel-headers 和 Clang 21 的构建环境，编译 EL 9.5 内核源码及其用户空间工具。

el9_8 是 RPM Release 字段中的发行版构建基线标识，表示该软件包面向 Enterprise Linux 9.8 软件栈维护和发布。它不能单独证明容器本身一定是 AlmaLinux 9.8，系统身份仍应通过 /etc/os-release 和发行版 release 包确认。

三、头文件体系
1. glibc 用户空间头文件

主要目录：

/usr/include/
/usr/include/bits/
/usr/include/sys/


典型文件：

/usr/include/sched.h
/usr/include/pthread.h
/usr/include/bits/sched.h
/usr/include/sys/types.h


通常由以下软件包安装：

glibc-headers
glibc-devel

2. 系统安装的 Linux UAPI 头文件

主要目录：

/usr/include/linux/
/usr/include/asm/
/usr/include/asm-generic/


对应内核源码中的：

include/uapi/
arch/<arch>/include/uapi/


典型文件：

/usr/include/linux/sched.h
/usr/include/linux/sched/types.h
/usr/include/linux/bpf.h


通常由 kernel-headers 安装。

3. 当前内核源码树头文件
include/linux/                  内核内部头文件
include/uapi/                   当前内核 UAPI
arch/x86/include/              x86 内核头文件
arch/x86/include/uapi/         x86 UAPI
include/generated/             构建生成头文件
tools/include/                 tools 专用头文件
tools/include/uapi/            tools 使用的 UAPI 副本
tools/testing/selftests/usr/include/
                               selftests 导出的 UAPI


内核主体通常使用源码树内部头文件，而 tools/ 下的用户空间程序会同时使用宿主 glibc、系统 UAPI 和源码树 UAPI，因此更容易发生版本冲突。

四、三个主要编译问题
4.1 RTLA 的 struct sched_attr 重定义
现象
src/utils.h: error: redefinition of 'struct sched_attr'
/usr/include/linux/sched/types.h: note: originally defined here

根因

第一份定义来自：

RTLA
  -> <sched.h>
  -> /usr/include/sched.h
  -> /usr/include/bits/sched.h
  -> /usr/include/linux/sched/types.h
  -> struct sched_attr


第二份定义来自：

tools/tracing/rtla/src/utils.h


旧 RTLA 为兼容早期用户空间环境，自行定义了 struct sched_attr 和 sched_setattr() syscall 包装。当前 EL 9.8 glibc 头文件已经通过 <sched.h> 暴露 Linux UAPI 中的 struct sched_attr，因此形成重复定义。

解决思路

应用上游兼容修复：

#ifndef SCHED_ATTR_SIZE_VER0
struct sched_attr {
        ...
};
#endif


同时将 RTLA 内部函数：

sched_setattr()


重命名为：

syscall_sched_setattr()


该问题属于硬错误，即使没有 -Werror 也会失败。

4.2 BPF dynptr 未初始化问题
现象

Clang 21 编译 dynptr_fail.c 时出现：

-Wuninitialized-const-pointer
-Wdefault-const-init-var-unsafe


由于编译参数包含：

-Werror


警告被提升为错误。

根因

dynptr_fail.c 是 BPF verifier 负向测试，部分 struct bpf_dynptr 变量被故意保持未初始化，用于验证 verifier 是否正确拒绝非法操作。

Clang 21 新增或强化了相关诊断，导致测试程序尚未生成 BPF 对象就被编译器拒绝。

解决思路

不应直接修改为：

struct bpf_dynptr ptr = {};


因为这可能改变测试语义。

调试阶段可在 BPF selftests 编译参数中加入：

-Wno-error=uninitialized-const-pointer
-Wno-error=default-const-init-var-unsafe


这样保留 warning，但允许生成 BPF 对象并继续由 verifier 验证。

4.3 SCHED_* 宏重定义
现象
"SCHED_NORMAL" redefined [-Werror]
"SCHED_FLAG_KEEP_ALL" redefined [-Werror]
"SCHED_FLAG_UTIL_CLAMP" redefined [-Werror]

根因

同一编译单元同时包含两套定义。

glibc 侧：

d_path.c
  -> test_progs.h
  -> pthread.h
  -> /usr/include/sched.h
  -> /usr/include/bits/sched.h


源码树侧：

d_path.c
  -> tools/include/uapi/linux/sched.h


双方定义的数值可能相同，但宏替换文本不同，例如：

#define SCHED_NORMAL SCHED_OTHER


与：

#define SCHED_NORMAL 0


预处理器仍将其识别为不同定义。该问题本来是 warning，由 -Werror 提升为构建错误。

解决思路

优先寻找相应上游兼容补丁。临时调试可：

在包含 Linux UAPI 前有条件 #undef 冲突宏。
暂时从 kselftest TARGETS 中移除 bpf。
避免全局删除 -Werror，防止掩盖其他真实问题。
五、GCC、Clang、glibc 与 -Werror
GCC 和 Clang

GCC、Clang 是编译器，负责预处理、语法语义分析、诊断和代码生成。一次内核构建可能同时使用两者：

内核主体                 GCC
宿主用户空间工具         GCC
BPF 用户空间 test runner GCC
BPF 程序                 Clang --target=bpf

glibc

glibc 是用户空间 C 库，包含：

编译期头文件
运行期动态库
动态加载器


GCC 和 Clang通常共享同一套系统 glibc 头文件与运行库。

-Werror

-Werror 是传给当前 GCC 或 Clang 的诊断选项，含义是：

将当前编译器产生的 warning 视为 error。

它不产生冲突，只会将部分原本可继续构建的警告升级为致命错误。

RTLA struct 重定义：
硬错误，不依赖 -Werror。

BPF dynptr 警告：
由 Clang 21 产生，受 -Werror 放大。

SCHED 宏重定义：
由 GCC 产生 warning，受 -Werror 放大。

六、排查方法

统一排查步骤如下：

从日志中找到第一条具体 error:，不要只看 make Error 1 或 %build Bad exit status。
根据 file:line:column 定位源码。
阅读紧随其后的 note: originally defined here。
使用 V=1 获取完整编译命令。
使用预处理器还原包含链：
gcc -H -E source.c
clang -H -E source.c

检查最终宏集合：
gcc -dM -E source.c

比较系统头文件和源码树头文件：
grep
diff -u

检查系统文件所属 RPM：
rpm -qf /usr/include/sched.h
rpm -qf /usr/include/linux/sched/types.h

单独构建失败组件，不立即重跑完整 rpmbuild -ba。
修复稳定后再生成 patch，纳入 SOURCES 和 Spec。
七、RPM 构建与增量调试

BUILD/ 是临时目录，rpmbuild -ba 会重新执行 %prep，删除并重建源码树。因此直接修改 BUILD 只适合临时验证。

推荐流程：

第一次：
rpmbuild -bp
生成完整 BUILD 源码树

调试阶段：
直接修改 BUILD
单独 make 失败组件

较完整验证：
rpmbuild --short-circuit -bc

稳定后：
生成 patch
放入 SOURCES
由 kernel.spec 的 %prep 自动应用

最终：
执行一次干净 rpmbuild -ba


对于 BPF selftests，可单独运行：

make -C tools/testing/selftests/bpf V=1


对于 RTLA：

make -C tools/tracing/rtla clean
make -C tools/tracing/rtla V=1

八、选择性跳过 tools/selftests

如果目标只是验证内核镜像、模块和基础 RPM，可暂时从 Spec 的 selftest 目标中移除：

bpf


例如将：

TARGETS="bpf cgroup mm livepatch ..."


改为：

TARGETS="cgroup mm livepatch ..."


若 Spec 已提供可覆盖宏或 bcond，可通过：

--define "selftest_targets ..."
--without selftests
--without bpf_selftests


控制。若 TARGETS 和 SKIP_TARGETS 在 Spec 中硬编码，外层环境变量通常无法覆盖，需要先将其参数化。

跳过这些目标只能证明内核主体可构建，不能代表完整 RHEL 内核 SRPM 已按原设计重建。

九、上游与 RHEL 提交追踪

查找上游 glibc 或 Linux 内核中某个宏的引入记录：

git log -S'SCHED_FLAG_KEEP_ALL' -p -- <file>
git log -S'SCHED_FLAG_UTIL_CLAMP' -p -- <file>
git log -G'SCHED_FLAG_' -p -- <file>
git blame <file>


其中：

git log -S    查找字符串出现次数发生变化的提交
git log -G    查找补丁中匹配正则的提交
git blame     查找当前行最后由哪个提交修改


追踪 RHEL/AlmaLinux 下游记录，应获取与二进制包精确对应的 SRPM：

glibc-2.34-275.el9_8.src.rpm


然后检查：

glibc.spec
发行版 patch 文件
RPM changelog
CentOS Stream dist-git/source-git 历史


不能只根据上游 glibc 版本判断实际接口，因为 EL 发行版会在稳定基线版本上持续回合补丁。

十、总体结论

本次问题不是单一源码缺陷，而是以下组合造成的源码级兼容性问题：

EL 9.5 内核源码中的 tools/selftests
+
EL 9.8 基线的 glibc-headers 和 kernel-headers
+
Clang 21 新诊断
+
严格的 -Werror
=
连续出现结构体、宏和诊断兼容问题


处理原则是：

区分硬错误与 -Werror 放大的 warning。
以实际头文件内容和 include 链为准，不仅看软件主版本。
调试阶段局部编译并保留 BUILD。
稳定后通过 patch 和 Spec实现可重复构建。
准确重建 RHEL 内核时，优先使用与目标 SRPM 小版本匹配的仓库、头文件和工具链环境。
