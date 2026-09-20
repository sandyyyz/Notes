# LWN 每周热点议题技术摘要

> **观察周期：** 2026-09-10 至 2026-09-17  
> **整理时间：** 2026-09-18  
> **范围说明：** 以 LWN 首页、2026-09-17 Weekly Edition 及随后发布的重要条目为主，优先选取 Linux 内核、系统安全、运行时与基础设施方向。部分 LWN 深度文章可能需要订阅后阅读全文。

## 1. io_uring 线程身份切换：以激进方案解决异步阻塞保证

io_uring 子系统的设计核心是不阻塞应用线程——除非应用显式要求阻塞。然而维持这一"永不阻塞"保证一直颇具挑战，因为内核中大量代码路径并非为异步执行而设计。以往的工作围绕这一问题做了诸多变通，但代价是可观的性能损耗。io_uring 维护者 Jens Axboe 于 9 月 11 日提交了一组 RFC 补丁，提出通过线程身份切换（thread-identity switcheroo）的机制来解决该问题：在需要执行阻塞路径时，将请求从发起应用线程转移至内部工作线程处理，从而保持应用侧的非阻塞语义。

**原文：** [Thread-identity switcheroo for io_uring](https://lwn.net/Articles/1094303/) · [RFC 补丁集](https://lwn.net/ml/all/20260911154148.644489-1-axboe@kernel.dk)

该方案的核心风险在于线程身份切换带来的状态一致性问题。io_uring 请求可能依赖当前线程的用户态地址空间、信号上下文、文件描述符表等，若由工作线程代为执行，需要确保这些上下文在切换后仍然有效且不被中间信号或调度事件破坏。此外，该机制可能引入新的并发路径，需要严格审计引用计数、内存屏障和错误传播逻辑。如果最终被接受，它将显著减少 io_uring 为规避阻塞而引入的性能惩罚路径，是 io_uring 走向更完整异步能力的关键一步。

**关注意义：** 对依赖 io_uring 的高性能存储服务、数据库和反向代理而言，该方案可能直接影响 I/O 延迟和吞吐。关注补丁在 -next 中的迭代进度，特别是工作线程生命周期管理、用户态内存访问安全和信号处理策略三个方向。

**参考：** [LWN io_uring coverage](https://lwn.net/Kernel/Index/#io_uring) · [io_uring(7) man page](https://man7.org/linux/man-pages/man7/io_uring.7.html)

## 2. BPF 驱动 blk-iocost：为固态 I/O 调度注入可编程成本模型

块 I/O 调度在旋转磁盘时代以请求排序为核心，而在 SSD 时代，调度器的主要职责是在高速设备（每秒可执行数百万 I/O 操作）上维持竞争用户间的公平性。blk-iocost I/O 控制器面向固态世界设计，通过为不同类 cgroup 分配"成本"来控制 I/O 速率，整体表现良好。Tao Cui 提交的补丁集旨在将 BPF 程序引入 blk-iocost 的成本决策环节，使其能够加载自定义 BPF 逻辑来计算每次 I/O 操作的代价，从而获得更灵活、更贴近实际硬件行为的调度策略。

**原文：** [Adding BPF to blk-iocost](https://lwn.net/Articles/1093661/) · [补丁集](https://lwn.net/ml/all/20260914073356.791518-1-cui.tao@linux.dev)

从架构角度看，该方案将 blk-iocost 从静态成本模型升级为可编程成本引擎。BPF 程序可以在内核态直接读取设备统计、队列深度、请求类型和时序信息，从而计算出比固定权重更精细的成本值。例如，针对 QLC NAND 的写放大特性，BPF 程序可以在大写入集中动态提高成本，使 blk-iocost 自然限制写入速率；或者根据设备温度、寿命指标调整成本以保护硬件。需要关注的是 BPF 程序的成本计算路径不能引入过高开销——每次 I/O 都需调用 BPF，若程序本身复杂度过高，反而会成为调度瓶颈。

**关注意义：** 对多租户存储、容器化平台和高性能数据库而言，可定制的 I/O 成本模型意味着更精确的公平性控制和 QoS 保障。建议在测试环境中使用 `bpftrace` 或 `bpftrace` 的 `kprobe` 验证 BPF 成本函数的执行延迟，确保其对调度路径的影响可控。

**参考：** [blk-iocost kernel documentation](https://docs.kernel.org/admin-guide/cgroup-v1/blkiocost.html) · [BPF documentation](https://docs.kernel.org/bpf/index.html)

## 3. 内核编译加速：LLM 辅助下的构建系统优化

内核构建是一个耗时过程，其构建系统复杂度极高——据 LWN 估计，真正理解整个构建系统全貌的开发者寥寥无几。Lorenzo Stoakes 在 LLM 辅助下对内核构建流程进行了系统性优化，取得了显著的速度提升。具体优化方向涉及减少冗余编译、改进并行度以及消除构建图中的不必要的依赖检查。

**原文：** [Accelerating the kernel's build process](https://lwn.net/Articles/1093398/)

这一工作的意义超越单纯的性能提升。内核构建系统是数十年积累的结果，涉及 Kconfig、Makefile、脚本和架构特定规则的复杂交织。能够在不破坏现有功能的前提下取得可测量的加速，说明当前构建系统中仍存在大量可消除的冗余。同时，这项工作展示了 LLM 在理解和优化复杂构建系统方面的实际价值——Stoakes 利用 LLM 辅助追踪构建依赖链、识别低效模式，这是纯人工审查难以在合理时间内完成的工作。

**关注意义：** 对内核开发者和发行版维护者而言，更快的编译意味着更短的开发-测试循环。但需注意，构建优化可能改变编译顺序或并行行为，从而暴露之前被掩盖的竞态条件或依赖问题，建议在采用后扩大跨架构测试覆盖。

**参考：** [LWN 深度文章](https://lwn.net/Articles/1093398/) · [Kernel kbuild documentation](https://docs.kernel.org/kbuild/kbuild.html)

## 4. PostgreSQL 19 "恐怖补丁竞赛"：发布质量争议

PostgreSQL 19 原计划于 9 月发布，延续该项目每年一次大版本的传统。但 8 月 25 日，核心贡献者 Robert Haas 发出一封题为"scary patch contest"的邮件，指出多个即将合入的功能补丁在发布前经历了异常大量的缺陷修复，引发社区对发布质量的担忧。其中一个补丁已被回退，多个仍在密集修订中，为此项目额外安排了一个 beta 版本以留出更多测试时间。

**原文：** [PostgreSQL 19's "scary patch contest"](https://lwn.net/Articles/1092003/) · [Robert Haas 原始邮件](https://lwn.net/ml/all/CA+Tgmob9NY6m0YNFTQ4nFH2d0iC9SQRruDYxfndGKKzh8OC80w@mail.gmail.com/)

这反映了大型数据库项目在功能速度和质量控制之间的经典张力。PostgreSQL 的发布周期固定，功能冻结后仍有大量修订空间，但补丁数量增长意味着回归测试压力上升。Tomas Vondra 近期分析显示，PostgreSQL 当前每周约 50 个提交，较 2010 年的 25 个增长约两倍，活跃提交者数量也同步翻倍。更高的开发密度需要更严格的发布门禁。

**关注意义：** 对生产环境用户而言，PostgreSQL 19 的功能集和稳定性状态值得持续关注。建议在额外 beta 版本发布后再做升级评估，重点关注被标记为"scary"的补丁是否已充分测试，以及回退功能对已有依赖的影响。

**参考：** [PostgreSQL 19 release notes](https://www.postgresql.org/docs/release/19.0/) · [PostgreSQL 开发活动分析](https://vondra.me/posts/postgres-development-activity/)

## 5. Rust never 类型稳定化：10 年悬而未决的类型系统改进

Rust 的 never 类型（用 `!` 表示）标记永不返回的函数和不可能出现的值位置。长期以来该类型仅用于编译器内部，被视为不稳定特性。8 月 24 日，经过超过两年的工作，Rust 编译器贡献者"waffle"成功稳定了该类型，将从 Rust 1.100 开始生效。

**原文：** [Stabilizing Rust's never type](https://lwn.net/Articles/1091015/) · [合并 PR](https://github.com/rust-lang/rust/pull/155499)

阻碍稳定化的核心难题是"never fallback"行为。由于 `!` 可隐式转换为任意类型，编译器在类型推断无法确定具体类型时会回退到一个默认类型。在 Rust 2024 edition 之前，该回退类型为 `()`（单元类型），之后改为 `!` 本身。这一变更在技术上是破坏性变更——某些依赖旧推断行为的代码会编译失败。社区使用 `crater` 工具对 crates.io 全部公开库进行编译扫描，发现 3,300 个 crate 受到负面影响，其中 7 个完全损坏。通过推动核心库回发补丁版本，已解决其中 1,553 个 crate 的依赖问题。

这一变更的实践价值在于：标准库中的 `Infallible` 类型将成为 `!` 的类型别名，使此前使用 `Infallible` 的代码自动获得编译器优化——编译器可以消除永不出现的错误分支相关代码。例如，`Result<Self, !>` 的 `Err` 分支可以被完全优化掉，这在泛型代码中尤为关键。

**关注意义：** 大多数 Rust 用户不会直接感知这一变化，但使用泛型函数且依赖类型推断省略的场景可能需要显式添加类型注解。建议运行 `cargo build` 检查是否有新增推断失败，并通过添加 `::<T>()` 语法或显式变量声明修复。

**参考：** [Rust never type documentation](https://doc.rust-lang.org/stable/std/primitive.never.html) · [Infallible](https://doc.rust-lang.org/std/convert/enum.Infallible.html)

## 6. 7 个稳定内核版本累计逾 9,000 个补丁

Greg Kroah-Hartman 发布了 7.2.6、6.18.52、6.12.110、6.6.157、6.1.188、5.15.221 和 5.10.270 共 7 个稳定内核版本，累计补丁数量可能创下历史纪录，总计超过 9,000 个。其中 7.2.6 单一版本就包含超过 1,800 个补丁。

**原文：** [More than 9,000 patches total in the seven stable kernels for Monday](https://lwn.net/Articles/1093985/) · [7.2.6 补丁统计](https://lwn.net/ml/linux-kernel/20260912065648.999753832@linuxfoundation.org/)

如此大规模的补丁注入反映了两个趋势。其一，内核维护分支数量持续增长，更多子系统维护者向稳定分支推送修复；其二，随着内核复杂度上升，回归面扩大，每个维护周期暴露的问题也更多。7.2.6 作为最新 LTS 分支的次稳定版本，其 1,800+ 补丁规模表明 7.2 合入的特性在稳定阶段仍有较多待修缺陷。

**关注意义：** 使用上述任一内核版本的用户应尽快升级。对于生产环境，重点关注自己所用子系统的补丁分布，特别是网络栈、文件系统和驱动层的修复密度。

**参考：** [LWN 7.2.6 报道](https://lwn.net/Articles/1093986/) · [Stable kernel announcements](https://www.kernel.org/)

## 7. Fedora 45 以 kmscon 取代内核 fbcon 控制台

Fedora 45 beta 引入一项重大变更：Linux 遗留的内核控制台（通常在 GUI 之下隐藏的文 本模式接口）被替换为受软件控制的用户态方案。替代方案是 `kmscon`，一个开发超过 10 年的用户态终端模拟器。长期目标是废弃内核中的 fbcon/fbdev 仿真。

**原文：** [Fedora 45 beta drags the Linux console into the 21st century](https://lwn.net/Articles/1094762/) · [Fedora 变更文档](https://fedoraproject.org/wiki/Changes/UseKmsconVTConsole)

核心动机来自两方面。其一，内核 fbcon/fbdev 的维护意愿持续下降——Unicode 支持、键盘配置、多语言渲染等功能在内核态实现成本高昂且效果有限，而用户态的 kmscon 可以自然获得更好的 Unicode 渲染、鼠标支持和缩放能力。其二，将控制台逻辑移入用户态使内核可以更干净地剥离显示相关代码，减少内核攻击面。

该变更不影響串口控制台（serial console/tty），仅针对虚拟终端（VT/vtcon）层。但社区反馈显示，`/dev/pts/n` 替代 `/dev/ttyN` 带来了设备识别难题——系统无法直接判断某个动态分配的伪终端是否关联本地控制台，这影响了基于本地认证的安全策略、盲文显示和屏幕阅读器的无障碍支持。

**关注意义：** 对重度依赖内核控制台的用户，需验证 kmscon 的兼容性，特别是设备路径变更对 PAM、`login`、`sshd` 的影响。对于内核开发者而言，fbcon/fbdev 的长期废弃意味着显示控制台相关调试和故障排除方式将发生结构性变化。

**参考：** [kmscon 项目](https://github.com/kmscon/kmscon) · [Fedora 变更文档](https://fedoraproject.org/wiki/Changes/UseKmsconVTConsole)

## 8. Emacs 任意代码执行漏洞修复不完整

Sean Whitton 宣布，Emacs 中一处任意代码执行漏洞（CVE-2024-53920）的原始修复不完整。Bas Alberts 发现，在非 Lisp 模式下查看或编辑不可信文件同样可能导致任意代码执行。该问题影响 Emacs 24 及更新版本，修复已排入 Emacs 31.2 发布。

**原文：** [Emacs arbitrary code execution flaw](https://lwn.net/Articles/1094224/) · [问题公告](https://lwn.net/ml/all/87tsnskt3e.fsf%40athena.silentflame.com/)

LWN 于 2024 年 12 月报道了原始漏洞。核心问题在于 Emacs 的文件处理管道——包括模式钩子、自动加载和文件内容解析——在处理不可信输入时可能触发未预期的代码执行路径。原始修复仅覆盖了 Lisp 模式，但未覆盖其他文件模式（如 text、fundamental、markdown 等），说明 Emacs 的信任模型在不同模式间存在差异，且修复难以做到穷尽。

**关注意义：** 在 Emacs 31.2 发布前，避免使用 Emacs 打开来源不明的文件，特别是可能包含恶意嵌入内容的文档。对于使用 `flymake` 等自动分析功能的用户，建议临时禁用相关功能以降低风险。

**参考：** [LWN 原始报道](https://lwn.net/Articles/1002046/) · [CVE-2024-53920](https://nvd.nist.gov/vuln/detail/cve-2024-53920)

## 本周总体判断

本周议题呈现三条主线。第一，内核异步 I/O 基础设施继续演进——io_uring 的线程身份切换方案和 BPF 驱动 blk-iocost 代表 Linux 在高性能 I/O 方向上的持续投入，二者都试图在保持内核安全的边界内给予应用更细粒度的控制。第二，构建与编译效率成为显性议题，从内核构建加速到 Rust never 类型的 10 年稳定化之旅，反映了开发者工具链在长期技术债务清理上的进展。第三，安全修复的复杂性持续上升——Emacs 漏洞修复不完整、7 个稳定内核版本累计逾 9,000 个补丁，表明大型软件项目在面对复杂攻击面时，单次修复难以覆盖全部路径。

对内核工程人员而言，本周最值得跟踪的是 io_uring 线程身份切换方案的后续迭代和 BPF 在 blk-iocost 中的实际性能影响；对系统运维人员而言，Fedora 45 的控制台变更和 Emacs 安全漏洞是需要优先处理的运维事项。

**来源汇总：** [LWN 首页](https://lwn.net/) · [LWN Kernel coverage](https://lwn.net/Kernel/) · [2026-09-17 Weekly Edition](https://lwn.net/Articles/1093434/)
