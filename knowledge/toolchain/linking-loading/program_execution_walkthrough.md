# 从 .o 到 main：一个 Linux 程序的链接、装载与启动

> 分享母稿，面向了解 C、基础 Linux 和 ELF 的读者。主线为 Linux x86-64、ELF64、GCC / GNU binutils、glibc。
>
> 不试图背下所有 ELF 字段，而是持续回答：**`add()` 怎么找到实现？`global_counter` 的地址怎么确定？`printf()` 怎么进入进程？谁最终调用 `main()`？**

## 阅读与演讲导航

| 章节 | 核心问题 | 首轮分享取舍 |
|---|---|---|
| [1. 实验文件与构建过程](#overview) | 文件放在哪里，各自保存什么？ | 必讲，认识实验与产物 |
| [2. 拆开 .o](#object-files) | 机器码以外还需要什么？ | 必讲，聚焦符号和重定位 |
| [3. 链接](#linking) | 多个输入如何形成一个输出？ | 必讲，手算一次调用位移 |
| [4. 最终 ELF](#executable-elf) | 内核需要哪些装载说明？ | 必讲，建立双视图 |
| [5. execve](#execve) | 文件如何变成地址空间？ | 必讲，聚焦映射与交接 |
| [6. 动态链接器](#dynamic-linker) | 为什么装载后仍需重定位？ | 必讲，lazy / now 对照是重点 |
| [7. 到达 main](#startup-to-main) | 谁执行启动代码和构造函数？ | 必讲，闭合整条链 |
| [附录](#experiment-index) | 如何复现、深入和排错？ | 按问题选讲 |

这是一份详实母稿，不要求一次逐段讲完。首轮分享可以跳过 COPY 重定位、符号抢占、COMMON、TLS / IFUNC 和源码实现拓展；优先保留总流程图、一次重定位手算、一次入口观测和一次 GOT 回填实验。

实验遵循“**提出问题 → 执行命令 → 阅读关键证据 → 得出结论**”。正文中的实测片段来自同一轮实验；省略的行用说明文字标识。所有地址、偏移、节索引和指令布局都不是跨环境保证。

### 实验来源与环境

已有笔记是内容起点，而非未经核验的结论来源：

- [编译流程](../compilation/compile.md)、[ELF](../binary-format/elf.md)。
- [GNU linker](linker.md)、[动态链接概览](dynamic_link.md)。
- [execve 源码笔记](../../linux-kernel/execution/execve.md)。

旧版基于 WSL2 开发环境编写；本版于 **2026-10-28** 在当前 container 中重新构建并验证，不再依赖旧环境的外部实验目录。实验源码直接使用仓库内的 [main.c](../../../labs/compiling-linking/src/main.c)、[calc.c](../../../labs/compiling-linking/src/calc.c)、[calc.h](../../../labs/compiling-linking/src/calc.h)。

[walkthrough 实验](../../../labs/compiling-linking/walkthrough/Makefile) 复用这些源码，构建产物集中放到 gitignored 的 `labs/compiling-linking/output/program-execution-walkthrough/`，不改动原始实验源码。

本次实测环境：

```text
Linux x86_64 / container
OS:     Ubuntu 24.04.5 LTS (Noble Numbat)
kernel: 5.15.0-191-generic
gcc:    13.3.0 (Ubuntu 13.3.0-6ubuntu2~24.04.1)
ld:     GNU Binutils for Ubuntu 2.42
glibc:  2.39 (Ubuntu 2.39-0ubuntu8.9)
gdb:    15.1 (Ubuntu 15.1-1ubuntu1~24.04.1)
strace: 6.8
make:   GNU Make 4.3
page:   4096 bytes
```

容器中的 `uname -r` 反映共享的宿主机内核，不是容器内 Ubuntu 用户态的发行版本。当前 GCC / binutils / glibc 的主要版本与旧环境一致；本次重新核对后，正文的 `.o` 节布局、调用位移、主程序入口和 PLT / GOT 链接地址仍一致，运行时随机地址则已换成本轮实测值。

源码导航仍固定引用 **Linux v6.8** 和 **glibc 2.39**，用于理解机制。Linux v6.8 不是当前容器共享的内核版本，不把它的函数调用链声称为本机内核逐行跟踪结果。发行版 glibc 也可能带补丁，正文用本机实验与上游版本交叉解释。[R4][R5][R6]

### 一次性准备

从笔记仓库根目录执行，先记录环境并强制重新构建，避免迁移进来的旧产物因时间戳未变而被 make 复用。后续 shell 实验默认处于构建产物目录：

```bash
uname -srmo
cat /etc/os-release
gcc --version
ld --version
getconf GNU_LIBC_VERSION
gdb --version
strace --version
getconf PAGESIZE

make -B -C labs/compiling-linking/walkthrough -j2 all
cd labs/compiling-linking/output/program-execution-walkthrough
```

需要 GCC、make、binutils；动态观测还需要 GDB、strace 和允许调试自己子进程的环境。本次容器中的工具均已具备，GDB 与 strace 跟踪子进程均成功；无需安装依赖、root、关闭 ASLR 或修改容器安全配置。容器身份本身不保证允许 ptrace；若换到其他容器后被策略禁止，应明确说明限制，不把静态反汇编当作 GOT 已发生回填的证据。

| 产物 | 构建意图 |
|---|---|
| `main.i` / `main.s` / `main.o` | 预处理、编译、汇编后的不同表示 |
| `calc.o` / `calc.pic.o` | 用于归档的对象与用于共享库的 PIC 对象 |
| `libcalc.a` / `libcalc.so` | 静态归档与共享对象 |
| `elf_archive` | PIE，显式纳入 `libcalc.a`，libc 仍动态链接 |
| `elf_shared` | PIE，依赖 `libcalc.so` 与 libc，显式 NOW |
| `bind_lazy` / `bind_now` | 非 PIE，对同一 `add()` 调用两次，只改变绑定策略 |
| `startup` / `libcalc_init.so` | 观察共享库构造函数、程序构造函数和 main |

**为什么不直接反复 `make` 原实验？** 原 makefile 的 static / shared 都使用 `-lcalc`。GNU ld 在相应动态链接搜索模式下，同一目录通常优先找 `.so` 再找 `.a`；旧产物和构建先后会影响“static”是否真的用了归档。这里显式把 `libcalc.a` 或 `libcalc.so` 作为输入，并用 `DT_NEEDED` 验证结果。名称不是证据。[R3]

<a id="overview"></a>

## 1. 实验文件与构建过程【必讲】

这个实验只有两个 C 源文件：`main.c` 使用计算模块，`calc.c` 提供实现。我们把同一个模块分别做成静态库和共享库，再生成两个可执行文件，比较代码、数据和外部引用的处理方式。

先看文件放在哪里，再看它们之间的关系，最后按构建顺序打开各类产物。本章只选取理解文件所需的格式内容；完整 ELF 表项、重定位计算和启动过程留给后续章节。

### 1.1 实验目录

实验位于仓库的 `labs/compiling-linking/`。下面列出与本文有关的目录和文件，省略部分后续实验产物：

```text
labs/compiling-linking/
├── src/
│   ├── main.c                      主程序
│   ├── calc.c                      计算函数和全局变量的定义
│   ├── calc.h                      供两个源文件使用的接口声明
│   └── makefile                    原始实验的构建脚本
├── walkthrough/
│   ├── Makefile                    本文使用的构建脚本，复用 src/ 源码
│   ├── binding.c / binding.gdb      第 6 章的绑定实验与调试脚本
│   └── library_init.c / startup.c  第 7 章的初始化实验
└── output/
    └── program-execution-walkthrough/
        ├── main.i / main.s         保留下来的预处理结果与汇编文本
        ├── main.o / calc.o         可重定位目标文件
        ├── calc.pic.o              用于共享库的目标文件
        ├── libcalc.a / libcalc.so  同一模块的两种库
        ├── elf_archive / elf_shared
        ├── elf_archive.map / elf_shared.map
        └── chapter1/              本章分步操作的独立输出目录
```

`src/` 保存原始代码，`walkthrough/` 保存本文增加的实验和构建规则，`output/` 保存生成文件，不纳入版本控制。本文使用 `walkthrough/Makefile`，不需要到 `src/` 中执行原始 makefile。

执行前面的“一次性准备”会生成树中的主线产物，以及后续用的 `bind_lazy`、`bind_now`、`startup` 等对照程序。`chapter1/` 则由本章手动建立，避免覆盖后续章节引用的产物；其中还会生成默认构建没有保留的 `calc.i`、`calc.s`。

目录中还可能看到以下文件，它们不是这条构建流程的必经产物：

| 文件组 | 来源与用途 |
|---|---|
| `elf_fully_static`、`elf_stripped` | 单独构建或处理得到的完全静态、去符号对照程序 |
| `loader.log`、`syscalls.log`、`entry.log`、`binding-*.log` 等 | 执行后续观察命令，保存动态链接器、strace 或 GDB 的输出 |
| `*.stdout` | 保存某次运行的标准输出 |

日志需要另外采集，重新 `make` 不会自动更新它们。先不用读这些文件，本章只关注上面目录树中的主线。

### 1.2 各类文件的作用

下面是源码到产物的逻辑关系。`calc.c` 有两条分支：普通对象用于静态归档，PIC 对象用于共享库。

```text
main.c + calc.h
  └─ 预处理 → main.i ─ 编译 → main.s ─ 汇编 → main.o

calc.c + calc.h
  ├─ 预处理 → calc.i ─ 编译 → calc.s ─ 汇编 → calc.o
  │                                              └─ ar → libcalc.a
  └─ 以 -fPIC 预处理、编译、汇编 → calc.pic.o
                                    └─ 共享链接 → libcalc.so

main.o + libcalc.a  + 启动对象、系统库等 ─ 链接 → elf_archive
main.o + libcalc.so + 启动对象、系统库等 ─ 链接 → elf_shared
```

这里的“编译”特指 C 到汇编这一步。日常说“编译项目”时，往往也包含预处理、汇编和链接。

| 文件 | 保存什么，由谁使用 | 本例程序启动时是否需要读取 |
|---|---|---|
| `.c`、`.h` | 人编写的源码与声明，供预处理和编译使用 | 否 |
| `.i` | 展开头文件、宏和条件编译后的 C 文本，供编译器使用 | 否 |
| `.s` | 目标架构的汇编文本，供汇编器使用 | 否 |
| `.o`、`.pic.o` | 机器码、数据、符号、重定位等，供链接器使用 | 否 |
| `.a` | 多个目标文件及索引的归档，供链接器选取成员 | 否，所需成员已纳入输出 |
| `.so` | 经过链接的共享对象，构建时参与链接，运行时可被装载 | 共享版需要 `libcalc.so` |
| `elf_archive`、`elf_shared` | 主程序的代码、数据和装载、动态链接信息 | 是，分别作为执行的主文件 |
| `.map` | 链接器输出的文本报告，供人查看输入来源与输出布局 | 否 |

所以，目录中的文件不都是“上一个文件换一种编码”。`.i`、`.s` 是不同层次的文本表示，`.o` 是带结构的二进制对象，`.a` 是对象的集合，`.so` 和可执行文件则是链接输出。

图中每一步也不要求留下一个永久文件。例如现有 Makefile 的 `gcc -c main.c` 会自行完成预处理、编译、汇编，不会去读取同目录已有的 `main.i`、`main.s`。下面把阶段拆开执行，是为了逐份观察。

### 1.3 文本文件：源码、预处理结果与汇编

以下命令接着“一次性准备”执行，此时位于 `output/program-execution-walkthrough/`：

```bash
mkdir -p chapter1
cd chapter1
SRC=../../../src
```

`SRC` 指向实验的 `src/`。本章后续命令都在这个子目录、同一个 shell 中依次执行，章末再回到上一级。输出摘录来自这里重新生成的文件；文件偏移、节索引和指令地址可能随工具链或选项变化。

#### 源码：main 知道接口，calc 提供定义

先查看这三个文件：

```bash
cat "$SRC/calc.h" "$SRC/main.c" "$SRC/calc.c"
```

`calc.h` 中与本章主线有关的声明是：

```c
extern int global_counter;
int add(int a, int b);
```

`main.c` 包含这个头文件，并使用这些名字。以下是其中两条语句，省略了中间的其他操作：

```c
printf("add(%d, %d) = %d\n", x, y, add(x, y));
printf("global_counter = %d\n", global_counter);
```

`calc.c` 包含对应的定义，以下两处之间也省略了其他定义：

```c
int global_counter = 10;

int add(int a, int b)
{
    return a + b;
}
```

声明让编译器知道变量的类型、函数的参数和返回值；这里的定义才提供变量的存储与函数体。`main.c` 不需要读到 `calc.c` 就可以编译，但后续链接必须找到这些引用对应的定义。

#### .i：包含头文件之后的 C 文本

```bash
gcc -std=c11 -O0 -g -fPIE -E "$SRC/main.c" -o main.i
gcc -std=c11 -O0 -g -fPIE -E "$SRC/calc.c" -o calc.i
grep -n -E 'calc.h|extern int global_counter|int add\(|int main\(' main.i
```

`-E` 让 GCC 停在预处理之后。摘录如下，省略 grep 的行号和其他匹配行：

```text
# 1 "../../../src/calc.h" 1
extern int global_counter;
int add(int a, int b);
int main(void)
```
对于代码:

```c

#include "calc.h"

/* main.o 自己的已初始化数据 */
static int local_data = 100;

/* main.o 自己的只读数据 */
static const char message[] = "ELF compilation and linking laboratory";

```

经过预处理展开后将变成：

```text
# 4 "../src/calc.h"
extern int global_counter;
extern int uninitialized_value;

int add(int a, int b);
int multiply(int a, int b);
void update_counter(int value);
# 3 "../src/main.c" 2


static int local_data = 100;


static const char message[] = "ELF compilation and linking laboratory";
```
打开完整 `main.i`，还能看到 `stdio.h` 展开后的大量声明，以及原来的 `main` 函数体。`# 行号 "文件名"` 记录源位置，供后续诊断和调试使用，不是待执行的语句。

此时 `#include "calc.h"` 已被展开，但 `add` 仍只有声明：预处理不会自动查找并合入 `calc.c` 的实现。每个源文件经过预处理后形成各自的编译单元。

#### .s：用汇编表示代码与数据

```bash
gcc -std=c11 -Wall -Wextra -Wpedantic -O0 -g -fPIE -S main.i -o main.s
gcc -std=c11 -Wall -Wextra -Wpedantic -O0 -g -fPIE -S calc.i -o calc.s
grep -n -B 5 -A 3 'call.*add@PLT' main.s
```

输入 `.i` 表示已预处理的 C 文本，`-S` 要求输出汇编。本次调用 `add` 附近的内容如下，省略 grep 行号：

```asm
	.loc 1 16 5
	movl	-4(%rbp), %edx
	movl	-8(%rbp), %eax
	movl	%edx, %esi
	movl	%eax, %edi
	call	add@PLT
	movl	%eax, %ecx
    .loc 1 16 5 is_stmt 0 discriminator
     movl    -4(%rbp), %edx
```

这是 x86-64 的 AT&T 汇编语法，源操作数在前、目的操作数在后。这里先从栈中取出 `y`、`x`，将两个整数参数放进 `%esi`、`%edi`，调用后从 `%eax` 取得返回值。

`call`、`movl` 会被编码成机器指令；`.loc` 是源位置指令，供汇编器生成调试信息，不会作为 CPU 指令执行。文件中的 `.section`、`.globl` 等也属于组织内容、描述符号的汇编器指令。

`add@PLT` 表达一种针对 `add` 的调用引用，此时还没有给出最终调用位移。它也不保证最终一定经过 PLT：链接器找到本地定义后可以直接连接到函数，第三章会检查这个结果。

```asm
.loc 1 16 5 is_stmt 0 discriminator 1
```
是 GNU 汇编器 GAS 的伪指令，用于生成 DWARF 源码行号调试信息。它不属于 CPU 指令，不会实际执行，而是告诉汇编器， 接下来的汇编指令对应源文件编号 1 的第 16 行、第 5 列。  

格式为

```
.loc 文件编号 行号 [列号] [选项]
```

本实验用 `-O0` 便于观察代码、`-g` 保留调试信息；`-fPIE` 为位置无关可执行文件生成代码。`-O0` 不代表源码调用绝不会转换，例如本例 GCC 仍将一处 `printf` 转成了 `puts`。

### 1.4 .o：有机器码，但还需要链接

#### ELF 头和节：怎样找到文件里的内容

把汇编文本交给汇编器：

```bash
gcc -c main.s -o main.o
gcc -c calc.s -o calc.o
file main.o calc.o
readelf -hW main.o
```

这里 `gcc` 根据 `.s` 后缀调用汇编器，`-c` 表示不继续链接。`file` 将两个输出识别为 ELF 64 位、小端、x86-64 的可重定位文件。`main.o` 的 ELF 头部分摘录如下：

```text
Class:                             ELF64
Data:                              2's complement, little endian
Type:                              REL (Relocatable file)
Machine:                           Advanced Micro Devices X86-64
Entry point address:               0x0
Start of section headers:          3952 (bytes into file)
Number of section headers:         23
```

ELF 是这里目标文件、共享库和可执行文件共同采用的格式。文件开头的 ELF 头说明如何解释后续内容：位数、字节序、目标架构，以及其他表的位置。`REL` 对应 `ET_REL`，表示它还要参与链接，不是可以直接启动的普通程序。

目标文件按用途把内容分成节（Section）。节头表为每个节记录类型、位置、大小等信息，工具先找到这张表，再定位所需内容：

```text
ELF 头 ──记录节头表的文件偏移──→ 节头表
                                 ├─ .text 的描述 ──→ 指令字节
                                 ├─ .data 的描述 ──→ 已初始化数据
                                 ├─ .symtab 的描述 → 符号记录
                                 └─ 其他节的描述   → 相应内容或空间需求
```

这是引用关系图，不表示这些内容必须按图中的顺序排列。继续查看节头表：

```bash
readelf -SW main.o
readelf -SW calc.o
```

下面从本次 `main.o` 中选取几行，只保留部分列；`Off`、`Size` 为十六进制：

```text
[Nr] Name        Type       Off    Size
[ 1] .text       PROGBITS   000040 0000cf
[ 2] .rela.text  RELA       000a08 000180
[ 3] .data       PROGBITS   000110 000004
[ 4] .bss        NOBITS     000114 000000
[ 5] .rodata     PROGBITS   000120 00007f
[20] .symtab     SYMTAB     0007b8 0001e0
[21] .strtab     STRTAB     000998 00006b
```

`.text` 保存函数的指令字节，`.data` 保存本例的已初始化可写数据，如 `local_data = 100`；`.rodata` 保存只读数据，如 `message` 字符串。`.symtab` 是符号表，`.strtab` 保存它引用的符号名字符串，`.rela.text` 则记录 `.text` 中待重定位的位置。

`.bss` 用于本例需要零初始化的静态存储期对象。它的类型是 `NOBITS`：记录空间大小，但不在文件里存放同等大小的全零字节。`main.o` 的 `.bss` 大小为 0，因为 `uninitialized_value` 定义在 `calc.c`，要到 `calc.o` 中查看。

这里的文件偏移和运行地址是两件事。例如 `.text` 的 `Off=0x40` 表示从文件开头数 64 字节处开始读取，不是说 CPU 会从地址 `0x40` 执行它。

| 编号 | Section | 类型 | 主要作用 | 是否进入运行时内存 |
|---|---|---|---|---|
| 0 | NULL | 空 Section | ELF 规范保留的无效占位项。索引 0 通常表示未定义 Section，例如符号表中的 UND。 | 否 |
| 1 | .text | PROGBITS | 保存函数编译后生成的机器指令，例如 add、sub 等函数的代码。具有 A 和 X 属性，表示需要分配内存且可执行。 | 是 |
| 2 | .rela.text | RELA | 保存针对 .text 的重定位记录，告诉链接器需要修正哪些函数调用、全局变量访问或只读数据引用。 | 否，链接时使用 |
| 3 | .data | PROGBITS | 保存具有非零初始值的可写全局变量和静态变量。具有 W 和 A 属性。 | 是 |
| 4 | .bss | NOBITS | 保存未初始化或初始化为零的全局变量和静态变量。只记录所需内存大小，不在文件中保存实际零值。 | 是，由加载器置零 |
| 5 | .rodata | PROGBITS | 保存字符串字面量、只读常量和跳转表等只读数据。具有 A 属性，没有 W 属性。 | 是 |
| 6 | .debug_info | PROGBITS | DWARF 调试信息的核心，描述源文件、函数、变量、参数、类型以及变量位置等信息。 | 否 |
| 7 | .rela.debug_info | RELA | 保存针对 .debug_info 的重定位记录，修正其中引用的代码地址、数据地址及其他调试 Section。 | 否，链接时使用 |
| 8 | .debug_abbrev | PROGBITS | 保存 .debug_info 中 DIE 调试条目的结构模板，用于减少重复字段定义。 | 否 |
| 9 | .debug_aranges | PROGBITS | 保存代码地址范围到编译单元的快速索引，帮助调试器判断某个地址属于哪个源文件编译单元。 | 否 |
| 10 | .rela.debug_aranges | RELA | 保存针对 .debug_aranges 的重定位记录，修正其中尚未确定的代码地址范围。 | 否，链接时使用 |
| 11 | .debug_line | PROGBITS | 保存机器指令地址与源文件、行号和列号之间的映射，用于断点和源码级单步调试。 | 否 |
| 12 | .rela.debug_line | RELA | 保存针对 .debug_line 的重定位记录，修正行号信息中引用的代码地址或其他 Section。 | 否，链接时使用 |
| 13 | .debug_str | PROGBITS | DWARF 通用字符串池，保存函数名、变量名、类型名、编译器信息和路径等字符串。 | 否 |
| 14 | .debug_line_str | PROGBITS | 专门供 DWARF 行号表使用的字符串池，通常保存源文件名、目录名和编译工作路径。 | 否 |
| 15 | .comment | PROGBITS | 保存编译器版本或工具链标识等说明字符串，不影响程序执行。 | 否 |
| 16 | .note.GNU-stack | PROGBITS | 告诉链接器当前目标文件是否要求可执行栈。没有 X 标志通常表示不要求可执行栈。 | 不直接装载，用于决定栈权限 |
| 17 | .note.gnu.property | NOTE | 保存 GNU 平台属性或体系结构安全特性，例如 ISA 要求、CET、IBT 或 Shadow Stack 等。具体内容可通过 readelf -n 查看。 | 通常保留，并可能映射到内存 |
| 18 | .eh_frame | PROGBITS | 保存调用帧展开信息，说明如何恢复栈指针、返回地址及保存的寄存器，用于异常处理、栈回溯和调试。 | 是 |
| 19 | .rela.eh_frame | RELA | 保存针对 .eh_frame 的重定位记录，修正其中引用的函数起始地址和代码范围。 | 否，链接时使用 |
| 20 | .symtab | SYMTAB | 完整静态符号表，记录函数、变量、Section 和未定义外部符号的名称索引、类型、绑定属性、所属 Section、大小及地址。 | 否，链接和调试时使用 |
| 21 | .strtab | STRTAB | .symtab 使用的字符串表，保存函数名、变量名和文件名等符号名称。 | 否 |
| 22 | .shstrtab | STRTAB | Section Header String Table，保存 .text、.data、.symtab 等全部 Section 的名称。 | 否 |

这里还有一些sections没有出现：  

| calc.o 中的信息 | 链接器处理后可能形成 |
|---|---|
| .symtab 中的未定义动态符号 | .dynsym 中的导入符号 |
| .strtab 中相关符号名 | .dynstr 中的动态字符串 |
| .rela.text 中的函数调用重定位 | .plt、.got.plt、.rela.plt |
| .rela.text 中的数据地址重定位 | .got、.rela.dyn |
| 链接命令指定的共享库 | .dynamic 中的 DT_NEEDED |
| 动态链接器路径 | .interp 和 PT_INTERP |
| GOT、PLT及动态符号表的位置 | .dynamic 中的 DT_* 条目 |

这类sections将由ld生成。  

#### Symbol Table：引用与定义怎样对应

```bash
readelf -sW main.o calc.o
```

从两个文件中各取几条记录，省略符号编号和 `Vis` 列：

```text
main.o:
Value             Size Type    Bind   Ndx Name
0000000000000000   207 FUNC    GLOBAL   1 main
0000000000000000     0 NOTYPE  GLOBAL UND add
0000000000000000     0 NOTYPE  GLOBAL UND global_counter

calc.o:
Value             Size Type    Bind   Ndx Name
0000000000000000    24 FUNC    GLOBAL   1 add
0000000000000000     4 OBJECT  GLOBAL   3 global_counter
```

`main.o` 中的 `UND` 表示本文件没有定义这个符号；`calc.o` 中 `add` 的 `Ndx=1` 指向该对象的 `.text`，`global_counter` 的 `Ndx=3` 指向 `.data`。`FUNC`、`OBJECT` 分别标记函数和数据对象；本例的 `GLOBAL` 绑定允许它们参与跨对象的符号解析。

对这里 ET_REL 中的普通定义，`Value` 是所在节内的偏移。`add` 和 `global_counter` 都为 0，是因为各自在自己的节开头，不是两者运行时共用地址 0。`UND` 记录的 0 则不是定义位置，也不表示读取变量会得到 0。

链接器正是借助这些记录，知道 `main.o` 需要哪些定义，以及 `calc.o` 能提供什么。

#### 重定位：哪几个字节还需要修改

符号表说明引用了谁，但还需要知道指令中哪里使用了这个引用：

```bash
objdump -dr main.o
readelf -rW main.o
```

`objdump -dr` 同时显示反汇编和重定位信息。调用 `add` 的两行是：

```text
33: e8 00 00 00 00    call 38 <main+0x38>
    34: R_X86_64_PLT32 add-0x4
38:   89 c1                   mov    %eax,%ecx
```
`call rel32`指令最终目标地址的计算逻辑为：

```
目标地址 = 下一条指令地址 + 32号有符号位移（即四个字节相对位移）
```

这里需要ralocate的位移则为
```
32位有符号位移 = 目标地址 - 下一条指令地址 = 目标地址 - 0x38
```

链接器计算地址时，对于R_X86_64_PLT32, 需要填入的地址为
```
L + A - P
```

之所以是这个公式是因为：  
L: add对应的plt入口地址，即目标地址
P: 被重定位字段的地址，这里是0x34
A: 为了得到正确的结果还需要加上的附加值，这里最终需要填入的地址是 L - 0x38, 所以A = -4

左边的 `0x33` 是 `.text` 节内偏移；`e8` 是调用指令的操作码，后面四个字节保存相对位移。此时这四个字节仍为 0，所以单看反汇编会显示跳到下一条指令，而不是最终的 `add`。

重定位记录补充了实际含义：

| 记录内容 | 对这条调用的意义 |
|---|---|
| `0x34` | 从 `.text` 节内偏移 `0x34` 开始修补，即操作码之后的位移字段 |
| `add` | 计算时引用的符号 |
| `R_X86_64_PLT32` | 本架构规定的重定位类型，指定计算与编码规则 |
| `-4` | 参与计算的加数，不是 `add` 的地址 |

所以 `.o` 中已经有调用指令，但调用目标尚未落实到正确的位移字节。第二章继续解释表项之间的索引关系，第三章再根据链接后的布局计算这个位移。

### 1.5 库文件：.a 与 .so 的内容不同

#### .a：把目标文件归档

```bash
ar rcs libcalc.a calc.o
ar t libcalc.a
nm -s libcalc.a
```

`ar t` 列出归档成员，本例只有：

```text
calc.o
```

`nm -s` 还会显示归档索引，部分结果为：

```text
Archive index:
global_counter in calc.o
uninitialized_value in calc.o
add in calc.o

calc.o:
0000000000000000 T add
0000000000000000 D global_counter
0000000000000004 d internal_state
```

索引告诉链接器哪个成员可能提供所需符号。`libcalc.a` 本身是 `ar` 归档，不是一个新的 ELF 可执行文件；其中的 `calc.o` 仍是刚才的可重定位对象。

执行 `ar` 时还没有输入 `main.o`，也没有安排最终程序的地址。最终链接时，链接器根据未定义引用提取所需成员；本例提取的是整个 `calc.o`，不是只复制 `add` 函数。

#### .so：把 PIC 对象链接成共享对象

```bash
gcc -std=c11 -Wall -Wextra -Wpedantic -O0 -g -fPIC \
  -c "$SRC/calc.c" -o calc.pic.o
gcc -shared calc.pic.o \
  -Wl,-soname,libcalc.so \
  -Wl,-Map,libcalc.map \
  -Wl,--cref \
  -o libcalc.so
file calc.pic.o libcalc.a libcalc.so
readelf -hW libcalc.so
readelf --dyn-syms -W libcalc.so
```

使用-fPIC编译的可重定位文件和不使用该参数的区别如下：  

符号类型 | 非 PIC 可重定位文件 | PIC 可重定位文件 | 关键差异 |
|---|---|---|---|
| 局部变量、函数参数 | 栈或寄存器 | 栈或寄存器 | 通常无差异 |
| 文件内 static 数据 | 通常 RIP 相对直接访问 | 通常仍是 RIP 相对直接访问 | 相对位置固定，无需 GOT |
| 字符串常量 | 通常 RIP 相对引用 .rodata | 通常仍是 RIP 相对引用 .rodata | 相对位置固定，无需 GOT |
| static 函数 | PC 相对直接调用 | 通常仍是 PC 相对直接调用 | 不可被外部抢占，无需 PLT |
| hidden 函数或数据 | PC/RIP 相对直接引用 | PC/RIP 相对直接引用 | 已知绑定在当前共享对象内部 |
| 默认可见全局变量 | 可直接使用 RIP 相对访问 | 通常通过 GOT 间接访问 | PIC 需支持运行时符号抢占 |
| 外部全局变量 | 可由链接器直接修正引用 | 通常通过 GOT 间接访问 | 实际地址需要运行时确定 |
| 默认可见全局函数 | 通常产生 PLT32 重定位 | 通常通过 PLT 调用 | 可能被其他 ELF 对象抢占 |
| 外部函数 | 通常产生 PLT32 重定位 | 通常通过 PLT/GOT 调用 | 实际实现可能来自共享库 |
| 函数或变量地址 | 链接器可写入地址或相对值 | 可抢占符号通常经 GOT，局部符号可用 RIP 相对 lea | 取地址也必须遵守绑定语义 |

```asm

# 访问 global_counter
# 普通版本
# 访问路径为 指令 → global_counter的值
3a: mov 0x0(%rip),%edx

# pic版本
# 访问路径为 指令 → GOT槽位 → global_counter地址 → global_counter值
3a: mov 0x0(%rip),%rax
41: mov (%rax),%edx
```
普通版本直接把结果写向 RIP 相对目标；PIC 版本先从 GOT 获取变量地址，再间接写入。  

对于pic,对于能确定绑定在当前共享对象内部的符号，只需保持相对位置固定并使用 RIP/PC 相对寻址；对于装载地址和最终符号绑定都可能在运行时确定的全局符号，则通过 GOT 或 PLT 间接访问。

```text
calc.c
  │ GCC编译、汇编：-c -fPIC
  ▼
calc.pic.o                         ELF可重定位目标文件
  │ 静态链接器处理：-shared
  ▼
libcalc.so                         ELF共享对象
```

g-fPIC` 生成位置无关代码，使共享库能在不同装载地址使用；它控制代码生成方式，不改变 `.o` 的文件格式。`calc.pic.o` 依然是 ET_REL，名字中的 `pic` 只是为了与另一份对象区分。

`-shared` 则要求链接器输出共享对象。本次 `libcalc.so` 的头与动态符号表部分内容如下，符号表省略编号和可见性：

```text
Type:                              DYN (Shared object file)
Entry point address:               0x0

Value             Size Type    Bind   Ndx Name
00000000000010f9    24 FUNC    GLOBAL  10 add
0000000000004008     4 OBJECT  GLOBAL  20 global_counter
```

首先，让我们先对比shared object (.so) 和 relocatable file (.o)文件结构上的区别，再借助.map尝试理解这个转换过程。  

生成共享库并不意味着所有地址都已确定。它如何通过位置无关寻址、GOT 和动态重定位适应装载地址，第六章再展开。

### 1.6 可执行文件与链接报告

#### 链接：选择实现来源并形成输出布局

有了 `main.o` 和两种库，分别生成两个程序指令 → GOT槽位 → global_counter地址 → global_counter值：

```bash
gcc -pie main.o ./libcalc.a \
  -Wl,-z,relro,-z,now,-Map,elf_archive.map \
  -o elf_archive

gcc -pie main.o ./libcalc.so \
  -Wl,-z,relro,-z,now,-Map,elf_shared.map \
  -Wl,--enable-new-dtags,-rpath,'$ORIGIN' \
  -o elf_shared
```

这里显式写出 `.a` 和 `.so`，不使用 `-lcalc`，避免库搜索优先级改变对照结果。原始实验中的 `elf_static` 只有“使用 calc 静态库”的意图，本文命名为 `elf_archive`，因为它仍然动态依赖 libc。

`gcc` 是工具链驱动：根据输入和选项调用工具，链接时还自动加入启动对象与系统库。上面的显式输入不是全部输入；我们只写了 `main`，启动入口仍由启动对象提供。

构建时的链接器（这里是 GNU ld）要查找符号定义、组织输出节和地址，并完成能确定的重定位。它既能处理归档，也能生成共享库和动态程序；“静态链接器”不表示它只会处理静态库。运行时的动态链接器则是另一份程序。

命令中，`-pie` 生成位置无关可执行文件，与前面的 `-fPIE` 配合；`-Wl,` 后的参数传给链接器。`-Map` 输出布局报告；`-z relro`、`-z now` 固定本例的保护和绑定策略，第六章再用独立程序对比延迟绑定。`-rpath` 与 new dtags 生成的查库信息在下面查看。

#### 可执行 ELF：除了代码，还有装载说明和依赖

```bash
readelf -hW elf_shared
readelf -lW elf_shared
```

头部显示本例主程序也是 `DYN`，入口为 `0x10e0`：

```text
Type:                              DYN (Position-Independent Executable file)
Entry point address:               0x10e0
```

PIE 主程序和普通共享库都使用 `ET_DYN`，但用途不同，不能只看类型就认定它是库。这里的入口值要结合装载地址解释，也不是 `main` 的运行时地址。

`readelf -lW` 读取程序头表。下面摘录解释器和可执行装载段，保留列标题：

```text
Type    Offset   VirtAddr           PhysAddr           FileSiz  MemSiz   Flg Align
INTERP  0x000318 0x0000000000000318 0x0000000000000318 0x00001c 0x00001c R   0x1
    [Requesting program interpreter: /lib64/ld-linux-x86-64.so.2]
LOAD    0x001000 0x0000000000001000 0x0000000000001000 0x0002a5 0x0002a5 R E 0x1000
```

与节头表按内容分类不同，程序头表描述装载和执行所需的信息。`LOAD` 指定一段（Segment）映射范围，包括文件偏移、虚拟地址、文件与内存大小、权限和对齐；这里 `R E` 表示可读、可执行。这段包含 `.text` 等多个节，并不是一个节对应一个段。

`INTERP` 指定程序解释器，本例是动态链接器。第四章会对照完整的节、段映射；这里先知道，可执行文件提供了让内核建立进程映像的说明，不只是机器码。

再看动态依赖：

```bash
readelf -dW elf_archive | grep NEEDED
readelf -dW elf_shared | grep -E 'NEEDED|RUNPATH'
```

两条命令依次得到：

```text
0x0000000000000001 (NEEDED)             Shared library: [libc.so.6]
```

```text
0x0000000000000001 (NEEDED)             Shared library: [libcalc.so]
0x0000000000000001 (NEEDED)             Shared library: [libc.so.6]
0x000000000000001d (RUNPATH)            Library runpath: [$ORIGIN]
```

这些是 ELF 动态信息中的记录，不是额外的配置文件。`NEEDED` 说明依赖的共享库；本例 `RUNPATH` 中的 `$ORIGIN` 由动态链接器展开为程序所在目录，用来找到旁边的 `libcalc.so`。命令中的单引号防止 shell 提前展开它。

两个程序都依赖 libc，所以 `elf_archive` 不是完全静态程序。它不需要运行时再打开 `libcalc.a`；`elf_shared` 则仍需要可找到的 `libcalc.so`。

#### .map：检查链接器实际选了什么

```bash
head -n 10 elf_archive.map
nm elf_archive elf_shared | grep -E '^elf_| add$'
```

map 开头的成员纳入记录为：

```text
Archive member included to satisfy reference by file (symbol)

./libcalc.a(calc.o)           main.o (global_counter)
```

这条记录说明链接器为了满足 `main.o` 对 `global_counter` 的引用，纳入了 `calc.o`；该成员同时带来了 `add` 等定义。后续 map 内容还能查看输出节布局和符号位置。它是可直接阅读的文本报告，运行程序不需要它。

`nm` 的结果进一步显示 `add` 在两个主文件中的差别：

```text
elf_archive:
0000000000001238 T add
elf_shared:
                 U add
```

归档版本已在自己的代码中定义 `add`；共享版本仍保留未定义引用，由动态链接关联到共享库中的实现。`T` 是 `nm` 对代码符号的简写，`U` 表示未定义，不表示这个已经成功链接的动态程序缺少了实现。

最后运行：

```bash
./elf_archive
./elf_shared
```

两个版本都输出：

```text
ELF compilation and linking laboratory
add(6, 7) = 13
multiply(6, 7) = 42
global_counter = 110
uninitialized_value = 3
```

输出相同，但 `add` 的实现位置和运行依赖不同：一个已经纳入主程序，另一个留在 `libcalc.so`。

### 1.7 从构建产物到程序运行

构建到这里已经完成。执行 `./elf_shared` 时，不会重新编译源码，也不会依次读取 `.i`、`.s`、`.o` 和 `.a`。对于本例动态程序，接下来的过程简述为：

```text
执行 elf_shared，发起 execve
  → 内核根据 ELF 程序头映射主程序和解释器
  → 动态链接器装入依赖库，完成必要的重定位
  → 主程序入口 _start
  → libc 启动流程
  → main
```

`elf_archive` 因为仍依赖 libc，也需要动态链接器。完全静态程序没有这里的外部解释器步骤，第五至七章会具体观察装载、初始化和进入 `main` 的过程。

本章分步操作结束，回到后续章节使用的产物目录：

```bash
cd ..
```

接下来第二章继续查看 `main.o`：把本章见过的节、符号和重定位记录对应起来，再进入第三章，计算链接器究竟向那条 `call` 指令写入了什么。

<a id="object-files"></a>

## 2. 拆开 .o：尚未完成的程序【必讲】

### 2.1 先认识我们跟踪的程序

`main.c` 调用 `add()`、`multiply()`、`update_counter()` 和 libc 输出函数，读取两个外部变量；`calc.c` 提供计算函数及变量定义。

| 源码实体 | 通常落点 | 后续观察价值 |
|---|---|---|
| `main` / `add` 等函数 | `.text` | 函数符号与调用重定位 |
| `local_data = 100` | main.o 的 `.data` | 文件内 LOCAL 符号，有静态存储期，不是栈局部变量 |
| `message[]` | main.o 的 `.rodata` | 只读字节与数据引用 |
| `global_counter = 10` | calc.o 的 `.data` | 跨文件定义 / 引用 |
| `uninitialized_value` | 本次 calc.o 的 `.bss` | 零初始化与装载时内存大小 |
| `internal_state` | calc.o 的 `.data` | 文件内可见定义 |
| main 中的 `x`、`y` | 本实验的栈槽 | 不等于 `.data` 中的数据对象 |

这是当前选项下的对应关系，不是“任何 C 对象都必然在某个同名节”的语言保证。优化、链接脚本、TLS、常量合并等都会改变具体表现。

### 2.2 ELF 头：告诉工具怎样解释文件

**实验 E1：`.o` 到底是不是 ELF？**

```bash
file main.o libcalc.a libcalc.so elf_archive elf_shared
readelf -hW main.o
readelf -SW main.o
```

应重点读：

| 字段 | 本实验含义 |
|---|---|
| `Class` / `Data` / `Machine` | ELF64、小端、AMD x86-64 |
| `Type` | `REL`，可重定位目标文件 |
| `Entry point address` | 本实验 main.o 为 0，不是可直接启动的程序 |
| `Start of section headers` | 从文件开头到节头表的偏移 |
| `Number of section headers` | 节头表中有多少描述项 |
| `Section header string table index` | 在哪个节中找节名字符串 |

ELF 头位于文件开头；它记录的偏移把工具引向其他表。不要以为所有表或所有节都在固定位置，或者 ELF 一定从 `.text` 开始。

本机 `file libcalc.so` 还输出了 `static-pie linked`。这是工具根据动态标签等信息做的描述性判断，**不意味着这个 `.so` 变成了我们的静态可执行程序**。应交叉检查 ELF 类型、SONAME、程序头、动态标签及用途，不能只依赖一句 `file` 描述。

### 2.3 Section：内容按链接语义分类

本次 `readelf -SW main.o` 的关键行摘录：

```text
[Nr] Name        Type       Address           Off    Size   ES Flg Lk Inf Al
[ 1] .text       PROGBITS   0000000000000000  000040 0000cf 00  AX  0   0  1
[ 2] .rela.text  RELA       0000000000000000  0009b8 000180 18   I 20   1  8
[ 3] .data       PROGBITS   0000000000000000  000110 000004 00  WA  0   0  4
[ 4] .bss        NOBITS     0000000000000000  000114 000000 00  WA  0   0  1
[ 5] .rodata     PROGBITS   0000000000000000  000120 00007f 00   A  0   0 32
[20] .symtab     SYMTAB     0000000000000000  000768 0001e0 18     21  12  8
[21] .strtab     STRTAB     0000000000000000  000948 00006b 00      0   0  1
```

- `Off` 是文件偏移；`Size` 是节的大小；`Address` 在这个 ET_REL 中为 0，不代表所有内容运行时都位于地址 0。
- `A/W/X` 表示分配属性、可写、可执行。它们是节属性，不能直接当作最终逐页权限图。
- main.o 的 `.bss` 大小为 0 并不矛盾：本例的未初始化全局变量定义在 **calc.o**。
- `NOBITS` 描述所需空间，但不在文件中存放同等大小的节内容。
- `.debug_*` 为调试信息；`.eh_frame` 为栈展开信息。不是所有重定位都在修补业务函数调用。

三个容易混淆的字符串表：`.strtab` 存普通符号名，`.shstrtab` 存节名，`.dynstr` 服务动态链接。表中保存以零字节结束的字符串，其他结构通过偏移引用它们。

> **截图位 S1：** `readelf -SW main.o`，框出 `.text`、`.rela.text`、`.symtab`、`.strtab` 的行及 `Lk/Inf` 列。突出“数据表之间有引用关系”，而不只是节名列表。

### 2.4 符号表：名字、定义位置与可见性

```bash
readelf -sW main.o
readelf -sW calc.o
nm main.o calc.o
```

本次 main.o 的符号表摘录：

```text
Num: Value             Size Type    Bind   Vis     Ndx Name
  4: 0000000000000000     4 OBJECT  LOCAL  DEFAULT   3 local_data
  6: 0000000000000000    39 OBJECT  LOCAL  DEFAULT   5 message
 12: 0000000000000000   207 FUNC    GLOBAL DEFAULT   1 main
 13: 0000000000000000     0 NOTYPE  GLOBAL DEFAULT UND puts
 14: 0000000000000000     0 NOTYPE  GLOBAL DEFAULT UND add
 15: 0000000000000000     0 NOTYPE  GLOBAL DEFAULT UND printf
 18: 0000000000000000     0 NOTYPE  GLOBAL DEFAULT UND global_counter
```

如何读：

1. `Ndx=1` 配合节头表说明 main 定义在 `.text` 中；`Value=0` 表示位于该节的起始位置。
2. `UND` 表示**这个文件没有定义**，不是“最终一定链接失败”，也不表示调用点没有机器指令。
3. calc.o 中 `add` 为 GLOBAL / FUNC，`global_counter` 为 GLOBAL / OBJECT，提供满足这些引用的定义。
4. `LOCAL` 符号仅在对应目标文件内部参与名字区分；不要把 ELF 绑定属性直接等同 C 变量的栈 / 堆分类。

对于本例普通已定义符号，ET_REL 的 `st_value` 是节内偏移；最终可执行文件和共享对象中，它通常是链接虚拟地址，PIE / DSO 运行时还要考虑 load bias。ABS、COMMON、TLS、IFUNC 等存在特殊语义，不能一句“所有 Value 都是最终地址”概括。[R1][R2]

ELF64 符号项真正需要记住的是这些关系，而不是逐字段背结构体：

```text
st_name  -> 字符串表中的名字偏移
st_info  -> 绑定属性 + 符号类型
st_other -> 包含可见性，不是恒为 0
st_shndx -> 所在节或 UND / ABS / COMMON 等特殊索引
st_value -> 依上下文解释的值
st_size  -> 大小
```

**为什么 C 里写的是 `printf("%s\n", message)`，却出现了 `puts`？** 本次 GCC 即使在 `-O0` 下也进行了这一内建函数相关转换。观察编译产物，而不是假定每个源码调用都原样保留。想研究这种转换，可额外对照 `-fno-builtin`，但本分享不依赖该拓展。

### 2.5 重定位项：明确告诉下一棒在哪里修补

```bash
objdump -dr main.o
readelf -rW main.o
```

本次两条相互对应的证据：

```text
33: e8 00 00 00 00    call 38 <main+0x38>
    34: R_X86_64_PLT32 add-0x4
```

```text
Offset             Info             Type              Symbol's Name + Addend
0000000000000034   0000000e00000004 R_X86_64_PLT32   add - 4
```

`e8` 是本次直接相对调用的操作码，后面四个字节是待确定的位移。当前四字节为零时，反汇编把它显示成跳到下一条指令；这不是程序最终的调用意图。重定位信息才说明这个位置应与 `add` 关联。

AMD64 使用的 `Elf64_Rela` 由三项构成：[R2]

| 字段 | 在该条记录中的解释 |
|---|---|
| `r_offset=0x34` | 在被修补的 `.text` 节中，四字节位移字段从哪里开始 |
| `r_info` | 高 32 位为符号索引 14，低 32 位为重定位类型 4 |
| `r_addend=-4` | 显式加数，参与该类型的计算 |

`.rela.text` 的 `sh_link=20` 指向 `.symtab`；`sh_info=1` 指向待修补的 `.text`。这就把“补哪里”“引用谁”“怎么补”连接起来。该 `sh_info` 解释针对这里的 ET_REL 重定位节，不能机械套到所有动态重定位节。

**结论：** `.o` 不是“只有机器码但地址暂时为零”。它是带着代码、数据、定义 / 引用和修补说明的可链接对象。

> **截图位 S2：** 并排显示 `objdump -dr main.o` 与 `readelf -rW main.o`，连线标出指令 `0x33`、位移字段 `0x34`、符号 `add`、加数 `-4`。

<a id="linking"></a>

## 3. 链接：把引用连接到定义【必讲】

### 3.1 静态归档不是另一种 ELF 可执行文件

**实验 E2：libcalc.a 中放了什么？**

```bash
ar t libcalc.a
nm -s libcalc.a
head -n 14 elf_archive.map
readelf -dW elf_archive
```

`ar t` 列出成员 `calc.o`；归档索引帮助链接器按符号找到可能满足未定义引用的成员。本次 map 开头摘录：

```text
Archive member included to satisfy reference by file (symbol)

../output/program-execution-walkthrough/libcalc.a(calc.o)
                              ../output/program-execution-walkthrough/main.o (global_counter)
```

这证明 calc.o 被纳入本次链接。map 显示的触发符号是 `global_counter`，不必强求输出一定写 `add`：一个成员可以同时定义多个所需符号。

通常被提取的单位是**归档成员对象**，不是自动只复制被调用的那一个函数。配合函数 / 数据独立节与 `--gc-sections` 可以更细粒度丢弃未使用内容，那是另一个机制。

传统 GNU ld 的归档处理还受命令行位置影响：通常先放产生未定义引用的对象，再放满足引用的库；循环依赖可考虑归档组。不要把本实验顺序随意颠倒后，得出“静态库坏了”。[R3]

### 3.2 链接过程不只是把二进制文件拼起来

可按三件事理解，实际实现可能多轮遍历：

1. **符号解析：** 收集输入定义和引用，决定一个引用应绑定到哪个定义；处理重复定义、未满足引用、弱符号等。
2. **空间布局：** 将输入节组织成输出节，按脚本、对齐与权限等约束安排输出地址和段布局。相同名字的输入节常被合并，但不是无条件简单拼接。
3. **重定位与输出：** 计算能在构建时确定的修补值；为运行时仍未确定的内容生成动态符号、动态重定位及 GOT / PLT 等结构。

GCC 驱动调用链接器时通常还加入 CRT 启动对象和库。最终程序中的 `_start` 不要求由 main.c 提供；`gcc -###` 可以查看驱动准备执行的命令，不能因为自己只写了 main 就认为链接输入只有两个 `.o`。

### 3.3 手算一次 add 调用

对归档版本观察：

```bash
nm -n elf_archive | grep -E ' (main|add)$'
objdump -d elf_archive --disassemble=main
```

本次实测：

```text
0000000000001169 T main
0000000000001238 T add

119c: e8 97 00 00 00    call 1238 <add>
```

前面对象中的 `main+0x33` 在输出中成为 `0x1169+0x33=0x119c`；修补字段的地址则为 `P=0x119d`。链接器确认 add 可以直接绑定到本程序中的实现后，该调用采用直接 PC 相对位移：

```text
S = 0x1238                  add 的输出地址
A = -4                      重定位项中的显式加数
P = 0x119d                  四字节位移字段的起始地址

S + A - P = 0x1238 - 4 - 0x119d = 0x97

CPU 的下一条 RIP = 0x11a1
0x11a1 + 0x97 = 0x1238
```

小端存储得到 `97 00 00 00`，与实测机器码一致。`-4` 正是这里“从修补字段开始”与“从下一条指令开始”的四字节差异，**不是所有重定位项固定都要减 4**。

AMD64 ABI 的 `R_X86_64_PLT32` 通式是 `L+A-P`，L 为 PLT 项地址。本例链接器已能将引用绑定到程序内部的 add，因而不需要保留通过 PLT 到共享库的路径。不要把该通式直接改写为“PLT32 永远等于 S+A-P”，也不要看到 `.o` 里的 `add@PLT` 就断言最终一定存在 `add@plt`。[R2][R3]

PIE 运行时如果整体增加同一个 load bias，源与目标同时平移，位移不变。这解释了“位置无关”与相对寻址的联系，但并不意味着 PIE 无须任何动态重定位。

> **截图位 S3：** 将对象中的零位移、map / nm 给出的输出地址、最终 `e8 97 00 00 00` 放到同一页，在旁边写出上述计算。

### 3.4 使用静态库，不等于完全静态程序

**实验 E3：比较两个版本依赖什么。**

```bash
readelf -dW elf_archive
readelf -dW elf_shared
nm elf_archive | grep ' add$'
nm -D elf_shared | grep ' add$'
./elf_archive
./elf_shared
```

动态标签摘录：

```text
elf_archive:
  NEEDED  Shared library: [libc.so.6]

elf_shared:
  NEEDED  Shared library: [libcalc.so]
  NEEDED  Shared library: [libc.so.6]
  RUNPATH Library runpath: [$ORIGIN]
```

归档版本中 add 已在程序内定义；共享版本的动态符号中 add 为待运行时解析的引用。两个版本都输出：

```text
ELF compilation and linking laboratory
add(6, 7) = 13
multiply(6, 7) = 42
global_counter = 110
uninitialized_value = 3
```

输出一样，不意味着构建方式或运行时工作一样。

**拓展：完全静态。** 从当前产物目录执行：

```bash
make -C ../../walkthrough optional-static
file elf_fully_static
readelf -lW elf_fully_static
readelf -dW elf_fully_static
./elf_fully_static
```

本次构建成功，输出与上面相同；没有 PT_INTERP，`readelf -dW` 报告 `There is no dynamic section in this file.`。该普通 `-static -no-pie` 样例不能推广成“所有静态程序没有重定位 / 动态节”：静态 PIE 及 glibc 自重定位、IFUNC 等另有实现细节。若系统缺少静态 libc，保留真实链接错误并说明依赖，不必为主线安装系统包。

<a id="executable-elf"></a>

## 4. 最终 ELF：从节转向段【必讲】

### 4.1 同一文件的两张视图

```text
链接视图                                执行视图

.interp  .dynsym .dynstr ... --------->  PT_LOAD: R
.init .plt .text .fini       --------->  PT_LOAD: R-X
.rodata .eh_frame ...       --------->  PT_LOAD: R
.init_array .dynamic .got
.data .bss                  --------->  PT_LOAD: RW-

.debug_* .symtab .strtab                 通常不在可装载段中
```

这是本例简化示意，不是 ELF 固定布局。一个 LOAD 段可覆盖多个节；DYNAMIC / NOTE / RELRO 等描述还能与 LOAD 描述的范围重叠。不是“每个节对应一个独立内存映射”。

```bash
readelf -hW elf_shared
readelf -SW elf_shared
readelf -lW elf_shared
```

`readelf -lW` 最后的 `Section to Segment mapping` 是将两个视图连起来的好工具，但内核不是读取这个工具生成的表格来装载，也不需要靠节名寻找 `.text`。

### 4.2 程序头：如何建立映像

| 程序头类型 | 本次需要理解的事 |
|---|---|
| `PT_LOAD` | 文件的哪段字节映射到哪个虚拟地址范围，大小及权限是什么 |
| `PT_INTERP` | 解释器路径，本机为 `/lib64/ld-linux-x86-64.so.2` |
| `PT_DYNAMIC` | 哪里找到运行时动态标签数组 |
| `PT_PHDR` | 若存在，描述程序头表自身 |
| `PT_GNU_STACK` | 栈权限要求；不是文件中存了一份完整进程栈 |
| `PT_GNU_RELRO` | 动态链接器完成必要修补后可改为只读的范围 |

本次 elf_shared 的最后一个 LOAD：

```text
Type  Offset   VirtAddr           FileSiz MemSiz  Flg Align
LOAD  0x002d78 0x0000000000003d78 0x29c  0x2b0  RW  0x1000
```

逐项解释：

- 文件从 `0x2d78` 起的字节映射到链接虚拟地址 `0x3d78` 对应位置。
- `0x2b0-0x29c=0x14` 字节属于超出文件内容的零填充区；其中包含本例 `.bss` 所需空间。
- 两个起始位置的低页内偏移同为 `0xd78`，并满足这里的 `p_align=0x1000` 对齐约束。
- 实际映射以页为单位，不能把程序头中的非页对齐起点机械等同 `/proc/<pid>/maps` 的映射起点。
- 普通数据映射通常为 RW 而不是 RWX；不要将“可写数据”误讲成“默认也可执行”。[R1]

文件偏移、地址和页边界可以用以下图解释：

```text
文件                                  进程虚拟地址
offset 0x2000 + 0xd78                  B + 0x3000 + 0xd78
             |                                      |
             +------ p_filesz 字节 ------------------+
                                                    +-- 零填充至 p_memsz
```

这里 B 为主程序 load bias。文件 offset 和虚拟地址低位满足对齐，并不要求两个完整数值相等。

> **截图位 S4：** 同屏展示 LOAD 表与 section-to-segment mapping，标出 RW LOAD、`.data/.bss`、filesz/memsz 差以及 RELRO 覆盖范围。

### 4.3 ET_EXEC、ET_DYN、PIE：不能只看文件后缀

| 类型 / 用途 | 本次例子 | 地址理解 |
|---|---|---|
| ET_REL | main.o | 待布局，普通符号值为节内偏移 |
| ET_EXEC | bind_lazy / bind_now | 这里为固定主程序虚拟地址的非 PIE |
| ET_DYN，可执行用途 | elf_archive / elf_shared | PIE，主程序基址可随运行变化 |
| ET_DYN，共享库用途 | libcalc.so | DSO，由动态链接器映射 |

对本例 PIE / DSO 中的普通地址，可以用：

```text
运行时虚拟地址 = load bias + ELF 中的链接虚拟地址
```

ET_DYN 是文件类型，不足以单独判断它是否为共享库、是否有 PT_INTERP、是否必须依赖外部动态链接器，也不是对编译器“每个对象都必须使用 -fPIC”的强制声明。PIE 通常使用 `-fPIE`，共享库通常使用 `-fPIC`；位置无关代码也不等于所有地址永远无需修补。

ASLR 使基址变化，但不改变同一对象内部代码和数据布局的相对关系。共享库与主程序各有自己的 load bias，不能把整个进程看成只有一个统一基址。

### 4.4 哪些信息留给运行时

```bash
readelf -dW elf_shared
readelf --dyn-syms -W elf_shared
readelf -rW elf_shared
```

动态链接器通过程序头找到 PT_DYNAMIC，再根据动态标签找到符号、字符串及重定位等数据，不要求原始节名存在。[R1][R7]

| 动态标签 | 作用 |
|---|---|
| `DT_NEEDED` | 依赖名，是动态字符串表中的索引 |
| `DT_STRTAB` / `DT_STRSZ` | 动态字符串表及大小 |
| `DT_SYMTAB` / `DT_SYMENT` | 动态符号表及项大小；不是普通 `.symtab` |
| `DT_GNU_HASH` / `DT_HASH` | 加速符号查找等所需的哈希信息 |
| `DT_RELA` / `DT_RELASZ` / `DT_RELAENT` | 动态重定位表的地址、长度、项大小 |
| `DT_JMPREL` / `DT_PLTRELSZ` / `DT_PLTREL` | PLT 相关重定位表及格式 |
| `DT_PLTGOT` | 与 GOT / PLT 支持结构相关的地址 |
| `DT_RUNPATH` | 运行时依赖搜索路径 |
| `DT_INIT` / `DT_INIT_ARRAY` 等 | 初始化入口或入口数组 |
| `DT_FLAGS` / `DT_FLAGS_1` | 包括立即绑定、PIE 等标志 |

**拓展实验：普通符号表不是运行的必需品。**

```bash
cp elf_shared elf_stripped
strip --strip-all elf_stripped
readelf -SW elf_stripped
./elf_stripped
```

本次剥离后 `.symtab` 不再出现，`.dynsym` 仍在，程序输出不变。这证明正常运行不依赖完整普通符号表；**不证明 section header table 已被删除**，`strip --strip-all` 在此并没有删除所有节头。

<a id="execve"></a>

## 5. execve：内核建立新的进程映像【必讲】

### 5.1 exec 不等于创建新进程

成功的 `execve(path, argv, envp)` 替换当前进程映像，不回到原来用户程序的调用点。通常 PID 保持；多线程 exec 涉及清理其他线程等更复杂细节，本分享不展开。失败时才以错误返回。[R4]

在 shell 中启动外部命令常见的是“创建子进程，然后子进程 exec”，但这是 shell 的执行策略，不是 execve 自动 fork。旧内存映射被替换；设置 FD_CLOEXEC 的描述符被关闭，其他打开的描述符通常可保留。

### 5.2 内核装载器按什么顺序工作

以 Linux v6.8 的 `fs/exec.c`、`fs/binfmt_elf.c` 为源码导航，可概括为：[R5]

```text
准备执行参数、文件和凭证等
             |
识别二进制格式 -> ELF 格式处理器
             |
检查 ELF / 读取程序头 / 读取 PT_INTERP
             |
切换到新的进程映像，布置地址空间与栈
             |
按 PT_LOAD 映射主程序
按解释器自己的 PT_LOAD 映射解释器
             |
准备 argc / argv / envp / auxv
             |
设置用户态 PC、SP 等寄存器
             |
返回用户态，从解释器入口开始执行
```

这里刻意省略凭证、LSM、线程组、错误回滚边界等细节。需要深入时再看 `linux_binprm`、`begin_new_exec()`、`load_elf_binary()`、`load_elf_interp()`、`create_elf_tables()` 和架构的启动寄存器设置。

**最重要的边界：** 常规动态 ELF 的主程序和解释器由内核映射；`libcalc.so`、libc 等普通依赖随后由用户态动态链接器处理。内核不会在这里替主程序查找 `printf` 的符号定义。

“映射进地址空间”也不等于一次性读入整份文件的全部物理页。文件支持的映射通常通过按需缺页建立实际驻留页；BSS 对应的尾部字节和额外匿名区域需要满足零初始化语义。映射方式、零填充和缺页时机不能混为一谈。

### 5.3 初始栈是内核与启动代码之间的协议

以下是 x86-64 常规启动栈的概念图，省略对齐和若干平台数据：

```text
高地址
    argv/envp 指向的字符串、execfn、随机字节、平台信息等
    ...
    auxv: (AT_NULL, 0)
    auxv: (type, value) ...
    envp 指针 ... NULL
    argv 指针 ... NULL
SP -> argc
低地址
```

argv/envp 是指针数组，其指向的字符串位于其他栈位置；auxv 是类型 / 值对，不是环境变量字符串。

| auxv 项 | 谁需要它 / 传递什么 |
|---|---|
| `AT_PHDR` / `AT_PHNUM` / `AT_PHENT` | 主程序程序头表的运行时地址、数量及项大小 |
| `AT_ENTRY` | 主程序的运行时入口地址 |
| `AT_BASE` | 解释器的装载基址，不是主程序基址 |
| `AT_PAGESZ` | 页大小 |
| `AT_RANDOM` | 指向内核提供的随机字节，供用户态初始化使用 |
| `AT_SECURE` | 安全执行模式相关标志 |
| `AT_SYSINFO_EHDR` | vDSO 映像的入口信息 |

不要把 `AT_ENTRY` 直接当作 main，也不要把 `AT_BASE` 当作所有对象共同的基址。

### 5.4 亲眼看见首次交接

**实验 E4：内核第一次返回用户态时，PC 在哪里？**

从产物目录启动：

```bash
gdb -q -nx ./elf_shared
```

在 GDB 中逐条执行：

```gdb
set pagination off
set debuginfod enabled off
set disable-randomization off
starti
x/i $pc
info auxv
info proc mappings
```

`start` 通常停在 main，已经跨过了本节想观察的过程；这里必须使用 `starti`。GDB 默认可能尝试关闭 ASLR，故显式设置 `disable-randomization off`，保留自然基址变化。无需下载 glibc 调试符号就可以看入口地址与映射。

本次同一运行中的关键实测：

```text
PC in ld.so _start:  0x7f52bad1b540
AT_BASE:            0x7f52bacfc000
AT_ENTRY:           0x56419e6550e0
AT_PHDR:            0x56419e654040
AT_PHENT:           56
AT_PHNUM:           13
```

另一个 shell 中查看：

```bash
readelf -hW elf_shared
readelf -hW /lib64/ld-linux-x86-64.so.2
```

本次主程序 e_entry 为 `0x10e0`，解释器 e_entry 为 `0x1f540`：

```text
解释器初始 PC = AT_BASE + 解释器 e_entry
              = 0x7f52bacfc000 + 0x1f540
              = 0x7f52bad1b540

主程序 load bias = AT_ENTRY - 主程序 e_entry
                 = 0x56419e6550e0 - 0x10e0
                 = 0x56419e654000

AT_PHDR = 主程序 load bias + 0x40
```

此刻 maps 中已存在主程序和 ld.so，还没有本例的 libcalc / libc 依赖映射。地址不同是 ASLR 预期行为；比较关系，不要比较截图里的固定高位。

接着在 GDB 中：

```gdb
tbreak _start
continue
x/i $pc
info proc mappings
tbreak main
continue
p global_counter
p uninitialized_value
```

本次 `_start` 断点停在主程序的 `0x56419e6550e0`，等于 AT_ENTRY；此时映射中已出现 libcalc 与 libc。`_start` 同名符号可能对应多个位置，观察实际停点归属；也可根据**当前这次运行**的 AT_ENTRY 用 `tbreak *地址` 精确设置。

同一运行中，主程序原先的 `0x56419e657000–0x56419e659000 rw-p` 映射拆成了前一页 `r--p`、后一页 `rw-p`。程序头中的 RELRO 范围为 `B+0x3d78` 到 `B+0x4000`，与前一页在完成重定位后变为只读相符；不是整个数据 LOAD 都变为只读。

在 main 起始处，本次两个变量分别为 10 和 0；程序之后才把它们更新成 110 和 3。

> **截图位 S5：** starti 停点 + auxv + 初始 maps，标记解释器 PC 与 AT_ENTRY 不同。
>
> **截图位 S6：** 到达主程序入口后的 maps，与 S5 对照新增的 libcalc / libc，以及 RELRO 区域权限变化。

**观察边界：** `strace` 能跟踪动态链接器发起的 openat / mmap / mprotect 等系统调用，但不能把内核在 execve 内部完成的每个 ELF 映射步骤显示成独立的用户系统调用。

<a id="dynamic-linker"></a>

## 6. 动态链接器：完成运行时未决事项【必讲】

### 6.1 先把依赖库找到

动态链接器本身也必须先达到能够工作的状态，例如完成必要的自举重定位，再解释主程序动态信息、建立对象关系、映射依赖。不要把它想成内核里的一个符号查找函数。

**实验 E5：libcalc.so 从哪里找到？**

```bash
readelf -dW libcalc.so
env -u LD_BIND_NOW -u LD_PRELOAD -u LD_AUDIT \
  LD_DEBUG=libs,reloc,bindings ./elf_shared \
  > loader.stdout 2> loader.log
grep -E 'find library=libcalc|search path=|trying file=' loader.log
```

共享库带有 SONAME `libcalc.so`；主程序的 DT_NEEDED 记录该名字而不是本次构建目录的绝对路径。`$ORIGIN` 在运行时由动态链接器解释为含该动态字符串的程序 / 共享对象所在目录，不能让 shell 提前把它展开掉。

本次日志摘录，长路径和硬件能力候选目录省略：

```text
find library=libcalc.so [0]; searching
 search path=.../program-execution-walkthrough/... (RUNPATH from file ./elf_shared)
```

对于**不含斜线**的常规依赖名，glibc 的搜索规则概括为：[R7]

1. 适用的 DT_RPATH；相关对象存在 DT_RUNPATH 时有不同处理，不能把两者无条件叠加。
2. LD_LIBRARY_PATH，安全执行模式下忽略。
3. 相关请求对象的 DT_RUNPATH，作用于直接依赖，不自动传递到孙依赖。
4. `/etc/ld.so.cache` 中的候选。
5. 平台默认目录；发行版可能使用多架构目录，不能只写死 `/usr/lib`。

实际还受依赖链、硬件能力目录、`-z nodefaultlib` 等影响；需要精确排查时读日志和手册。依赖字符串含斜线时按路径处理，不走上述普通名字查找。也不要混淆构建时 `-L` 与运行时搜索路径：`-L` 本身不会给程序安装一个 RUNPATH。

```bash
strace -o syscalls.log \
  -e trace=execve,openat,mmap,mprotect,brk ./elf_shared
```

对照 loader.log 与 syscalls.log：前者解释库搜索、重定位和绑定意图，后者记录用户态触发的系统调用。mprotect 的出现可以与 RELRO 对照，但不能把每个 mprotect 都简单等同“正在保护 GOT”。

### 6.2 动态重定位：不是所有地址都能在链接时确定

```bash
readelf -rW elf_shared
readelf -rW libcalc.so
```

本次主程序的关键项摘录：

```text
0000000000003d78  R_X86_64_RELATIVE                           11c0
0000000000003fd8  R_X86_64_GLOB_DAT  __libc_start_main@GLIBC_2.34 + 0
0000000000004018  R_X86_64_COPY      uninitialized_value + 0
0000000000004020  R_X86_64_COPY      global_counter + 0
0000000000003fb8  R_X86_64_JUMP_SLOT add + 0
```

上面省略 Info / Value 等列。ET_DYN 中这些 Offset 是对象链接虚拟地址；实际修补位置通常是对象 load bias 加该值，不是文件内偏移。

| 类型 | 核心工作 | 是否通常需要按名找定义 |
|---|---|---|
| RELATIVE | 写入 `B+A` | 不需要普通符号名查找 |
| GLOB_DAT | 将解析后的符号地址写入相应位置，常见于 GOT | 需要，弱未定义等有特殊规则 |
| JUMP_SLOT | 为函数调用的间接槽位建立目标 | 需要，可在允许时延迟 |
| COPY | 从共享对象定义复制初始数据到主程序预留位置 | 需要，细节见拓展 |

动态符号查找不只是“随便打开一个 so，按名字找到地址”。对象的查找作用域、绑定与可见性、符号版本、抢占规则等都会影响结果；哈希表加快查找，但不替代这些语义。本例主要在主程序及其普通启动依赖构成的全局作用域中观察。

RELATIVE 与函数延迟绑定是两回事。即使启用 lazy，大部分非 PLT 动态重定位仍须在启动时完成；数据访问不能等到“第一次函数调用”才处理。

### 6.3 PIC、GOT 与 PLT 各解决什么

PIC 尽量让代码使用相对寻址、间接访问等方式适应装载地址变化。对于可能来自其他对象、运行时才确定的符号，GOT 提供可由动态链接器填入地址的槽位。

概念示意：

```text
访问共享变量：
代码 --相对寻址--> GOT 中的地址槽 --读取指针--> 变量

调用外部函数：
call foo@plt -> PLT 中的指令 -> GOT 对应槽 -> 实际目标
```

不是“全部变量都必须通过 GOT”，也不是“所有动态调用都必须通过 PLT”。对象内部的相对访问、链接器松弛、隐藏符号、`-fno-plt` 等都可能产生其他路径。

共享的通常是文件支持的代码页。修补 GOT 等可写数据页时，各进程有自己的映射和写时复制语义；“库是共享的”不意味着所有进程共享同一个可随意改写的 GOT。

### 6.4 不先验证策略，就无法演示 lazy binding

本文主线 elf_shared 显式设置了 BIND_NOW，不能用它直接演示延迟绑定，因此先准备两个独立对照：

```bash
readelf -hW bind_lazy
readelf -dW bind_lazy
readelf -dW bind_now
readelf -rW bind_lazy
```

二者都显式 `-no-pie`；这只是为了让本节的主程序 GOT 地址无需再加随机基址，**不是延迟绑定要求非 PIE**。共享库依然可以随机映射。构建用同一 binding.o、同一 libcalc.so，分别链接 `-z lazy` 与 `-z now`。

`bind_lazy` 不含 NOW，`bind_now` 含 NOW。实际还需排除 LD_BIND_NOW、LD_BIND_NOT、LD_LIBRARY_PATH、LD_PRELOAD、LD_AUDIT 等对演示的干扰；GDB 脚本会清理这些变量。共享库自身的 NOW 标志不自动把主程序的全部 PLT 重定位改成 NOW。

[binding.c](../../../labs/compiling-linking/walkthrough/binding.c) 的核心逻辑：

```c
binding_checkpoint(0);
int first = add(6, 7);
binding_checkpoint(1);
int second = add(6, 7);
binding_checkpoint(2);
```

这三个停点分别位于首次调用前、两次调用之间、第二次调用后；不在首次调用前打印 add 的地址，也不调用目标函数作“预热”。

### 6.5 读真实 PLT，而不是套固定字节图

```bash
objdump -d -j .plt -j .plt.sec bind_lazy
objdump -d bind_lazy --disassemble=main
```

本次 CET 相关布局的关键片段：

```text
.plt.sec:
401050 <add@plt>:
  401050: endbr64
  401054: jmp *0x2fa6(%rip)    # 404000 <add@Base>

.plt:
401030: endbr64
401034: push $0x0
401039: jmp 401020
```

首次调用前，GOT 槽 `0x404000` 指向 `0x401030`，而不是 `add@plt+6`。传统 PLT 图能帮助建立概念，但布局由工具链和保护特性决定，本机存在拆分的 `.plt.sec` 和 `.plt`。

本例逻辑路径：

```text
第一次：
main -> add@plt (.plt.sec) -> GOT[add]
     -> .plt 中的解析入口 -> PLT0 -> ld.so 解析器
     -> 查找 add / 更新 GOT / 进入真实 add

第二次：
main -> add@plt -> GOT[add] -> libcalc.so 中的 add
```

glibc 源码导航可看 `elf/dl-runtime.c` 的 `_dl_fixup` 及 x86-64 对应的解析跳板；具体跳板名可能随 CPU 特性变化，不要求截图总是出现某一个固定名字。[R6]

### 6.6 观察 GOT 前后值【核心演示】

**实验 E6：同一函数首次与再次调用有什么不同？**

从产物目录执行。以下命令自动从当前二进制提取 add 的槽地址，不写死截图数值：

```bash
set -eu
for mode in lazy now; do
  slot=$(readelf -rW "bind_$mode" |
    awk '$3 == "R_X86_64_JUMP_SLOT" && $5 == "add" {print "0x" $1}')
  test -n "$slot"
  expect=0
  if [ "$mode" = lazy ]; then expect=1; fi
  gdb -q -nx -batch \
    -ex "set \$slot = $slot" \
    -ex "set \$expect_lazy = $expect" \
    -x ../../walkthrough/binding.gdb "bind_$mode" \
    > "binding-$mode.log" 2>&1
  cat "binding-$mode.log"
done
```

脚本 [binding.gdb](../../../labs/compiling-linking/walkthrough/binding.gdb) 在三个断点读取同一个槽位，验证 lazy 首次发生变化、之后不变，以及 NOW 三次值相同；再用 `info symbol` 确认最终目标属于 libcalc.so。

本次实测摘录：

```text
bind_lazy:
before first call: 0x404000 <add@got.plt>: 0x0000000000401030
after first call:  0x404000 <add@got.plt>: 0x00007fefbfb3d0f9
after second call: 0x404000 <add@got.plt>: 0x00007fefbfb3d0f9

bind_now:
before first call: 0x403fe0 <add@got.plt>: 0x00007f7f6829a0f9
after first call:  0x403fe0 <add@got.plt>: 0x00007f7f6829a0f9
after second call: 0x403fe0 <add@got.plt>: 0x00007f7f6829a0f9
```

两个进程的共享库基址不同，绝对函数地址不同是正常的；比较各自运行内部的变化。NOW / lazy 还会影响链接布局，不能要求二者槽地址相同。

也可在交互式 GDB 中用 `x/gx $slot` 看槽内容、`x/i *(void **)$slot` 看目标指令，再反汇编 PLT 串起调用路径。不要在未解析前求助于会改变程序状态的函数调用。

> **截图位 S7：** lazy 的三次槽值，标记“解析入口 → 真实函数 → 真实函数”。
>
> **截图位 S8：** NOW 对照及动态标签，标记“首次调用前已解析”。

**拓展：RELRO 与 NOW。** Full RELRO 常将 RELRO 与 NOW 结合，使需要启动时写入的 GOT 相关区域在之后可只读。Lazy 需要保留相应槽位可更新；具体哪些地址进入 RELRO，要读程序头和运行时 maps，不能简单断言“整个 GOT 永远可写”或“整个 GOT 永远只读”。

### 6.7 为什么主程序里出现了共享变量的存储【拓展】

本例 elf_shared 中对 `global_counter`、`uninitialized_value` 出现 COPY 重定位。这说明不能把“动态库变量一定存放在共享库自己的数据区，主程序只拿一个地址”当作普遍事实。

在这个具体构建中，链接器在主程序中预留对象空间，动态链接器将共享库提供的初值复制过来；正常符号抢占规则还使共享库内部针对这些符号的引用可绑定到主程序副本，从而使双方观察到同一份有效状态。

用证据区分两种动作：

```bash
nm -D elf_shared | grep -E 'global_counter|uninitialized_value'
readelf -rW elf_shared
grep -E 'binding file .*symbol .(global_counter|uninitialized_value)' loader.log
```

本次日志同时出现“库的 global_counter 引用绑定到主程序”与“主程序为复制初值在库中找到 global_counter 定义”的记录。不要把它们当作互相矛盾的重复查找。

COPY 有大小、可见性和 ABI 演化等问题。本次只用它解释真实实验现象；不推广成所有 PIE 或所有共享变量访问都使用 COPY。修改代码生成选项可以产生不同访问路径，需另做对照才能下结论。

<a id="startup-to-main"></a>

## 7. 从动态链接器到 main【必讲】

### 7.1 主程序入口不是 main

```bash
readelf -hW elf_shared
objdump -d elf_shared --disassemble=_start
```

本次入口为 `0x10e0`，对应 `_start`；main 在 `0x11c9`。启动代码关键指令摘录：

```text
10e9: pop %rsi                   # argc
10ea: mov %rsp,%rdx              # argv
10ed: and $0xfffffffffffffff0,%rsp
...
10f8: lea ...,%rdi               # main 的地址
10ff: call *...(%rip)            # __libc_start_main@GLIBC_2.34
```

这里是对实测反汇编的注解，不是完整启动代码。`_start` 按 ABI 从初始栈获取参数、调整栈对齐，把 main 等信息交给 libc。main 的普通 C 调用环境由用户态启动代码建立，不是内核直接做了一次 `call main`。[R6]

`__libc_start_main` 的地址来自启动阶段处理的 GOT，这里不是一个等待业务代码首次调用才解析的普通 lazy PLT 示例。

### 7.2 构造函数到底由谁调用

对于本次新构建的 glibc 2.39 动态程序，可用下图理解正常路径；特殊对象、旧版启动方式和循环依赖不在此图范围：

```text
内核 -> ld.so 入口
          自举 / 加载依赖 / 必要重定位与线程相关初始化
          _dl_init
            主程序 preinit 数组（若有）
            依赖共享对象的 init / init_array
       -> 主程序 _start
       -> __libc_start_main
            主程序 init / init_array
       -> main
       -> exit 路径
```

关键版本依据：

- glibc 2.39 `elf/dl-init.c` 的 `_dl_init` 处理主程序 preinit 及依赖初始化；其 `call_init` 跳过普通主可执行对象。
- `csu/libc-start.c` 中，现代启动代码传入空的旧式 init 参数时，由 `__libc_start_main` 内部的 `call_init` 执行主程序初始化。
- 因而不能泛泛讲成“所有构造函数都在主程序 `_start` 之前由 ld.so 执行”。[R6]

### 7.3 用调用栈验证，而不只看打印顺序

**实验 E7：观察两类构造函数和 main。**

```bash
./startup
LD_DEBUG=libs ./startup > startup.stdout 2> startup.log
```

本次输出：

```text
library constructor
program constructor
main: add=13
```

随后从产物目录启动 `gdb -q -nx ./startup`，执行：

```gdb
set pagination off
set debuginfod enabled off
set disable-randomization off
set breakpoint pending on
break library_ctor
break program_ctor
break main
run
bt
continue
bt
continue
bt
continue
```

共享库尚未加载时 library_ctor 的 pending 断点是预期行为。以下是本次调用栈的**关键函数链摘录**，省略地址与优化相关帧：

```text
library_ctor
  <- call_init
  <- _dl_init
  <- _dl_start_user

program_ctor
  <- call_init
  <- __libc_start_main_impl
  <- _start
```

当前容器已有与 libc 匹配的 `libc6-dbg 2.39-0ubuntu8.9`，关闭 debuginfod 后仍能显示上述内部函数及 `dl-init.c` / `libc-start.c` 源位置；不需要联网下载符号。别的机器没有调试信息时，仍能在自编译的构造函数断点停住，系统库帧可能只有地址或 `??`。此时把准确内部调用者作为源码解释，不伪造本机 GDB 输出。

两个地方都叫 `call_init`，但属于不同组件；要结合所属对象和调用者理解。main 停点的 `bt` 也可能只显示 main 等有限帧，不能强求每个环境都能完整展开最早启动栈。

> **截图位 S9：** library_ctor 和 program_ctor 的两张调用栈并排，框出 `_dl_init` 与 `__libc_start_main_impl`；辅助显示三个打印的顺序。

### 7.4 回答开头的三个问题

| 问题 | 归档版本 | 共享库版本 |
|---|---|---|
| add 的实现在哪里？ | calc.o 被提取后进入主程序，调用位移在链接时确定 | 主程序保留动态引用，启动时或首次调用时解析到 libcalc |
| global_counter 如何定位？ | 主程序布局给出位置，内部访问可用相对寻址 | 依代码生成和动态重定位处理；本例有 COPY，实际状态在主程序副本 |
| printf 从哪里来？ | 仍由 libc 共享库提供 | 同样由 libc 共享库提供 |

最后补上启动问题：

```text
.o：描述我有什么、我引用谁、哪里还需修补
链接器：布局并解决构建时能解决的问题
内核：按 ELF 装载说明建立新映像和启动协议
ld.so：完成运行时依赖连接与部分初始化
_start / libc：建立 C 运行环境并调用 main
```

main 返回后，正常 libc 启动路径会进入退出处理，执行相应退出回调 / 析构并最终终止进程；不展开把程序运行讲成“main 返回就重新跳回内核最初的 execve 调用点”。

<a id="experiment-index"></a>

## 附录 A：实验与截图索引

| 实验 | 提问与最小证据 | 截图位置 |
|---|---|---|
| E1 | readelf 的节、符号、重定位与 objdump 的引用字段相互对应 | S1、S2 |
| E2 | ar 成员与 map 证明成员提取；手算位移与最终字节一致 | S3 |
| E3 | NEEDED 区分归档 / 共享依赖；程序输出一致 | 可贴两份动态标签对照 |
| ELF 双视图 | LOAD 与节映射、filesz/memsz、权限 | S4 |
| E4 | starti 在 ld.so、auxv、主程序入口和映射变化 | S5、S6 |
| E5 | LD_DEBUG 解释依赖选择；strace 补充系统调用证据 | 可贴搜索路径与 mmap |
| E6 | lazy 第一次回填与 NOW 启动前解析 | S7、S8 |
| E7 | 两类构造函数的调用者与 main | S9 |

现场输出过长时保存到文件，再提取相关区间。不要用 `head` 截断后误以为没有其他符号，也不要将日志中搜索过但不存在的候选路径当成实际加载路径。

截图建议只展示相关命令、停点和关键输出，去掉无关路径、环境变量、身份信息；不要展示完整 envp 或实际随机字节内容。正文保留文字结论，即使图片缺失也能阅读。

## 附录 B：地址与重定位速查

| 概念 | 本文示例 | 能否直接当运行时指针 |
|---|---|---|
| 文件偏移 | main.o 的 `.text` 位于文件 `0x40` | 不能 |
| 节内偏移 | main.o 的调用位移字段在 `.text+0x34` | 不能 |
| 链接虚拟地址 | elf_archive 的 add 为 `0x1238` | PIE 还需加对象 load bias |
| 运行时虚拟地址 | AT_ENTRY 显示的地址 | 是该次运行中的有效虚拟地址，但仍须考虑对象范围和权限 |
| GOT 槽地址 | bind_lazy 中的 `0x404000` | 指向地址槽，不等于槽中保存的函数地址 |

本篇使用的 AMD64 重定位记号：[R2]

```text
S = 符号解析后的值
A = 加数
P = 被修补位置的地址
L = 符号对应的 PLT 项地址
B = 当前对象的装载基址 / load bias

R_X86_64_PC32      S + A - P
R_X86_64_PLT32     L + A - P
R_X86_64_RELATIVE  B + A
R_X86_64_GLOB_DAT  S
R_X86_64_JUMP_SLOT S
```

这些是特定类型的语义，不是所有重定位都写入完整的 64 位绝对地址；还涉及字段宽度、范围校验、符号特殊属性和链接器优化。本文只对直接绑定 add 的具体结果作手算。

## 附录 C：常见误区与继续深入

| 不准确的说法 | 应怎样限定 |
|---|---|
| `.o` 没有机器码 | 通常已有机器码，但部分引用仍需修补 |
| 静态库是一种 ELF | `.a` 是归档，其成员通常为 ELF `.o` |
| 名为 elf_static 就没有动态依赖 | 检查 PT_INTERP / NEEDED，且显式保证归档选择 |
| `.o` 的 UND 都必须从另一份 `.o` 立刻解决 | 动态链接输出可以为运行时保留必要引用 |
| 符号 Value 总是 0 / 总是最终地址 | 依对象类型和符号类别解释 |
| 内核把所有节全部复制进内存 | 主要按程序头建立映射，不按节名装载整个文件 |
| 程序总从 e_entry 对应代码开始，那里就是 main | 有解释器时首先进入解释器；主程序入口通常为 `_start` |
| 开 lazy 就不做启动重定位 | 只允许特定函数绑定延迟，其他必要处理仍要完成 |
| GOT 第一次一定指向 foo@plt+6 | 读取当前工具链实际 PLT 布局 |
| 所有构造函数都由 ld.so 在 `_start` 前调用 | 区分对象种类与 glibc 启动版本 |

适合另开分享的拓展：

- **链接编辑器实现：** GNU ld / BFD 的符号状态、节布局和架构重定位回调，承接已有 linker 笔记。
- **符号语义：** 强弱符号、可见性、符号版本、抢占；现代 GCC 的 `-fno-common` 与历史 COMMON 行为。
- **代码生成比较：** `-fPIC`、`-fPIE`、`-fno-plt`、隐藏符号与 GOTPCREL 松弛；必须对比实物，不能只看编译参数名。
- **更复杂启动：** 静态 PIE 自重定位、TLS、IFUNC、审计、dlopen 与构造依赖；它们不改变本文的职责划分，但会增加阶段细节。
- **内存管理：** VMA、页表、文件页缓存、写时复制与缺页；本文只介绍理解装载所需的部分。

## 附录 D：复现核对清单

以下为演讲前的操作清单，不要求现场完整展示：

1. 从仓库根目录运行 walkthrough 的 make，而不是依赖外部目录旧产物；迁移或切换工具链后用 `make -B` 强制重建，确认编译没有警告或错误。
2. 记录 gcc、ld、glibc、内核版本；readelf 核对架构、PIE、NOW、RUNPATH、NEEDED。
3. 运行 elf_archive 与 elf_shared，确认加法 13、乘法 42、计数器 110、未初始化变量更新为 3。
4. 用 nm / map / objdump 验证 add 的输入、输出地址和实际位移；地址变动后重新计算。
5. 运行 E6，确认 lazy 首次变化、第二次不变，NOW 三次相同，最终目标是 libcalc 的 add。
6. 用 starti 验证 PC 位于解释器，按当次 auxv 对照主程序入口；不要沿用前次地址。
7. 运行 startup，验证构造函数与 main 的顺序；有调试信息时对照调用栈。
8. 完全静态与 strip 拓展单独执行；依赖不足或环境限制必须如实标注。

### 当前容器复验记录（2026-10-28）

以下均在当前容器实际执行，不是仅替换版本号；没有修改实验源码或构建选项来迎合旧输出。

| 范围 | 本轮结果 / 关键证据 |
|---|---|
| 默认构建与第 1 章分步构建 | `make -B ... all optional-static` 及 chapter1 中的预处理、编译、汇编、归档、共享链接均成功，无编译警告 |
| E1 / E2：对象与构建时链接 | `.text` 大小仍为 `0xcf`；add 重定位字段 `0x34`；归档成员触发符号为 global_counter；最终 `0x1238-4-0x119d=0x97` 与机器码一致 |
| E3：依赖与输出 | archive 仅 NEEDED libc，共享版另需 libcalc；两者均输出 13、42、110、3，保存于 `archive.stdout` / `shared.stdout` |
| ELF 双视图 | RW LOAD 的 filesz / memsz 仍为 `0x29c` / `0x2b0`；NEEDED、NOW、RUNPATH、COPY 重定位均已重新核对；静态检查记录于 `container-elf.log` |
| E4：首次交接 | `entry.log`：starti 位于 ld.so，PC 等于 AT_BASE 加解释器入口；主程序入口等于 AT_ENTRY；依赖映射及 RELRO 权限变化可见，main 停点变量为 10 / 0 |
| E5：查库与系统调用 | `loader.log` 使用 `$ORIGIN` RUNPATH 找到 libcalc，并记录 COPY 双向绑定；`syscalls.log` 记录成功的 openat / mmap / mprotect，进程以 0 退出 |
| E6：lazy / NOW | `binding-lazy.log` / `binding-now.log` 的原脚本断言均通过；lazy 仅首次改变槽值，NOW 三次相同，最终目标均为 libcalc.so 的 add |
| E7：启动初始化 | `startup.stdout` 顺序为 library constructor、program constructor、main；`startup-gdb.log` 中调用者分别为 `_dl_init` 和 `__libc_start_main_impl` |
| 完全静态与 strip 拓展 | 静态程序无 INTERP / 动态节；strip 后无 `.symtab`、仍有 `.dynsym`；`static.stdout` / `stripped.stdout` 与共享版输出逐字节一致 |

构建产物及本轮日志留在隔离输出目录，不纳入版本控制；第 1 章产物位于其 chapter1 子目录。重新构建不会自动重新采集日志，需执行各节观察命令；上述日志名用于定位本轮证据，交互式 GDB 会话也可自行保存。正文截图位置仍是待演讲者替换的占位，不是假称已生成截图。

## 参考资料与版本

正文解释以公开规范、手册和固定版本源码为依据；只复述相关机制，不将历史 ELF32 示例直接套用到现代 x86-64。

- **[R1] System V gABI**：[目录](https://www.sco.com/developers/gabi/latest/contents.html)、[符号表](https://www.sco.com/developers/gabi/latest/ch4.symtab.html)、[程序头](https://www.sco.com/developers/gabi/latest/ch5.pheader.html)、[动态链接](https://www.sco.com/developers/gabi/latest/ch5.dynamic.html)。用于通用 ELF64 结构与语义，平台细节需配合 AMD64 ABI。
- **[R2] AMD64 psABI**：[项目](https://gitlab.com/x86-psABIs/x86-64-ABI)，核验版本为 commit [`e1ce098331da5dbd66e1ffc74162380bcc213236`](https://gitlab.com/x86-psABIs/x86-64-ABI/-/commit/e1ce098331da5dbd66e1ffc74162380bcc213236)，重点为 [`x86-64-ABI/object-files.tex`](https://gitlab.com/x86-psABIs/x86-64-ABI/-/blob/e1ce098331da5dbd66e1ffc74162380bcc213236/x86-64-ABI/object-files.tex) 中的重定位定义。
- **[R3] GNU ld**：[命令行选项](https://sourceware.org/binutils/docs/ld/Options.html)、[链接脚本](https://sourceware.org/binutils/docs/ld/Scripts.html)。在线文档可能更新；本地实测链接器为 2.42。
- **[R4] Linux man-pages**：[`execve(2)`](https://man7.org/linux/man-pages/man2/execve.2.html)、[`getauxval(3)`](https://man7.org/linux/man-pages/man3/getauxval.3.html)、[`proc_pid_maps(5)`](https://man7.org/linux/man-pages/man5/proc_pid_maps.5.html)。
- **[R5] Linux v6.8 源码**：[`fs/exec.c`](https://github.com/torvalds/linux/blob/v6.8/fs/exec.c)、[`fs/binfmt_elf.c`](https://github.com/torvalds/linux/blob/v6.8/fs/binfmt_elf.c)。重点关注 load_elf_binary、load_elf_interp、create_elf_tables 和用户入口设置。
- **[R6] glibc 2.39 源码**：[`sysdeps/x86_64/start.S`](https://github.com/bminor/glibc/blob/glibc-2.39/sysdeps/x86_64/start.S)、[`csu/libc-start.c`](https://github.com/bminor/glibc/blob/glibc-2.39/csu/libc-start.c)、[`elf/dl-init.c`](https://github.com/bminor/glibc/blob/glibc-2.39/elf/dl-init.c)、[`elf/rtld.c`](https://github.com/bminor/glibc/blob/glibc-2.39/elf/rtld.c)、[`elf/dl-runtime.c`](https://github.com/bminor/glibc/blob/glibc-2.39/elf/dl-runtime.c)。区分启动汇编、加载器初始化、libc 初始化与延迟绑定。
- **[R7] 动态链接器手册**：[`ld.so(8)`](https://man7.org/linux/man-pages/man8/ld.so.8.html)。用于搜索顺序、动态字符串、安全执行模式与 LD_BIND_NOW / LD_DEBUG 等环境变量的适用条件。
