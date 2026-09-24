# \*.c -> elf

`~/workspace/compiling_lab`下所有文件类型：  

| 文件               | 文件类型         | 生成方式                         | 主要内容与作用                                                                                    |
| ---------------- | ------------ | ---------------------------- | ------------------------------------------------------------------------------------------ |
| `main.i`         | 预处理结果，文本文件   | `gcc -E main.c`              | 展开 `#include`、宏定义和条件编译后的 `main.c`。仍是 C 语言代码，通常用于检查头文件展开和宏替换结果。                             |
| `calc.i`         | 预处理结果，文本文件   | `gcc -E calc.c`              | 展开 `calc.c` 中的头文件、宏和条件编译内容。                                                                |
| `main.s`         | 汇编代码，文本文件    | `gcc -S main.c`              | `main.c` 编译生成的 x86-64 汇编代码。由于启用了 `-O0 -g`，其中通常还包含较完整的调试信息指令。                               |
| `calc.s`         | 汇编代码，文本文件    | `gcc -S calc.c`              | `calc.c` 编译生成的 x86-64 汇编代码。                                                                |
| `main.o`         | ELF 可重定位目标文件 | `gcc -c main.c`              | 包含 `main` 的机器码、数据、符号表、重定位表和调试信息。对 `add`、`multiply`、`global_counter`、`printf` 等符号的引用尚未全部解析。 |
| `calc.o`         | ELF 可重定位目标文件 | `gcc -c calc.c`              | 包含普通非 PIC 形式的计算函数和全局变量定义，用来构建静态库。                                                          |
| `calc.pic.o`     | ELF 可重定位目标文件 | `gcc -fPIC -c calc.c`        | 包含位置无关代码，供构建共享库使用。与 `calc.o` 的主要区别是外部符号访问和地址计算方式适用于共享对象的任意加载地址。                            |
| `libcalc.a`      | 静态归档库        | `ar rcs libcalc.a calc.o`    | 静态库，本质上是包含 `calc.o` 的归档文件。静态链接时，链接器按未解析符号从中提取需要的目标文件成员。                                    |
| `libcalc.so`     | ELF 共享对象     | `gcc -shared ... calc.pic.o` | 动态共享库，包含 `calc` 模块的代码和数据。其 SONAME 被设置为 `libcalc.so`，运行时由动态链接器加载。                           |
| `elf_static`     | ELF 可执行文件    | `gcc main.o -L. -lcalc`      | 使用 `libcalc.a` 提供 `calc` 相关符号的可执行文件。`calc.o` 的代码被复制进入该文件，但 libc 默认仍是动态链接的。                 |
| `elf_static.map` | 链接映射文件，文本文件  | 链接 `elf_static` 时由 `ld` 生成   | 记录静态库成员提取原因、输入 section 合并过程、符号地址、输出 section 布局、丢弃 section、PLT/GOT 和动态库依赖等链接结果。             |
| `elf_shared`     | ELF 可执行文件    | `gcc main.o -L. -lcalc`      | 使用 `libcalc.so` 的动态链接可执行文件。不会复制 `calc` 的主体代码，而是记录对 `libcalc.so` 的运行时依赖。                    |
| `elf_shared.map` | 链接映射文件，文本文件  | 链接 `elf_shared` 时由 `ld` 生成   | 记录动态链接版本的 section 布局、符号解析、动态依赖、PLT/GOT 及动态重定位结构。                                           |

## preprocessing

[preprocessor-output](https://gcc.gnu.org/onlinedocs/cpp/Preprocessor-Output.html)  

预处理过程将：  

- 所有预处理指令将被展开(处理后替换为空行)，包含：
    - `#include`
    - `#define`
    - `#if defined()`
    - `endif`
- 丢弃所有注释
- 过长的空行将被丢弃
- 添加`inemarkers`, 格式为`# linenum filename flags`



| 项目 | 说明 |
|---|---|
| 名称 | linemarkers（行标记） |
| 插入位置 | 按需插入到输出中（但绝不会出现在字符串或字符常量内） |
| 含义 | 表示下一行内容来自文件 filename 的第 linenum 行 |
| filename 限制 | 不含任何非打印字符；如有则替换为八进制转义序列 |
| flags数量 | 文件名后跟零个或多个标志 |
| flags取值 | ‘1’、‘2’、‘3’、‘4’ |
| 多flags分隔 | 用空格分隔 |

| flags | 含义 |
|---|---|
| ‘1’ | 表示一个新文件的开始 |
| ‘2’ | 表示返回到某个文件（在包含其他文件之后） |
| ‘3’ | 表示后续文本来自系统头文件，应抑制某些警告 |
| ‘4’ | 表示后续文本应被视为包裹在隐式的 extern "C" 块中 |

输出格式如下:  

```c
# 4 "calc.h"
extern int global_counter;
extern int uninitialized_value;

int add(int a, int b);
int multiply(int a, int b);
void update_counter(int value);
# 3 "main.c" 2


static int local_data = 100;


static const char message[] = "ELF compilation and linking laboratory";

int main(void)
{
    int x = 6;
    int y = 7;
```

## compile

[gnu_assembler](https://ftp.gnu.org/old-gnu/Manuals/gas-2.9.1/html_chapter/as_toc.html)  

形成一份汇编代码：  
```asm

	.file	"main.c"
	.text
.Ltext0:
	.file 0 "/home/zoe/workspace/complie_lab" "main.c"
	.data
	.align 4
	.type	local_data, @object
	.size	local_data, 4
local_data:
	.long	100
	.section	.rodata
	.align 32
	.type	message, @object
	.size	message, 39
message:
	.string	"ELF compilation and linking laboratory"
.LC0:
	.string	"add(%d, %d) = %d\n"
.LC1:
	.string	"multiply(%d, %d) = %d\n"
.LC2:
	.string	"global_counter = %d\n"
.LC3:
	.string	"uninitialized_value = %d\n"
	.text
	.globl	main
	.type	main, @function
main:
.LFB0:
	.file 1 "main.c"
	.loc 1 11 1
	.cfi_startproc

```

此时可以看到`	call	add@PLT`这类对外部函数的调用。此时编译器并不知道函数的最终地址，只生成符号引用。  

常见的语法规范如下：  

| 分类         | 语法或示例                                   | 作用                           | 对 ELF `.o` 的主要影响           |
| ---------- | --------------------------------------- | ---------------------------- | -------------------------- |
| 源文件信息      | `.file "main.c"`                        | 记录源文件名称                      | 生成调试和文件元数据                 |
| 源文件表       | `.file 1 "main.c"`                      | 为源文件分配编号，供 `.loc` 引用         | 参与生成 DWARF 调试信息            |
| 源码位置       | `.loc 1 11 1`                           | 指定后续指令对应文件 1、第 11 行、第 1 列    | 生成 `.debug_line` 内容        |
| 切换代码节      | `.text`                                 | 将后续指令或数据放入 `.text` 节         | 创建或选择可执行代码节                |
| 切换数据节      | `.data`                                 | 将后续数据放入 `.data` 节            | 创建或选择已初始化可写数据节             |
| 切换只读节      | `.section .rodata`                      | 将后续内容放入指定节                   | 创建或选择只读数据节                 |
| 切换 BSS 节   | `.bss`                                  | 放置未初始化或零初始化数据                | 生成通常不占文件内容的 `SHT_NOBITS` 节 |
| 通用节定义      | `.section name,"flags",@type`           | 创建或切换节，并指定属性和类型              | 精确控制 ELF Section Header    |
| 恢复前一节      | `.previous`                             | 返回进入当前节之前的节                  | 改变后续内容所属节区                 |
| 节栈操作       | `.pushsection name`                     | 保存当前节并切换新节                   | 改变当前输出节                    |
| 节栈操作       | `.popsection`                           | 恢复由 `.pushsection` 保存的节      | 恢复当前输出节                    |
| 字节对齐       | `.align 4`                              | 将当前位置推进到目标相关的对齐边界            | 在节内插入填充字节                  |
| 明确字节对齐     | `.balign 16`                            | 按 16 字节边界对齐                  | 比 `.align` 的跨架构语义更明确       |
| 2 的幂对齐     | `.p2align 4`                            | 按 `2^4 = 16` 字节对齐            | 常用于函数和循环入口对齐               |
| 全局符号       | `.globl main`                           | 将符号声明为全局可见                   | 符号绑定通常为 `STB_GLOBAL`       |
| 弱符号        | `.weak symbol`                          | 声明可被强符号覆盖的弱符号                | 符号绑定为 `STB_WEAK`           |
| 隐藏符号       | `.hidden symbol`                        | 限制符号对其他动态对象的可见性              | ELF 可见性为 `STV_HIDDEN`      |
| 内部符号       | `.local symbol`                         | 将符号声明为当前目标文件的局部符号            | 符号绑定为 `STB_LOCAL`          |
| 函数类型       | `.type main, @function`                 | 声明 `main` 是函数                | 符号类型为 `STT_FUNC`           |
| 对象类型       | `.type local_data, @object`             | 声明符号是数据对象                    | 符号类型为 `STT_OBJECT`         |
| 符号大小       | `.size local_data, 4`                   | 指定对象占 4 字节                   | 设置符号表中的 `st_size`          |
| 函数大小       | `.size main, .-main`                    | 用当前位置减函数起始位置计算函数大小           | 设置函数符号的 `st_size`          |
| 符号别名       | `.set alias, symbol`                    | 将一个符号定义为另一个符号或表达式            | 建立符号值或别名关系                 |
| 常量定义       | `.equ SIZE, 16`                         | 定义汇编期常量                      | 通常不分配存储空间                  |
| 标签         | `main:`                                 | 将符号绑定到当前位置                   | 生成符号及其节内偏移                 |
| 局部标签       | `.LC0:`、`.LFB0:`                        | 编译器内部使用的局部符号                 | 通常不会保留到最终普通符号表             |
| 数字局部标签     | `1:`、`1f`、`1b`                          | 定义可重复使用的局部标签；`f` 向前、`b` 向后引用 | 用于当前汇编单元内部跳转               |
| 1 字节数据     | `.byte 0xff`                            | 写入一个字节                       | 直接增加当前节内容                  |
| 2 字节数据     | `.short 100`                            | 写入通常为 2 字节的整数                | 直接增加当前节内容                  |
| 4 字节数据     | `.long 100`                             | 写入通常为 4 字节的整数                | 例如生成 `.data` 中的整型对象        |
| 8 字节数据     | `.quad symbol`                          | 写入 8 字节整数或地址表达式              | 符号地址未确定时产生重定位项             |
| 零结尾字符串     | `.string "text"`                        | 写入字符串并追加 `\0`                | 常用于 `.rodata`              |
| 零结尾字符串     | `.asciz "text"`                         | 与常见目标上的 `.string` 类似，追加 `\0` | 常用于 C 字符串                  |
| 原始字符串      | `.ascii "text"`                         | 写入字符串但不追加 `\0`               | 直接增加当前节内容                  |
| 保留空间       | `.zero 16`                              | 写入或保留 16 个零字节                | 在当前节分配空间                   |
| 填充空间       | `.space 16, 0`                          | 分配 16 字节并使用指定值填充             | 增加当前节大小和内容                 |
| 公共符号       | `.comm buf, 64, 16`                     | 定义未初始化的公共对象及其对齐              | 链接后通常进入 `.bss`             |
| 局部公共符号     | `.lcomm buf, 64`                        | 定义当前文件局部的未初始化对象              | 通常进入 `.bss`，绑定为局部          |
| 函数 CFI 开始  | `.cfi_startproc`                        | 开始描述一个函数的调用帧信息               | 通常开始生成 `.eh_frame` 记录      |
| 函数 CFI 结束  | `.cfi_endproc`                          | 结束当前函数的调用帧描述                 | 完成对应的栈展开记录                 |
| 定义 CFA     | `.cfi_def_cfa %rsp, 8`                  | 指定规范帧地址使用的寄存器和偏移             | 生成栈展开信息                    |
| 修改 CFA 偏移  | `.cfi_def_cfa_offset 16`                | 更新 CFA 相对当前寄存器的偏移            | 反映 `push` 等栈操作             |
| 修改 CFA 寄存器 | `.cfi_def_cfa_register %rbp`            | 修改计算 CFA 使用的基础寄存器            | 反映帧指针建立过程                  |
| 保存寄存器位置    | `.cfi_offset %rbp, -16`                 | 描述寄存器旧值保存在 CFA 的哪个偏移处        | 供调试器和展开器恢复寄存器              |
| 恢复寄存器规则    | `.cfi_restore %rbp`                     | 恢复寄存器之前的展开规则                 | 更新 `.eh_frame` 中的规则        |
| 调用帧状态      | `.cfi_remember_state`                   | 暂存当前 CFI 状态                  | 常用于函数多条退出路径                |
| 调用帧状态      | `.cfi_restore_state`                    | 恢复之前保存的 CFI 状态               | 简化复杂控制流中的展开描述              |
| 标识器        | `.ident "GCC: ..."`                     | 记录编译工具链标识字符串                 | 通常生成 `.comment` 节          |
| 禁止可执行栈     | `.section .note.GNU-stack,"",@progbits` | 声明目标文件不要求可执行栈                | 影响链接后栈的执行权限                |
| 栈保存指令      | `pushq %rbp`                            | 将 64 位寄存器压入栈中                | 在 `.text` 中生成机器码           |
| 数据移动指令     | `movq %rsp, %rbp`                       | 将栈指针复制到帧指针                   | 生成函数栈帧相关机器码                |
| 函数调用指令     | `call add`                              | 调用函数；地址尚未确定时引用符号             | 通常产生针对 `add` 的重定位项         |
| 返回指令       | `ret`                                   | 从当前函数返回调用者                   | 生成返回机器码                    |
| 间接分支保护     | `endbr64`                               | Intel CET 间接分支目标标记           | 在 `.text` 中生成实际机器指令        |
| ----------------- | -------------------------------------- | ------------------------------------------------------------- | ------------------------------------------------------------------------------------- |
| 2 字节数据            | `.value 0x5`                           | 在当前节写入一个 16 位数值；在 GNU GAS 常见目标上等价于生成 2 字节整数                   | 增加当前节内容，常用于 DWARF 版本号等字段                                                              |
| 无符号变长整数           | `.uleb128 0x24`                        | 使用 ULEB128 编码写入无符号整数，数值越小通常占用越少字节                             | 常用于 `.debug_info`、`.debug_abbrev` 等 DWARF 节 [\[sourceware.org\]](https://sourceware.org/binutils/docs-2.45/as/Uleb128.html) |
| 有符号变长整数           | `.sleb128 -24`                         | 使用 SLEB128 编码写入有符号整数，并保留符号信息                                  | 常用于 DWARF 位置偏移、常量及表达式                                                                 |
| ELF 节属性           | `.section .debug_info,"",@progbits`    | 创建或切换到 `.debug_info`；空字符串表示未指定额外标志，`@progbits` 表示该节包含实际字节内容   | 生成类型为 `SHT_PROGBITS` 的 ELF 节                                                          |
| 可分组字符串节           | `.section .debug_str,"MS",@progbits,1` | 创建可合并、以字符串结尾的节；最后的 `1` 是每个条目的实体大小                             | 生成带 `SHF_MERGE`、`SHF_STRINGS` 标志的字符串节                                                 |
| 可分配节              | `.section .note.gnu.property,"a"`      | `a` 表示该节在运行时需要分配到进程地址空间                                       | 设置 ELF `SHF_ALLOC` 标志                                                                 |
| 合并节标志             | `M`                                    | 表示链接器可以合并内容相同的条目                                              | 设置 `SHF_MERGE`                                                                        |
| 字符串节标志            | `S`                                    | 表示节内容由零结尾字符串组成                                                | 设置 `SHF_STRINGS`，通常与 `M` 一起使用                                                         |
| 可分配标志             | `a`                                    | 表示节应出现在运行时内存映射中                                               | 设置 `SHF_ALLOC`                                                                        |
| 节实体大小             | `.section ...,1`                       | 指定可合并节中每个实体的大小；字符串节通常设为 1 字节字符宽度                              | 写入 Section Header 的 `sh_entsize`                                                      |
| 调试信息节             | `.debug_info`                          | 存放 DWARF 编译单元、类型、变量和函数等调试信息                                   | 生成 DWARF Debugging Information Entry 数据                                               |
| 调试缩写节             | `.debug_abbrev`                        | 存放 `.debug_info` 使用的 DIE 缩写声明                                 | 减少 DWARF 属性描述的重复编码                                                                    |
| 调试地址范围节           | `.debug_aranges`                       | 建立机器码地址范围到编译单元的快速索引                                           | 便于调试器按地址定位编译单元                                                                        |
| 调试行号节             | `.debug_line`                          | 存放地址与源文件、行号、列号之间的映射                                           | `.file` 和 `.loc` 会驱动 GAS 生成该节                                                         |
| 调试字符串节            | `.debug_str`                           | 集中保存 DWARF 使用的字符串                                             | DWARF 属性通常通过偏移引用其中字符串                                                                 |
| 行号字符串节            | `.debug_line_str`                      | 保存 DWARF 行号表使用的文件名和目录字符串                                      | 常见于 DWARF 5                                                                           |
| 当前位置符号            | `.`                                    | 表示当前节中的当前位置计数器                                                | 可用于计算对象、函数或地址范围大小                                                                     |
| 地址差表达式            | `.Letext0-.Ltext0`                     | 计算两个局部标签之间的距离                                                 | 若汇编时可解析，直接写入差值，通常不产生动态重定位                                                             |
| 前向数字标签            | `1f`、`3f`、`4f`                         | 引用后面最近的同编号数字标签；`f` 表示 forward                                 | GAS 在汇编时解析为局部地址                                                                       |
| 后向数字标签            | `1b`、`3b`                              | 引用前面最近的同编号数字标签；`b` 表示 backward                                | GAS 在汇编时解析为局部地址                                                                       |
| ELF Note 名称大小     | `.long 1f - 0f`                        | 通过数字局部标签计算 Note 名称字段长度                                        | 写入 ELF Note 的 `namesz`                                                                |
| ELF Note 描述大小     | `.long 4f - 1f`                        | 计算 ELF Note 描述区域的长度                                           | 写入 ELF Note 的 `descsz`                                                                |
| ELF Note 类型       | `.long 5`                              | 写入 Note 类型号                                                   | 在 `.note.gnu.property` 中表示 GNU Property Note                                          |
| GNU 属性类型          | `.long 0xc0000002`                     | 写入 GNU x86 功能属性类型标识                                           | 用于描述 x86 CET 等处理器特性                                                                   |
| 编译器标识             | `.ident "GCC: ..."`                    | 把编译器版本字符串写入目标文件                                               | 通常生成或追加到 `.comment` 节                                                                 |
| ELF Stack Note    | `.note.GNU-stack`                      | 声明目标文件是否需要可执行栈；空标志通常表示不需要                                     | 链接器据此决定最终栈的执行权限                                                                       |
| GNU Property Note | `.note.gnu.property`                   | 保存目标架构安全特性或 ABI 属性                                            | 链接器和加载器可据此识别 CET 等能力                                                                  |
| CFI 保存寄存器         | `.cfi_offset 6, -16`                   | 表示 DWARF 寄存器 6 的旧值保存在 CFA 偏移 `-16` 处；x86-64 中编号 6 通常对应 `%rbp` | 生成 `.eh_frame` 或 `.debug_frame` 展开规则                                                  |
| CFI 修改基准寄存器       | `.cfi_def_cfa_register 6`              | 将 CFA 的基准寄存器改为 DWARF 寄存器 6，即 `%rbp`                           | 描述建立帧指针后的栈展开方式                                                                        |
| CFI 完整定义 CFA      | `.cfi_def_cfa 7, 8`                    | 定义 CFA 为 DWARF 寄存器 7 加 8；x86-64 中编号 7 通常对应 `%rsp`             | 描述函数退出阶段恢复后的调用帧                                                                       |
| 行号语句属性            | `.loc 1 16 5 is_stmt 0`                | 表示对应位置不是新的源语句推荐停靠点                                            | 修改 DWARF 行号状态机的 `is_stmt` 状态                                                          |
| 行号路径区分            | `.loc ... discriminator 1`             | 区分同一行、同一列对应的不同控制流路径                                           | 在 DWARF 行号表中记录 discriminator                                                          |
| 立即数语法             | `$16`、`$0`                             | `$` 表示立即数，而不是内存地址                                             | 决定 x86 指令操作数编码方式                                                                      |
| 寄存器语法             | `%rax`、`%rbp`                          | `%` 表示寄存器，这是 GAS 的 AT\&T 语法                                   | 决定指令寄存器操作数                                                                            |
| 帧内变量寻址            | `-8(%rbp)`                             | 地址为 `%rbp - 8`，通常用于访问栈上的局部变量                                  | 编码为基址加位移的内存操作数                                                                        |
| RIP 相对寻址          | `message(%rip)`                        | 地址为下一条指令地址加相对位移，用于访问静态数据或符号                                   | 通常产生 PC-relative 重定位，支持 PIE/PIC                                                       |
| 有效地址计算            | `leaq message(%rip), %rax`             | 计算 `message` 的地址并写入 `%rax`，不会读取 `message` 内容                  | 生成 `lea` 机器指令及相应重定位                                                                   |
| 栈空间分配             | `subq $16, %rsp`                       | 从栈指针减去 16，为局部变量分配栈空间                                          | 生成 64 位减法指令                                                                           |
| 32 位数据移动          | `movl $6, -8(%rbp)`                    | 将 32 位整数写入栈内存                                                 | 生成 32 位 `mov` 指令                                                                      |
| 64 位数据移动          | `movq %rax, %rdi`                      | 在 64 位寄存器之间移动数据                                               | 常用于按 AMD64 ABI 准备函数参数                                                                 |
| PLT 符号引用          | `call printf@PLT`                      | 要求通过 Procedure Linkage Table 调用外部函数                           | 产生面向 PLT 的重定位，链接后进入 `.plt` 或相关结构                                                      |
| 外部数据引用            | `global_counter(%rip)`                 | 使用 RIP 相对方式访问外部或全局数据符号                                        | 在 `.o` 中通常产生 PC-relative 重定位                                                          |
| 函数返回值             | `%eax`                                 | AMD64 ABI 中整数函数返回值通常位于 `%eax` 或 `%rax`                        | 这是 ABI 约定，不是 ELF 元数据                                                                  |
| 可变参数准备            | `movl $0, %eax`                        | 调用可变参数函数前，设置使用的向量寄存器数量；这里表示未使用 XMM 参数寄存器                      | 满足 System V AMD64 ABI 的可变参数调用约定                                                       |
| 函数退出              | `leave`                                | 等价于恢复栈指针并弹出旧帧指针：概念上为 `mov %rbp,%rsp; pop %rbp`                | 生成函数栈帧清理指令                                                                            |
| 指令宽度后缀            | `b`、`w`、`l`、`q`                        | AT\&T 语法中分别表示 8、16、32、64 位操作数                                 | 决定机器指令的操作数宽度                                                                          |
| 源和目标顺序            | `movl %eax, %esi`                      | AT\&T 语法采用“源操作数在前，目标操作数在后”                                    | 与 Intel 语法的常见书写顺序相反                                                                   |

## assembling

使用`$cc -c`选项将c文件编译至.o文件后停止。  

`main.o`的`elf-header`  

```sh
zoe@HUANGZS7-2V8W0R:~/workspace/compling_lab$ readelf -h main.o
ELF Header:
  Magic:   7f 45 4c 46 02 01 01 00 00 00 00 00 00 00 00 00
  Class:                             ELF64
  Data:                              2's complement, little endian
  Version:                           1 (current)
  OS/ABI:                            UNIX - System V
  ABI Version:                       0
  Type:                              REL (Relocatable file)
  Machine:                           Advanced Micro Devices X86-64
  Version:                           0x1
  Entry point address:               0x0
  Start of program headers:          0 (bytes into file)
  Start of section headers:          3832 (bytes into file)
  Flags:                             0x0
  Size of this header:               64 (bytes)
  Size of program headers:           0 (bytes)
  Number of program headers:         0
  Size of section headers:           64 (bytes)
  Number of section headers:         23
  Section header string table index: 22
```


```asm
main.o:     file format elf64-x86-64


Disassembly of section .text:

0000000000000000 <main>:
   0:	f3 0f 1e fa          	endbr64
   4:	55                   	push   %rbp
   5:	48 89 e5             	mov    %rsp,%rbp
   8:	48 83 ec 10          	sub    $0x10,%rsp
   c:	c7 45 f8 06 00 00 00 	movl   $0x6,-0x8(%rbp)
  13:	c7 45 fc 07 00 00 00 	movl   $0x7,-0x4(%rbp)
  1a:	48 8d 05 00 00 00 00 	lea    0x0(%rip),%rax        # 21 <main+0x21>
			1d: R_X86_64_PC32	.rodata-0x4
  21:	48 89 c7             	mov    %rax,%rdi
  24:	e8 00 00 00 00       	call   29 <main+0x29>
			25: R_X86_64_PLT32	puts-0x4
  29:	8b 55 fc             	mov    -0x4(%rbp),%edx
  2c:	8b 45 f8             	mov    -0x8(%rbp),%eax
  2f:	89 d6                	mov    %edx,%esi
  31:	89 c7                	mov    %eax,%edi
  33:	e8 00 00 00 00       	call   38 <main+0x38>
			34: R_X86_64_PLT32	add-0x4
  38:	89 c1                	mov    %eax,%ecx
  3a:	8b 55 fc             	mov    -0x4(%rbp),%edx
  3d:	8b 45 f8             	mov    -0x8(%rbp),%eax
  40:	89 c6                	mov    %eax,%esi
  42:	48 8d 05 00 00 00 00 	lea    0x0(%rip),%rax        # 49 <main+0x49>
			45: R_X86_64_PC32	.rodata+0x23
  49:	48 89 c7             	mov    %rax,%rdi
  4c:	b8 00 00 00 00       	mov    $0x0,%eax
  51:	e8 00 00 00 00       	call   56 <main+0x56>
			52: R_X86_64_PLT32	printf-0x4
  56:	8b 55 fc             	mov    -0x4(%rbp),%edx
  59:	8b 45 f8             	mov    -0x8(%rbp),%eax
  5c:	89 d6                	mov    %edx,%esi
  5e:	89 c7                	mov    %eax,%edi
  60:	e8 00 00 00 00       	call   65 <main+0x65>
			61: R_X86_64_PLT32	multiply-0x4
  65:	89 c1                	mov    %eax,%ecx
  67:	8b 55 fc             	mov    -0x4(%rbp),%edx
  6a:	8b 45 f8             	mov    -0x8(%rbp),%eax
  6d:	89 c6                	mov    %eax,%esi
  6f:	48 8d 05 00 00 00 00 	lea    0x0(%rip),%rax        # 76 <main+0x76>
			72: R_X86_64_PC32	.rodata+0x35
  76:	48 89 c7             	mov    %rax,%rdi
  79:	b8 00 00 00 00       	mov    $0x0,%eax
  7e:	e8 00 00 00 00       	call   83 <main+0x83>
			7f: R_X86_64_PLT32	printf-0x4
  83:	8b 05 00 00 00 00    	mov    0x0(%rip),%eax        # 89 <main+0x89>
			85: R_X86_64_PC32	.data-0x4
  89:	89 c7                	mov    %eax,%edi
  8b:	e8 00 00 00 00       	call   90 <main+0x90>
			8c: R_X86_64_PLT32	update_counter-0x4
  90:	8b 05 00 00 00 00    	mov    0x0(%rip),%eax        # 96 <main+0x96>
			92: R_X86_64_PC32	global_counter-0x4
  96:	89 c6                	mov    %eax,%esi
  98:	48 8d 05 00 00 00 00 	lea    0x0(%rip),%rax        # 9f <main+0x9f>
			9b: R_X86_64_PC32	.rodata+0x4c
  9f:	48 89 c7             	mov    %rax,%rdi
  a2:	b8 00 00 00 00       	mov    $0x0,%eax
  a7:	e8 00 00 00 00       	call   ac <main+0xac>
			a8: R_X86_64_PLT32	printf-0x4
  ac:	8b 05 00 00 00 00    	mov    0x0(%rip),%eax        # b2 <main+0xb2>
			ae: R_X86_64_PC32	uninitialized_value-0x4
  b2:	89 c6                	mov    %eax,%esi
  b4:	48 8d 05 00 00 00 00 	lea    0x0(%rip),%rax        # bb <main+0xbb>
			b7: R_X86_64_PC32	.rodata+0x61
  bb:	48 89 c7             	mov    %rax,%rdi
  be:	b8 00 00 00 00       	mov    $0x0,%eax
  c3:	e8 00 00 00 00       	call   c8 <main+0xc8>
			c4: R_X86_64_PLT32	printf-0x4
  c8:	b8 00 00 00 00       	mov    $0x0,%eax
  cd:	c9                   	leave
  ce:	c3                   	ret
```

有关重定位的部分：  

|  重定位位置 | 类型               | 目标                        | 含义                  |
| -----: | ---------------- | ------------------------- | ------------------- |
| `0x1d` | `R_X86_64_PC32`  | `.rodata-0x4`             | 获取第一个字符串地址          |
| `0x25` | `R_X86_64_PLT32` | `puts-0x4`                | 调用 `puts`           |
| `0x34` | `R_X86_64_PLT32` | `add-0x4`                 | 调用 `add`            |
| `0x45` | `R_X86_64_PC32`  | `.rodata+0x23`            | 获取第二个格式字符串          |
| `0x52` | `R_X86_64_PLT32` | `printf-0x4`              | 调用 `printf`         |
| `0x61` | `R_X86_64_PLT32` | `multiply-0x4`            | 调用 `multiply`       |
| `0x72` | `R_X86_64_PC32`  | `.rodata+0x35`            | 获取第三个格式字符串          |
| `0x7f` | `R_X86_64_PLT32` | `printf-0x4`              | 调用 `printf`         |
| `0x85` | `R_X86_64_PC32`  | `.data-0x4`               | 读取 `.data` 中的局部对象   |
| `0x8c` | `R_X86_64_PLT32` | `update_counter-0x4`      | 调用 `update_counter` |
| `0x92` | `R_X86_64_PC32`  | `global_counter-0x4`      | 读取全局变量              |
| `0x9b` | `R_X86_64_PC32`  | `.rodata+0x4c`            | 获取格式字符串             |
| `0xa8` | `R_X86_64_PLT32` | `printf-0x4`              | 调用 `printf`         |
| `0xae` | `R_X86_64_PC32`  | `uninitialized_value-0x4` | 读取未初始化全局变量          |
| `0xb7` | `R_X86_64_PC32`  | `.rodata+0x61`            | 获取格式字符串             |
| `0xc4` | `R_X86_64_PLT32` | `printf-0x4`              | 调用 `printf`         |

这段代码中的重定位可分为三类：  

- 字符串地址重定位：R_X86_64_PC32 .rodata+...
- 函数调用重定位：R_X86_64_PLT32 function-0x4
- 全局或静态数据重定位：R_X86_64_PC32 symbol-0x4 或 .data-0x4

它们共同解决的问题是：编译 `main.c` 时，编译器和汇编器还不知道各个节、函数和全局变量在最终可执行文件中的地址，所以将修正工作延迟到链接阶段。  
其中的 -4 本质上来自 x86-64 RIP 相对寻址以“下一条指令地址”为基准的规则。  

## symbol table

对于`main.o`  

该文件的符号表格式：  

```
zoe@HUANGZS7-2V8W0R:~/workspace/compling_lab$ readelf -s main.o

Symbol table '.symtab' contains 20 entries:
   Num:    Value          Size Type    Bind   Vis      Ndx Name
     0: 0000000000000000     0 NOTYPE  LOCAL  DEFAULT  UND
     1: 0000000000000000     0 FILE    LOCAL  DEFAULT  ABS main.c
     2: 0000000000000000     0 SECTION LOCAL  DEFAULT    1 .text
     3: 0000000000000000     0 SECTION LOCAL  DEFAULT    3 .data
     4: 0000000000000000     4 OBJECT  LOCAL  DEFAULT    3 local_data
     5: 0000000000000000     0 SECTION LOCAL  DEFAULT    5 .rodata
     6: 0000000000000000    39 OBJECT  LOCAL  DEFAULT    5 message
     7: 0000000000000000     0 SECTION LOCAL  DEFAULT    6 .debug_info
     8: 0000000000000000     0 SECTION LOCAL  DEFAULT    8 .debug_abbrev
     9: 0000000000000000     0 SECTION LOCAL  DEFAULT   11 .debug_line
    10: 0000000000000000     0 SECTION LOCAL  DEFAULT   13 .debug_str
    11: 0000000000000000     0 SECTION LOCAL  DEFAULT   14 .debug_line_str
    12: 0000000000000000   207 FUNC    GLOBAL DEFAULT    1 main
    13: 0000000000000000     0 NOTYPE  GLOBAL DEFAULT  UND puts
    14: 0000000000000000     0 NOTYPE  GLOBAL DEFAULT  UND add
    15: 0000000000000000     0 NOTYPE  GLOBAL DEFAULT  UND printf
    16: 0000000000000000     0 NOTYPE  GLOBAL DEFAULT  UND multiply
    17: 0000000000000000     0 NOTYPE  GLOBAL DEFAULT  UND update_counter
    18: 0000000000000000     0 NOTYPE  GLOBAL DEFAULT  UND global_counter
    19: 0000000000000000     0 NOTYPE  GLOBAL DEFAULT  UND uninitialized_value

```

该符号表（.symtab）共20个条目，每条包含编号、Value（符号值/地址，可重定位文件中多为0）、Size（符号大小，如main占207字节、message占39字节）、Type（类型：FUNC函数、OBJECT变量、SECTION节、FILE源文件、NOTYPE未指定）、Bind（绑定属性：LOCAL局部符号仅本文件可见，GLOBAL全局符号可被链接时跨文件引用）、Vis（可见性，均为DEFAULT）、Ndx（所属节索引或特殊值：ABS表示绝对符号不参与重定位，UND表示未定义符号需在其他目标文件或库中解析，数字如1、3、5表示定义在.text、.data、.rodata等节中）以及符号名。其中main是本文件定义的全局函数，local_data和message是局部变量，而puts、add、printf、multiply、global_counter等UND符号是本文件引用但未定义的，它们正是后续链接步骤的关键输入：静态链接器（ld）会在链接时根据GLOBAL/UND符号在其他目标文件的.symtab和全局符号表中查找定义并完成符号解析，若找不到则报“undefined reference”错误；解析成功后，链接器再根据符号所在的节进行存储空间分配，将Value从0修正为实际虚拟地址，并生成可执行文件中合并后的符号表供运行时动态链接器（ld.so）解析libc等共享库中的符号（如puts、printf），从而将符号表、重定位和动态链接三个阶段串联起来。  

这里的Ndx标注当前符号所属的section，可以从section header table找到对应：  

```sh

zoe@HUANGZS7-2V8W0R:~/workspace/compling_lab$ readelf -S main.o
There are 23 section headers, starting at offset 0xef8:

Section Headers:
  [Nr] Name              Type             Address           Offset
       Size              EntSize          Flags  Link  Info  Align
  [ 0]                   NULL             0000000000000000  00000000
       0000000000000000  0000000000000000           0     0     0
  [ 1] .text             PROGBITS         0000000000000000  00000040
       00000000000000cf  0000000000000000  AX       0     0     1
  [ 2] .rela.text        RELA             0000000000000000  00000958
       0000000000000180  0000000000000018   I      20     1     8
  [ 3] .data             PROGBITS         0000000000000000  00000110
       0000000000000004  0000000000000000  WA       0     0     4
  [ 4] .bss              NOBITS           0000000000000000  00000114
       0000000000000000  0000000000000000  WA       0     0     1
  [ 5] .rodata           PROGBITS         0000000000000000  00000120
       000000000000007f  0000000000000000   A       0     0     32
  [ 6] .debug_info       PROGBITS         0000000000000000  0000019f
       0000000000000161  0000000000000000           0     0     1
  [ 7] .rela.debug_info  RELA             0000000000000000  00000ad8
       0000000000000258  0000000000000018   I      20     6     8
  [ 8] .debug_abbrev     PROGBITS         0000000000000000  00000300
       0000000000000107  0000000000000000           0     0     1
  [ 9] .debug_aranges    PROGBITS         0000000000000000  00000407
       0000000000000030  0000000000000000           0     0     1
  [10] .rela.debug_[...] RELA             0000000000000000  00000d30
       0000000000000030  0000000000000018   I      20     9     8
  [11] .debug_line       PROGBITS         0000000000000000  00000437
       000000000000007f  0000000000000000           0     0     1
  [12] .rela.debug_line  RELA             0000000000000000  00000d60
       00000000000000a8  0000000000000018   I      20    11     8
  [13] .debug_str        PROGBITS         0000000000000000  000004b6
       0000000000000159  0000000000000001  MS       0     0     1
  [14] .debug_line_str   PROGBITS         0000000000000000  0000060f
       0000000000000071  0000000000000001  MS       0     0     1
  [15] .comment          PROGBITS         0000000000000000  00000680
       000000000000002e  0000000000000001  MS       0     0     1
  [16] .note.GNU-stack   PROGBITS         0000000000000000  000006ae
       0000000000000000  0000000000000000           0     0     1
  [17] .note.gnu.pr[...] NOTE             0000000000000000  000006b0
       0000000000000020  0000000000000000   A       0     0     8
  [18] .eh_frame         PROGBITS         0000000000000000  000006d0
       0000000000000038  0000000000000000   A       0     0     8
  [19] .rela.eh_frame    RELA             0000000000000000  00000e08
       0000000000000018  0000000000000018   I      20    18     8
  [20] .symtab           SYMTAB           0000000000000000  00000708
       00000000000001e0  0000000000000018          21    12     8
  [21] .strtab           STRTAB           0000000000000000  000008e8
       000000000000006b  0000000000000000           0     0     1
  [22] .shstrtab         STRTAB           0000000000000000  00000e20
       00000000000000d3  0000000000000000           0     0     1
Key to Flags:
  W (write), A (alloc), X (execute), M (merge), S (strings), I (info),
  L (link order), O (extra OS processing required), G (group), T (TLS),
  C (compressed), x (unknown), o (OS specific), E (exclude),
  D (mbind), l (large), p (processor specific
```

可以看到，有些*符号*已经定义，而有些的还未定义，需要在链接阶段寻找定义：  

```sh
zoe@HUANGZS7-2V8W0R:~/workspace/compling_lab$ nm -C main.o
                 U add
                 U global_counter
0000000000000000 d local_data
0000000000000000 T main
0000000000000000 r message
                 U multiply
                 U printf
                 U puts
                 U uninitialized_value
                 U update_counter

	• U：未定义符号，需要链接器寻找定义
	• T：定义在代码节.text
	• D：定义在已初始化数据节
	• B：定义在 .bss
小写字母通常表示局部符号(.r maybe .rodata?)
and .d .data?

```

对于在`main.o`中无法找到定义的符号，可以在`calc.o`中找到  

```
zoe@HUANGZS7-2V8W0R:~/workspace/compling_lab$ nm -C calc.o
0000000000000000 T add
0000000000000000 D global_counter
0000000000000004 d internal_state
0000000000000000 r module_name
0000000000000018 T multiply
0000000000000000 B uninitialized_value
000000000000002f T update_counter
```

## linking

`main.o`的`relocation table`  

```sh
zoe@HUANGZS7-2V8W0R:~/workspace/compling_lab$ readelf -r main.o

Relocation section '.rela.text' at offset 0x958 contains 16 entries:
  Offset          Info           Type           Sym. Value    Sym. Name + Addend
00000000001d  000500000002 R_X86_64_PC32     0000000000000000 .rodata - 4
000000000025  000d00000004 R_X86_64_PLT32    0000000000000000 puts - 4
000000000034  000e00000004 R_X86_64_PLT32    0000000000000000 add - 4
000000000045  000500000002 R_X86_64_PC32     0000000000000000 .rodata + 23
000000000052  000f00000004 R_X86_64_PLT32    0000000000000000 printf - 4
000000000061  001000000004 R_X86_64_PLT32    0000000000000000 multiply - 4
000000000072  000500000002 R_X86_64_PC32     0000000000000000 .rodata + 35
00000000007f  000f00000004 R_X86_64_PLT32    0000000000000000 printf - 4
000000000085  000300000002 R_X86_64_PC32     0000000000000000 .data - 4
00000000008c  001100000004 R_X86_64_PLT32    0000000000000000 update_counter - 4
000000000092  001200000002 R_X86_64_PC32     0000000000000000 global_counter - 4
00000000009b  000500000002 R_X86_64_PC32     0000000000000000 .rodata + 4c
0000000000a8  000f00000004 R_X86_64_PLT32    0000000000000000 printf - 4
0000000000ae  001300000002 R_X86_64_PC32     0000000000000000 uninitialized_value - 4
0000000000b7  000500000002 R_X86_64_PC32     0000000000000000 .rodata + 61
0000000000c4  000f00000004 R_X86_64_PLT32    0000000000000000 printf - 4

Relocation section '.rela.debug_info' at offset 0xad8 contains 25 entries:
  Offset          Info           Type           Sym. Value    Sym. Name + Addend
000000000008  00080000000a R_X86_64_32       0000000000000000 .debug_abbrev + 0
00000000000d  000a0000000a R_X86_64_32       0000000000000000 .debug_str + 76
000000000012  000b0000000a R_X86_64_32       0000000000000000 .debug_line_str + 0
000000000016  000b0000000a R_X86_64_32       0000000000000000 .debug_line_str + 7
00000000001a  000200000001 R_X86_64_64       0000000000000000 .text + 0
00000000002a  00090000000a R_X86_64_32       0000000000000000 .debug_line + 0
000000000031  000a0000000a R_X86_64_32       0000000000000000 .debug_str + 29
000000000038  000a0000000a R_X86_64_32       0000000000000000 .debug_str + 8
00000000003f  000a0000000a R_X86_64_32       0000000000000000 .debug_str + 63
000000000046  000a0000000a R_X86_64_32       0000000000000000 .debug_str + 129
00000000004d  000a0000000a R_X86_64_32       0000000000000000 .debug_str + 14d
000000000054  000a0000000a R_X86_64_32       0000000000000000 .debug_str + 143
000000000062  000a0000000a R_X86_64_32       0000000000000000 .debug_str + 111
000000000069  000a0000000a R_X86_64_32       0000000000000000 .debug_str + 4f
000000000073  000a0000000a R_X86_64_32       0000000000000000 .debug_str + 11a
00000000007d  000a0000000a R_X86_64_32       0000000000000000 .debug_str + 15
000000000087  000a0000000a R_X86_64_32       0000000000000000 .debug_str + 44
000000000093  000300000001 R_X86_64_64       0000000000000000 .data + 0
0000000000b1  000a0000000a R_X86_64_32       0000000000000000 .debug_str + 0
0000000000bd  000500000001 R_X86_64_64       0000000000000000 .rodata + 0
0000000000c6  000a0000000a R_X86_64_32       0000000000000000 .debug_str + 54
0000000000d8  000a0000000a R_X86_64_32       0000000000000000 .debug_str + 3b
0000000000f3  000a0000000a R_X86_64_32       0000000000000000 .debug_str + 13c
00000000012c  000a0000000a R_X86_64_32       0000000000000000 .debug_str + 71
000000000137  000200000001 R_X86_64_64       0000000000000000 .text + 0

Relocation section '.rela.debug_aranges' at offset 0xd30 contains 2 entries:
  Offset          Info           Type           Sym. Value    Sym. Name + Addend
000000000006  00070000000a R_X86_64_32       0000000000000000 .debug_info + 0
000000000010  000200000001 R_X86_64_64       0000000000000000 .text + 0

Relocation section '.rela.debug_line' at offset 0xd60 contains 7 entries:
  Offset          Info           Type           Sym. Value    Sym. Name + Addend
000000000022  000b0000000a R_X86_64_32       0000000000000000 .debug_line_str + 27
000000000026  000b0000000a R_X86_64_32       0000000000000000 .debug_line_str + 47
000000000030  000b0000000a R_X86_64_32       0000000000000000 .debug_line_str + 54
000000000035  000b0000000a R_X86_64_32       0000000000000000 .debug_line_str + 5b
00000000003a  000b0000000a R_X86_64_32       0000000000000000 .debug_line_str + 62
00000000003f  000b0000000a R_X86_64_32       0000000000000000 .debug_line_str + 69
000000000049  000200000001 R_X86_64_64       0000000000000000 .text + 0

Relocation section '.rela.eh_frame' at offset 0xe08 contains 1 entry:
  Offset          Info           Type           Sym. Value    Sym. Name + Addend
000000000020  000200000002 R_X86_64_PC32     0000000000000000 .text + 0
```

对于这样一个`relocation entry`  

```

Relocation section '.rela.text' at offset 0x958 contains 16 entries:
  Offset          Info           Type           Sym. Value    Sym. Name + Addend
  000000000034  000e00000004 R_X86_64_PLT32    0000000000000000 add - 4

```

其关键字段值：  

```
r_offset = 0x34
r_info   = 0x0000000e00000004
r_addend = -4
```

其 `section header`中`sh_name`字段， 如`.rela.text`说明该`relocation table`负责修改哪个section  

```
.rela.text          → 修补 .text
.rela.debug_info    → 修补 .debug_info
.rela.debug_aranges → 修补 .debug_aranges
.rela.debug_line    → 修补 .debug_line
.rela.eh_frame      → 修补 .eh_frame
```
`.rela` 中的 `rela` 表明它使用显式加数，即 `r_addend` 单独保存在重定位项中；与之相对，`.rel` 通常将加数隐含在需要修补的字段中。  

`r_offset`在`relocatable file`中表示`应当修改对应section中的r_offset`处, 注意，不是指令开始处，而是需要回填地址的起始位置  

`r_info`指代 `type=0x4`, `symidx=0xe`, 即`add`  

```
S：目标符号最终解析得到的地址或符号值, 即symidx指代的符号表中的表项(所属的section).
A：重定位项中记录的 Addend
P：被重定位字段本身的最终地址
L：目标符号对应的 PLT 表项地址
```

e.g.  

```

R_X86_64_64：写入 64 位绝对值
result = S + A
链接器把完整结果写入目标位置的 8 字节字段。这里不需要 P，因为写入的是目标本身的绝对地址，而不是目标相对于当前位置的距离。

R_X86_64_32：写入 32 位绝对值
result = S + A
区别在于链接器只向目标位置写入 4 字节，并检查该结果是否可以通过零扩展还原成原始 64 位结果。
因此合法范围：0 <= result <= 0xffffffff

R_X86_64_PC32：写入 32 位 PC 相对位移
result = S + A - P (由于是相对当前pc的地址，所以-p)
链接器向目标位置写入一个 4 字节有符号值。该字段通常不是目标地址，而是从当前指令附近到目标地址的距离。它用于 x86-64 的 RIP-relative 数据访问、分支，或其他 PC-relative 引用。

R_X86_64_PLT32：写入到函数或 PLT 表项的相对位移
R_X86_64_PLT32 主要用于直接函数调用
result = L + A - P
其中 L 是目标函数对应的 PLT 表项地址。它与 R_X86_64_PC32 的计算形式相似，区别在于目标原则上不是函数实体地址 S，而是该符号的 Procedure Linkage Table 表项地址 L。


PLT/GOT 是每个 ELF 可执行文件或共享库自身的链接基础设施。静态链接器负责规划、创建和初始化其静态结构；动态链接器负责在加载期或首次调用时解析动态符号，并更新 GOT 中需要运行时确定的地址；CPU 只负责执行 PLT 指令并读取 GOT 槽位。

```

这里可以看到，计算重定位地址需要考虑很多方面：
1. 机器架构
2. 机器位长
3. 相对寻址还是绝对寻址
4. 是否为函数调用

这些在`type`字段规定的类型中都有体现  

```
add
multiply
update_counter
printf
global_counter
uninitialized_value

可以看到main.o 中的指令尚未包含这些符号的最终虚拟地址，因此汇编器生成重定位项。
链接器读取重定位项后，将符号绑定到定义，并修正相应指令或数据。ELF 重定位项描述了待修正位置、关联符号和体系结构相关的重定位类型。
```

## static(?) linking

`linker`的三项核心工作：  

选择输入目标文件、合并输入 section、解析并重定位符号引用  

链接过程：  

1. 链接器读取 main.o、启动文件和库
2. 根据未定义符号，从 libcalc.a 中按需提取 calc.o
3. 把各输入文件中的同类 section 合并
4. 为输出 section 和符号分配最终链接地址
5. 根据 relocation entry 修正 main.o 中的符号引用

### `.map`

对于`.map`文件：  

| Map 文件区域                        | 回答的问题                  |
| ------------------------------- | ---------------------- |
| `Archive member included...`    | 为什么从静态库中提取某个 `.o`      |
| `As-needed library included...` | 为什么保留某个动态库依赖           |
| `Discarded input sections`      | 哪些输入 section 没进入最终输出   |
| `Memory Configuration`          | 链接脚本允许使用哪些地址区域         |
| `LOAD`                          | 链接器处理了哪些输入文件和库         |
| `Linker script and memory map`  | 输入 section 如何合并、最终放到哪里 |
| 符号地址行                           | 函数和变量最终位于什么链接地址        |
| `OUTPUT(...)`                   | 最终输出文件名和 ELF 格式        |


#### include static-library

```
Archive member included to satisfy reference by file (symbol)

./libcalc.a(calc.o)           main.o (global_counter)
```

链接器处理 `main.o` 时，发现其中引用了未定义符号 `global_counter`；随后扫描 `libcalc.a` 的符号索引，发现该符号由成员 `calc.o` 定义，于是从静态库中提取整个 `calc.o` 加入当前链接。  
静态库通常按目标文件成员粒度提取，即只要需要某个成员中的一个符号，该成员整体就会参与链接；被提取成员中的其他未定义符号还可能进一步触发更多库成员被提取  

#### include dynamic-library

```
As-needed library included to satisfy reference by file (symbol)
 
libc.so.6 main.o (puts@@GLIBC_2.2.5)
```

`main.o` 时发现其中存在未定义符号 `puts@@GLIBC_2.2.5`，而 `GCC` 在默认链接过程中会自动加入 C 标准库 `-lc`；由于当前未使用 `-static` 或 `-Wl,-Bstatic`，链接器按默认动态模式选择了提供该符号的 `libc.so.6`，并用其动态符号定义满足 `main.o` 的引用。  
启用 `--as-needed` 后，只有实际解决了未定义符号的共享库才会被写入最终 `ELF` 的 `DT_NEEDED`，因此该行表示：`main.o` 对 `puts` 的引用使 `libc.so.6` 成为必要的运行时依赖；其中 `@@GLIBC_2.2.5` 表示链接的是 `puts` 的默认 `GLIBC_2.2.5` 符号版本。  


#### discard input sections

```
Discarded input sections

 .note.GNU-stack
                0x0000000000000000        0x0 /usr/lib/gcc/x86_64-linux-gnu/13/../../../x86_64-linux-gnu/Scrt1.o
 .note.gnu.property
                0x0000000000000000       0x20 /usr/lib/gcc/x86_64-linux-gnu/13/../../../x86_64-linux-gnu/crti.o

```
这些是被丢弃的`section`，输出格式为：  
输入 `section` 名 地址 大小 来源文件  

`Discarded input sections` 中的所有条目都没有原样进入最终输出。这里出现的地址 0 不表示它被放在最终映像的地址 0，而是因为它已经被丢弃，没有获得有效的输出地址。  

#### memory configuration

```

Memory Configuration

Name             Origin             Length             Attributes
*default*        0x0000000000000000 0xffffffffffffffff

```

这表示当前链接没有自定义 `MEMORY` 区域，所有段都可以放在默认的整个地址空间中。实际代码、数据放在哪里，由后面的 `SECTIONS` 命令决定。


#### linker script and memory map

```text
Linker script and memory map
LOAD ...
```

`LOAD` 表示链接器在链接过程中读取了某个输入文件。注意：这里的“LOAD”不是运行时加载，而是链接时把该文件作为输入参与链接。对于动态库，最终可执行文件通常不会复制其代码，而是记录依赖关系。

涉及的文件：  

| 文件 | 作用 |
|---|---|
| `Scrt1.o` | C 运行时启动文件，用于 PIE 可执行文件，提供 `_start`，最终调用 `__libc_start_main` |
| `crti.o` | 提供 `.init` 和 `.fini` 节的开头部分 |
| `crtbeginS.o` | GCC 提供的构造函数/析构函数注册开始，`S` 表示用于 PIE/共享库 |
| `main.o` | 用户编译出的主目标文件 |
| `./libcalc.a` | 用户自己的静态库，例如包含计算相关函数 |
| `libgcc.a` | GCC 静态运行时库，提供底层算术、异常处理等支持 |
| `libgcc_s.so` | GCC 共享运行时库的链接脚本，会展开成组 |
| `libc.so` | glibc 的链接脚本，会展开成组 |
| `libc.so.6` | 真正的动态 C 库 |
| `libc_nonshared.a` | 必须静态链接进可执行文件的 libc 部分 |
| `ld-linux-x86-64.so.2` | 动态链接器/加载器 |
| `crtendS.o` | GCC 构造函数/析构函数注册结束 |
| `crtn.o` | 提供 `.init` 和 `.fini` 节的结尾部分 |

#### group

```text
START GROUP
LOAD /usr/lib/gcc/.../libgcc_s.so.1
LOAD /usr/lib/gcc/.../libgcc.a
END GROUP
```

`START GROUP` 和 `END GROUP` 对应链接器脚本中的 `GROUP(...)` 命令。

它的作用是：组内的库会被反复扫描，直到没有新的未定义符号被解析。这主要用于解决静态库之间的循环依赖。

#### merge sections

format:  

```
```text
.interp         0x0000000000000318       0x1c     ← 输出节名、起始地址、大小
 *(.interp)                                      ← 通配符：收集所有输入文件的 .interp 节
 .interp        0x0000000000000318       0x1c Scrt1.o  ← 实际来自哪个文件、放在哪、多大
                0x0000000000001080                _start   ← 定义在该地址的符号
 *fill*         0x00000000000010a6        0xa            ← 对齐填充字节
                [!provide]  PROVIDE (...)              ← 弱定义符号（仅被引用时才生成）
```


##### 1. sections after program header(0x318 起)

```
PROVIDE (__executable_start = SEGMENT_START ("text-segment", 0x0))
0x0000000000000318                . = (SEGMENT_START ("text-segment", 0x0) + SIZEOF_HEADERS)
```

- `PROVIDE` 定义了一个符号 `__executable_start`，其值为 `text-segment` 段的起始地址，默认是 `0x0`。这个符号通常表示程序可执行代码段的起始地址。
- `SEGMENT_START("text-segment", 0x0)` 是链接器脚本函数，返回 `-Ttext-segment=...` 指定的地址，若未指定则用默认值 `0x0`。
- `SIZEOF_HEADERS` 是 ELF 文件头（ELF header + program header table）的总大小。
- 位置计数器 `.` 被设置为 `0x0 + SIZEOF_HEADERS`，这里结果是 `0x318`，说明程序头大小是 `0x318` 字节。因此第一个输出节从 `0x318` 开始。

```text
. = (SEGMENT_START("text-segment", 0x0) + SIZEOF_HEADERS)
```

代码段从 ELF 头之后开始。这一段都是**动态链接所需的元数据节**：

| 节 | 作用 |
|---|---|
| `.interp` | 动态链接器路径字符串，如 `/lib64/ld-linux-x86-64.so.2` |
| `.note.gnu.property` | GNU 属性(如 IBT/CET 安全特性标志) |
| `.note.gnu.build-id` | 构建唯一 ID(`readelf -n` 可见) |
| `.note.ABI-tag` | ABI 版本标记 |
| `.gnu.hash` | 符号哈希表(快速查找动态符号) |
| `.dynsym` / `.dynstr` | 动态符号表及其字符串表 |
| `.gnu.version` / `_d` / `_r` | 符号版本信息 |
| `.rela.dyn` | 运行时重定位表(数据/GOT 重定位) |
| `.rela.plt` | PLT 函数的重定位表(懒绑定信息) |

##### 2. 代码段(0x1000 起，页对齐)

```text
. = ALIGN(CONSTANT(MAXPAGESIZE))   ← 对齐到 4096(0x1000)
```

- **`.init` (0x1000)**: 进程初始化代码，由 `crti.o` 的开头 + `crtn.o` 的结尾拼成，入口符号 `_init`。
- **`.plt` (0x1020, 大小 0x30)**: 过程链接表，动态函数调用的跳转桩。
- **`.plt.got` (0x1050, 大小 0x10)**: 针对 GOT 的 PLT 条目，包含 `__cxa_finalize@@GLIBC_2.2.5`（退出时清理，用于 C++ 析构函数的最终清理）。
- **`.plt.sec` (0x1060, 大小 0x20)**: 安全 PLT 节（与 `.plt` 配合，用于 IBT 等安全特性），包含 `puts@@GLIBC_2.2.5` 和 `printf@@GLIBC_2.2.5` 的跳转桩。
- **`.text` (0x1080, 0x225)**:主代码。注意各文件的贡献：

```text
.text  0x1080  0x26   Scrt1.o      → _start(真正的进程入口)
.text  0x10b0  0xb9   crtbeginS.o
.text  0x1169  0xcf   main.o       → main
.text  0x1238  0x6d   libcalc.a(calc.o) → add, multiply, update_counter
```

**这说明 `libcalc.a` 中的 `calc.o` 被从静态库中提取并链入了最终可执行文件**(因为 `main` 引用了它的符号)。

- **`.fini` (0x12a8)**:进程退出代码，入口符号 `_fini`。
- 随后定义了 `__etext`/`_etext`/`etext`(代码段结束地址)。

##### 3. 只读数据段(0x2000 起，新的一页)

- **`.rodata`**:只读数据。`_IO_stdin_used`(glibc 检测 stdin 是否被使用的标志)、`main.o` 的字符串常量(printf/puts 的格式串)、`calc.o` 的只读数据。
- **`.eh_frame_hdr` / `.eh_frame`**:C++ 异常展开/栈回溯信息。注意 `0x2c (size before relaxing)` —— 链接器做了 **DWARF CFI relaxation**,压缩了帧描述，所以最终大小比输入时小。
- `.sframe`、`.gcc_except_table` 等为空(本程序无 C++ 异常)。

##### 4. 数据段(0x3db0 起)

```text
. = DATA_SEGMENT_ALIGN(MAXPAGESIZE, COMMONPAGESIZE)
```

- **`.init_array` / `.fini_array`**:构造/析构函数指针表，由 `crtbeginS.o` 提供边界标记(`__init_array_start/end`)。运行时 `__libc_csu_init` 会遍历它们。
- **`.dynamic` (0x3dc0)**:动态段，记录所有依赖库、重定位、版本等信息，符号 `_DYNAMIC` 指向它。
- **`.got` / `.got.plt` (0x3fb0)**:全局偏移表。`_GLOBAL_OFFSET_TABLE_` 指向 `.got.plt` 开头。`puts`/`printf` 的实际地址运行时填到这里。
- **`.data` (0x4000)**:已初始化的可写数据：

```text
.data  0x4010  0x4   main.o
.data  0x4014  0x8   libcalc.a(calc.o) → global_counter
```

`__dso_handle` 用于 `atexit`/`__cxa_finalize` 识别自身。

- **`.bss` (0x401c)**:未初始化数据(文件中不占空间，运行时清零):

```text
.bss   0x4020  0x4   libcalc.a(calc.o) → uninitialized_value
```

- `_edata`、`__bss_start`、`_end`/`end` 是传统的段边界符号。
- `.lbss`/`.lrodata`/`.ldata` 是 **large/BFD 大节支持**(x86-64 上通常为空)。

##### 5. 调试与注释节(地址 0)

这些节不加载到内存，地址为 0:

- `.comment`:编译器版本字符串(如 "GCC: (Ubuntu 13...)")。
- `.debug_aranges`、`.debug_info`、`.debug_abbrev`、`.debug_line`、`.debug_str`、`.debug_line_str`:**DWARF 调试信息**，来自 `main.o` 和 `calc.o`,说明程序是带 `-g` 编译的。`size before relaxing` 表示链接器合并去重了重复的调试字符串。

##### 6. /DISCARD/ 与 OUTPUT

```text
/DISCARD/
 *(.note.GNU-stack)     ← 丢弃(不生成 .note.GNU-stack 节)
 *(.gnu_debuglink)
 *(.gnu.lto_*)
OUTPUT(elf_static elf64-x86-64)
```

- `/DISCARD/`:这些输入节被丢弃，不进入输出文件。
- `OUTPUT(...)`:输出文件格式为 **静态 ELF、64 位 x86-64**(`elf_static` 指目标格式，不是静态链接——程序显然是动态链接的 PIE)。

##### 7. 整体内存布局总结

```text
0x0318 ─ 0x0660   ELF 头 + 动态链接元数据(.interp/.dynsym/.rela...)
0x1000 ─ 0x12b5   代码(.init/.plt/.text/.fini)      ← 可执行
0x2000 ─ 0x21fc   只读数据(.rodata/.eh_frame)       ← 只读
0x3db0 ─ 0x4000   RELRO 区(.init_array/.dynamic/.got) ← 只读(重定位后)
0x4000 ─ 0x4028   可写数据(.data/.bss)               ← 读写
```

## shared libary

```text

zoe@HUANGZS7-2V8W0R:~/workspace/compling_lab$ readelf -h libcalc.so
ELF Header:
  Magic:   7f 45 4c 46 02 01 01 00 00 00 00 00 00 00 00 00
  Class:                             ELF64
  Data:                              2's complement, little endian
  Version:                           1 (current)
  OS/ABI:                            UNIX - System V
  ABI Version:                       0
  Type:                              DYN (Shared object file)
  Machine:                           Advanced Micro Devices X86-64
  Version:                           0x1
  Entry point address:               0x0
  Start of program headers:          64 (bytes into file)
  Start of section headers:          14912 (bytes into file)
  Flags:                             0x0
  Size of this header:               64 (bytes)
  Size of program headers:           56 (bytes)
  Number of program headers:         11
  Size of section headers:           64 (bytes)
  Number of section headers:         32
  Section header string table index: 31

```

`shared object file`, 既有`section headers`也有`program headers`

`libcalc.so`的`.dynamic`和`.dyn-syms`

```text
zoe@HUANGZS7-2V8W0R:~/workspace/compling_lab$ readelf -d libcalc.so

Dynamic section at offset 0x2e58 contains 18 entries:
  Tag        Type                         Name/Value
 0x000000000000000e (SONAME)             Library soname: [libcalc.so]
 0x000000000000000c (INIT)               0x1000
 0x000000000000000d (FINI)               0x1174
 0x0000000000000019 (INIT_ARRAY)         0x3e48
 0x000000000000001b (INIT_ARRAYSZ)       8 (bytes)
 0x000000000000001a (FINI_ARRAY)         0x3e50
 0x000000000000001c (FINI_ARRAYSZ)       8 (bytes)
 0x000000006ffffef5 (GNU_HASH)           0x2f0
 0x0000000000000005 (STRTAB)             0x418
 0x0000000000000006 (SYMTAB)             0x328
 0x000000000000000a (STRSZ)              159 (bytes)
 0x000000000000000b (SYMENT)             24 (bytes)
 0x0000000000000003 (PLTGOT)             0x3fe8
 0x0000000000000007 (RELA)               0x4b8
 0x0000000000000008 (RELASZ)             216 (bytes)
 0x0000000000000009 (RELAENT)            24 (bytes)
 0x000000006ffffff9 (RELACOUNT)          3
 0x0000000000000000 (NULL)               0x0
zoe@HUANGZS7-2V8W0R:~/workspace/compling_lab$ readelf  --dyn-syms libcalc.so

Symbol table '.dynsym' contains 10 entries:
   Num:    Value          Size Type    Bind   Vis      Ndx Name
     0: 0000000000000000     0 NOTYPE  LOCAL  DEFAULT  UND
     1: 0000000000000000     0 NOTYPE  WEAK   DEFAULT  UND __cxa_finalize
     2: 0000000000000000     0 NOTYPE  WEAK   DEFAULT  UND _ITM_registerTMC[...]
     3: 0000000000000000     0 NOTYPE  WEAK   DEFAULT  UND _ITM_deregisterT[...]
     4: 0000000000000000     0 NOTYPE  WEAK   DEFAULT  UND __gmon_start__
     5: 0000000000004014     4 OBJECT  GLOBAL DEFAULT   21 uninitialized_value
     6: 00000000000010f9    24 FUNC    GLOBAL DEFAULT   10 add
     7: 0000000000001111    23 FUNC    GLOBAL DEFAULT   10 multiply
     8: 0000000000004008     4 OBJECT  GLOBAL DEFAULT   20 global_counter
     9: 0000000000001128    74 FUNC    GLOBAL DEFAULT   10 update_counter
```

`elf_shared`的`.dynamic`和相关依赖  

```
zoe@HUANGZS7-2V8W0R:~/workspace/compling_lab$ readelf -d elf_shared
ldd ./elf_shared

Dynamic section at offset 0x2d88 contains 29 entries:
  Tag        Type                         Name/Value
 0x0000000000000001 (NEEDED)             Shared library: [libcalc.so]
 0x0000000000000001 (NEEDED)             Shared library: [libc.so.6]
 0x000000000000001d (RUNPATH)            Library runpath: [$ORIGIN]
 0x000000000000000c (INIT)               0x1000
 0x000000000000000d (FINI)               0x1298
 0x0000000000000019 (INIT_ARRAY)         0x3d78
 0x000000000000001b (INIT_ARRAYSZ)       8 (bytes)
 0x000000000000001a (FINI_ARRAY)         0x3d80
 0x000000000000001c (FINI_ARRAYSZ)       8 (bytes)
 0x000000006ffffef5 (GNU_HASH)           0x3b0
 0x0000000000000005 (STRTAB)             0x518
 0x0000000000000006 (SYMTAB)             0x3e0
 0x000000000000000a (STRSZ)              230 (bytes)
 0x000000000000000b (SYMENT)             24 (bytes)
 0x0000000000000015 (DEBUG)              0x0
 0x0000000000000003 (PLTGOT)             0x3f98
 0x0000000000000002 (PLTRELSZ)           120 (bytes)
 0x0000000000000014 (PLTREL)             RELA
 0x0000000000000017 (JMPREL)             0x738
 0x0000000000000007 (RELA)               0x648
 0x0000000000000008 (RELASZ)             240 (bytes)
 0x0000000000000009 (RELAENT)            24 (bytes)
 0x000000000000001e (FLAGS)              BIND_NOW
 0x000000006ffffffb (FLAGS_1)            Flags: NOW PIE
 0x000000006ffffffe (VERNEED)            0x618
 0x000000006fffffff (VERNEEDNUM)         1
 0x000000006ffffff0 (VERSYM)             0x5fe
 0x000000006ffffff9 (RELACOUNT)          3
 0x0000000000000000 (NULL)               0x0
        linux-vdso.so.1 (0x00007e6c07df0000)
        libcalc.so => /home/zoe/workspace/compling_lab/./libcalc.so (0x00007e6c07dde000)
        libc.so.6 => /lib/x86_64-linux-gnu/libc.so.6 (0x00007e6c07a00000)
        /lib64/ld-linux-x86-64.so.2 (0x00007e6c07df2000)
```

- 这些输出共同说明：`libcalc.so` 是面向 `x86-64`、采用 `小端格式` 的 `64 位 ELF 共享对象`，类型为 `ET_DYN`，没有 `独立程序入口`，保留了 `调试信息` 且未被 `strip`；
- 它以 `libcalc.so` 为 `SONAME`，并通过 `动态符号表` 对外导出 `add`、`multiply`、`update_counter`、`global_counter` 和 `uninitialized_value`，同时保留少量由 `运行时环境` 选择性解析的 `弱未定义符号`。
- `elf_shared` 则是 `PIE 动态可执行文件`，明确依赖 `libcalc.so` 和 `libc.so.6`，通过 `$ORIGIN` 在自身所在目录查找 `libcalc.so`，并启用了 `立即绑定`；
- `ldd` 的结果进一步证明，`运行时` 已成功从当前工程目录加载 `libcalc.so`，从系统目录加载 `libc.so.6`，并由 `ld-linux-x86-64.so.2` 完成 `动态装载` 和 `符号解析`。

| 检查对象或字段               | 输出结果                                   | 可提炼的关键信息                                 |
| --------------------- | -------------------------------------- | ---------------------------------------- |
| `file libcalc.so`     | ELF 64-bit LSB shared object, x86-64   | `libcalc.so` 是 x86-64 平台的 64 位小端共享对象     |
| 调试状态                  | with debug\_info, not stripped         | 包含 DWARF 调试信息和完整符号信息，适合使用 GDB 调试         |
| ELF 类型                | DYN                                    | 属于共享对象，可在运行时加载到不同虚拟地址                    |
| Entry point           | `0x0`                                  | 共享库不是独立程序，不需要类似 `_start` 的程序入口           |
| Program Headers       | 11 个                                   | 描述动态装载器需要映射的段及其权限                        |
| Section Headers       | 32 个                                   | 描述代码、数据、动态信息、符号和调试信息等 section            |
| SONAME                | `libcalc.so`                           | 其他 ELF 文件记录依赖时使用的共享库逻辑名称                 |
| `.dynsym`             | 10 个动态符号                               | 保存供动态链接器查找的导出符号和未定义符号                    |
| 导出函数                  | `add`、`multiply`、`update_counter`      | 这些函数可被其他可执行文件或共享库动态引用                    |
| 导出变量                  | `global_counter`、`uninitialized_value` | 这些全局对象也对外可见并可参与动态符号解析                    |
| 弱未定义符号                | `__cxa_finalize`、`__gmon_start__` 等    | 通用运行时辅助符号，允许不存在，不属于 `calc` 的主要业务接口       |
| 符号 `Value`            | 如 `add=0x10f9`                         | 是共享库映像内部的相对虚拟地址，运行时地址通常等于加载基址加该值         |
| 动态字符串表与符号表            | `STRTAB`、`SYMTAB`                      | 分别保存动态符号名称字符串和动态符号记录                     |
| GNU Hash              | `GNU_HASH=0x2f0`                       | 用于加速动态链接器查找导出符号                          |
| 动态重定位                 | `RELA` 大小 216 字节，共 9 项                 | 共享库加载后仍有部分地址需要动态链接器修正                    |
| PLTGOT                | `0x3fe8`                               | 共享库包含 GOT/PLT 相关地址区域，用于动态地址解析            |
| `elf_shared` 的依赖      | `libcalc.so`、`libc.so.6`               | 前者提供计算模块，后者提供 `puts`、`printf` 等标准库函数     |
| RUNPATH               | `$ORIGIN`                              | 动态链接器会在 `elf_shared` 所在目录寻找其直接依赖的共享库     |
| `BIND_NOW` / `NOW`    | 已启用                                    | 可延迟绑定的动态符号在程序启动阶段立即完成解析                  |
| PIE 标志                | `PIE`                                  | `elf_shared` 是位置无关可执行文件，可配合 ASLR 随机化加载地址 |
| `ldd` 中的 `libcalc.so` | 指向工程目录下的 `./libcalc.so`                | 证明 `$ORIGIN` 生效，共享库能够被正确找到               |
| `ldd` 中的 `libc.so.6`  | 指向系统 `/lib/x86_64-linux-gnu`           | C 标准库由系统共享库提供                            |
| 动态加载器                 | `ld-linux-x86-64.so.2`                 | 负责加载依赖库、执行重定位并解析动态符号                     |

对于 `elf_static`和`elf_shared`，  

| 对比项                          | `elf_static`           | `elf_shared`                |
| ---------------------------- | ---------------------- | --------------------------- |
| calc 模块来源                    | `libcalc.a(calc.o)`    | `libcalc.so`                |
| calc 代码是否进入可执行文件             | 是，合并进自身 `.text`        | 否，保留在 `libcalc.so` 中        |
| calc 数据是否进入可执行文件             | 是，合并进自身 `.data/.bss`   | 否，保留在 `libcalc.so` 中        |
| `add` 等符号何时解析                | 静态链接阶段                 | 链接时确认由 `.so` 提供，运行时完成装载与重定位 |
| 运行时是否需要 calc 库               | 不需要 `libcalc.a`        | 必须能够找到 `libcalc.so`         |
| 是否存在 `DT_NEEDED: libcalc.so` | 不存在                    | 存在                          |
| 库更新后是否自动生效                   | 不会，必须重新链接 `elf_static` | ABI 兼容时，替换 `.so` 后重启程序即可生效  |
| 可执行文件大小                      | 通常较大                   | 通常较小，但需配合 `.so`             |
| 多个进程的 calc 代码                | 每个可执行文件中各有一份           | `.so` 的只读代码页可被多个进程共享        |

`elf_shared`的`.plt`

```asm
zoe@HUANGZS7-2V8W0R:~/workspace/compling_lab$ objdump -dsj .plt elf_shared

elf_shared:     file format elf64-x86-64

Contents of section .plt:
 1020 ff357a2f 0000ff25 7c2f0000 0f1f4000  .5z/...%|/....@.
 1030 f30f1efa 68000000 00e9e2ff ffff6690  ....h.........f.
 1040 f30f1efa 68010000 00e9d2ff ffff6690  ....h.........f.
 1050 f30f1efa 68020000 00e9c2ff ffff6690  ....h.........f.
 1060 f30f1efa 68030000 00e9b2ff ffff6690  ....h.........f.
 1070 f30f1efa 68040000 00e9a2ff ffff6690  ....h.........f.

Disassembly of section .plt:

0000000000001020 <.plt>:
    1020:       ff 35 7a 2f 00 00       push   0x2f7a(%rip)        # 3fa0 <_GLOBAL_OFFSET_TABLE_+0x8>
    1026:       ff 25 7c 2f 00 00       jmp    *0x2f7c(%rip)        # 3fa8 <_GLOBAL_OFFSET_TABLE_+0x10>
    102c:       0f 1f 40 00             nopl   0x0(%rax)
    1030:       f3 0f 1e fa             endbr64
    1034:       68 00 00 00 00          push   $0x0
    1039:       e9 e2 ff ff ff          jmp    1020 <_init+0x20>
    103e:       66 90                   xchg   %ax,%ax
    1040:       f3 0f 1e fa             endbr64
    1044:       68 01 00 00 00          push   $0x1
    1049:       e9 d2 ff ff ff          jmp    1020 <_init+0x20>
    104e:       66 90                   xchg   %ax,%ax
    1050:       f3 0f 1e fa             endbr64
    1054:       68 02 00 00 00          push   $0x2
    1059:       e9 c2 ff ff ff          jmp    1020 <_init+0x20>
    105e:       66 90                   xchg   %ax,%ax
    1060:       f3 0f 1e fa             endbr64
    1064:       68 03 00 00 00          push   $0x3
    1069:       e9 b2 ff ff ff          jmp    1020 <_init+0x20>
    106e:       66 90                   xchg   %ax,%ax
    1070:       f3 0f 1e fa             endbr64
    1074:       68 04 00 00 00          push   $0x4
    1079:       e9 a2 ff ff ff          jmp    1020 <_init+0x20>
    107e:       66 90                   xchg   %ax,%ax

```

`.got`:  

```

zoe@HUANGZS7-2V8W0R:~/workspace/compling_lab$ objdump -sj .got elf_shared

elf_shared:     file format elf64-x86-64

Contents of section .got:
 3f98 883d0000 00000000 00000000 00000000  .=..............
 3fa8 00000000 00000000 30100000 00000000  ........0.......
 3fb8 40100000 00000000 50100000 00000000  @.......P.......
 3fc8 60100000 00000000 70100000 00000000  `.......p.......
 3fd8 00000000 00000000 00000000 00000000  ................
 3fe8 00000000 00000000 00000000 00000000  ................
 3ff8 00000000 00000000

```


`.plt.sec`

```asm

zoe@HUANGZS7-2V8W0R:~/workspace/compling_lab$ objdump -dj .plt.sec elf_shared

elf_shared:     file format elf64-x86-64


Disassembly of section .plt.sec:

0000000000001090 <update_counter@plt>:
    1090:       f3 0f 1e fa             endbr64
    1094:       ff 25 16 2f 00 00       jmp    *0x2f16(%rip)        # 3fb0 <update_counter@Base>
    109a:       66 0f 1f 44 00 00       nopw   0x0(%rax,%rax,1)

00000000000010a0 <add@plt>:
    10a0:       f3 0f 1e fa             endbr64
    10a4:       ff 25 0e 2f 00 00       jmp    *0x2f0e(%rip)        # 3fb8 <add@Base>
    10aa:       66 0f 1f 44 00 00       nopw   0x0(%rax,%rax,1)

00000000000010b0 <multiply@plt>:
    10b0:       f3 0f 1e fa             endbr64
    10b4:       ff 25 06 2f 00 00       jmp    *0x2f06(%rip)        # 3fc0 <multiply@Base>
    10ba:       66 0f 1f 44 00 00       nopw   0x0(%rax,%rax,1)

00000000000010c0 <puts@plt>:
    10c0:       f3 0f 1e fa             endbr64
    10c4:       ff 25 fe 2e 00 00       jmp    *0x2efe(%rip)        # 3fc8 <puts@GLIBC_2.2.5>
    10ca:       66 0f 1f 44 00 00       nopw   0x0(%rax,%rax,1)

00000000000010d0 <printf@plt>:
    10d0:       f3 0f 1e fa             endbr64
    10d4:       ff 25 f6 2e 00 00       jmp    *0x2ef6(%rip)        # 3fd0 <printf@GLIBC_2.2.5>
    10da:       66 0f 1f 44 00 00       nopw   0x0(%rax,%rax,1)
```

这三个部分如此协作：  

在支持延迟绑定的初始状态下：  

```
main
  │ call add@plt
  ▼
.plt.sec: 0x10a0
  │ jmp *GOT[0x3fb8]
  ▼
GOT[0x3fb8] 初始值 = 0x1040
  ▼
.plt: 0x1040
  │ push 1
  │ jmp 0x1020
  ▼
PLT0
  │ 传递当前模块信息
  │ 跳转到动态链接器
  ▼
ld.so 解析 add
  │ 将 add 的真实地址写入 GOT[0x3fb8]
  ▼
libcalc.so:add
```

完成解析后，下次一调用将变为：  

```
main
  → .plt.sec:add@plt
  → GOT[0x3fb8]
  → libcalc.so:add
```

也就是说，所有的函数调用流程如下：  
1. 调用 function@plt（跳转到 .plt.sec）
2. .plt.sec 中对应位置将执行 jump *GOT[对应位置]，也就是说 .plt.sec 中对应的 entry 将跳转到 got[index + 3] 所指向的位置
3. 一开始，*got[index + 3] == 对应的 .plt entry
4. .plt entry 将 push index，随后 jump plt[0]，plt[0] 是所有 plt entry 共享的跳转地址
5. plt[0] 将压入 GOT[1] 中保存的当前模块的动态链接上下文，随后跳转到 GOT[2] 中保存的动态解析器入口
6. 文件中这两项均为 0 → 因为运行时地址在静态链接阶段无法确定 → ld.so 加载程序后才会初始化内存中的相应槽位
7. got[0]的含义？

当动态链接器将函数的真正地址回调到got表中后，在第二步就将直接跳转到对应函数的位置。  

## loading

首先区分**动态链接器**和**动态库**  

**动态链接器**是负责“加载和连接”的特殊运行时程序，例如 x86-64 Linux 上的 `/lib64/ld-linux-x86-64.so.2`；**动态库**则是被加载和使用的共享对象，例如 `libcalc.so`、`libc.so.6`。内核通过主程序的 `PT_INTERP` 指定并加载动态链接器，动态链接器再读取主程序 `.dynamic` 中的 `DT_NEEDED` 项，查找并加载其依赖的动态库，随后完成符号解析、重定位和初始化。

| 对比项       | 动态链接器                         | 动态库                                                   |
| --------- | ----------------------------- | ----------------------------------------------------- |
| 典型文件      | `/lib64/ld-linux-x86-64.so.2` | `libcalc.so`、`libc.so.6`                              |
| 本质        | 特殊的可执行 ELF 程序                 | ELF 共享对象                                              |
| 主要作用      | 加载共享库、解析符号、执行重定位、调用初始化函数      | 提供函数和全局变量的具体实现                                        |
| 谁加载它      | Linux 内核根据 `PT_INTERP` 加载     | 动态链接器根据 `DT_NEEDED` 加载                                |
| 是否由普通程序调用 | 通常不直接调用                       | 程序通过 PLT/GOT 调用其中函数                                   |
| 在当前实验中的角色 | 负责装载 `elf_shared` 的依赖         | `libcalc.so` 提供 `add` 等符号，`libc.so.6` 提供 `printf` 等符号 |

`glibc` 是完整的软件包；`libc.so.6` 是其中提供 `C` 运行库功能的共享库；`ld-linux-x86-64.so.2` 是其中负责装载和连接共享库的动态链接器。二者通常应当来自兼容的 `glibc` 版本.  
运行  

```sh
LD_DEBUG=libs,reloc,bindings ./elf_shared 2> loader.log
```

`LD_DEBUG=libs,reloc,bindings` 要求 `glibc` `动态链接器` 输出 `共享库` 搜索、`重定位` 处理和 `符号绑定` 过程；  
2> `loader.log` 将这些信息从 `标准错误` 重定向到文件。  
该日志可以按程序启动顺序阅读：  
加载依赖库 → 处理各模块 `重定位` → `绑定符号` → 调用 `初始化函数` → 将控制权交给程序 → 程序结束后调用 `终止函数`。  

- `LD_DEBUG=libs`：显示动态库的搜索路径、尝试路径和最终选中的库。
- `LD_DEBUG=reloc`：显示动态链接器正在对哪个 `ELF` 模块进行重定位。
- `LD_DEBUG=bindings`：显示每个符号引用最终绑定到哪个模块的定义。

`loader.log`:  

```
     53171:	binding file linux-vdso.so.1 [0] to linux-vdso.so.1 [0]: normal symbol `__vdso_clock_gettime' [LINUX_2.6]
     53171:	binding file linux-vdso.so.1 [0] to linux-vdso.so.1 [0]: normal symbol `__vdso_gettimeofday' [LINUX_2.6]
     53171:	binding file linux-vdso.so.1 [0] to linux-vdso.so.1 [0]: normal symbol `__vdso_time' [LINUX_2.6]
     53171:	binding file linux-vdso.so.1 [0] to linux-vdso.so.1 [0]: normal symbol `__vdso_getcpu' [LINUX_2.6]
     53171:	binding file linux-vdso.so.1 [0] to linux-vdso.so.1 [0]: normal symbol `__vdso_clock_getres' [LINUX_2.6]

/*
 * 首先根据 DT_NEEDED 搜索动态库
 * 这里是 libcalc.so 和 lib.so.6
 * $ readelf -d elf_shared
 *
 * Dynamic section at offset 0x2d88 contains 29 entries:
 *   Tag        Type                         Name/Value
 *  0x0000000000000001 (NEEDED)   Shared library: [libcalc.so]
 *  0x0000000000000001 (NEEDED)   Shared library: [libc.so.6]
 *  0x000000000000001d (RUNPATH)  Library runpath: [$ORIGIN]
 */

     53171:	find library=libcalc.so [0]; searching
     53171:	 search path=/home/zoe/workspace/compling_lab/glibc-hwcaps/x86-64-v3:/home/zoe/workspace/compling_lab/glibc-hwcaps/x86-64-v2:/home/zoe/workspace/compling_lab		(RUNPATH from file ./elf_shared)
     53171:	  trying file=/home/zoe/workspace/compling_lab/glibc-hwcaps/x86-64-v3/libcalc.so
     53171:	  trying file=/home/zoe/workspace/compling_lab/glibc-hwcaps/x86-64-v2/libcalc.so
     53171:	  trying file=/home/zoe/workspace/compling_lab/libcalc.so
     53171:
     53171:	find library=libc.so.6 [0]; searching
     53171:	 search path=/home/zoe/workspace/compling_lab		(RUNPATH from file ./elf_shared)
     53171:	  trying file=/home/zoe/workspace/compling_lab/libc.so.6
     53171:	 search cache=/etc/ld.so.cache
     53171:	  trying file=/lib/x86_64-linux-gnu/libc.so.6
     53171:
     53171:
/*
 * 开始处理动态重定位
 * 顺序为：
 *   libc.so.6
 *   libcalc.so
 *   elf_shared
 *   ld-linux-x86-64.so.2
 */

     53171:	relocation processing: /lib/x86_64-linux-gnu/libc.so.6

/* binding 格式：
 * binding file 引用方 [命名空间]
 * to 定义方 [命名空间]:
 * 绑定类型 symbol `符号名' [符号版本]
 *
 * | 字段                    | 含义                       |
 * | ----------------------- | -------------------------- |
 * | `binding file` 后的路径 | 引用该符号的 ELF 模块      |
 * | `to` 后的路径           | 最终提供符号定义的 ELF 模块 |
 * | `[0]`                   | 基础动态链接命名空间       |
 * | `normal symbol`         | 普通符号绑定               |
 * | 反引号中的名称           | 被解析的符号               |
 * | `[GLIBC_x.y]`           | 要求或匹配的符号版本       |


为什么这里libc还要将符号“重定位到自己”？

| 原因 | 说明 |
|---|---|
| 位置无关 | 加载地址运行时才知，GOT/PLT 必须由动态链接器填写 |
| 符号插入语义 | 全局符号以“先到先得”裁决，libc 不能假设自己赢（LD_PRELOAD、copy relocation 都可能改变结果） |
| 跨库依赖 | `GLIBC_PRIVATE` 符号实际定义在 `ld.so` 中 |
| 延迟绑定 | 函数符号首次调用时才解析 |
 */

     53171:	binding file /lib/x86_64-linux-gnu/libc.so.6 [0] to /lib/x86_64-linux-gnu/libc.so.6 [0]: normal symbol `_res' [GLIBC_2.2.5]
     53171:	binding file /lib/x86_64-linux-gnu/libc.so.6 [0] to /lib/x86_64-linux-gnu/libc.so.6 [0]: normal symbol `svc_max_pollfd' [GLIBC_2.2.5]
     53171:	binding file /lib/x86_64-linux-gnu/libc.so.6 [0] to /lib/x86_64-linux-gnu/libc.so.6 [0]: normal symbol `obstack_alloc_failed_handler' [GLIBC_2.2.5]
     53171:	binding file /lib/x86_64-linux-gnu/libc.so.6 [0] to /lib/x86_64-linux-gnu/libc.so.6 [0]: normal symbol `__ctype_toupper' [GLIBC_2.2.5]
     53171:	binding file /lib/x86_64-linux-gnu/libc.so.6 [0] to /lib/x86_64-linux-gnu/libc.so.6 [0]: normal symbol `loc1' [GLIBC_2.2.5]
     53171:	binding file /lib/x86_64-linux-gnu/libc.so.6 [0] to /lib64/ld-linux-x86-64.so.2 [0]: normal symbol `_dl_argv' [GLIBC_PRIVATE]
     53171:	binding file /lib/x86_64-linux-gnu/libc.so.6 [0] to /lib/x86_64-linux-gnu/libc.so.6 [0]: normal symbol `__libc_single_threaded' [GLIBC_2.32]
     53171:	binding file /lib/x86_64-linux-gnu/libc.so.6 [0] to /lib/x86_64-linux-gnu/libc.so.6 [0]: normal symbol `free' [GLIBC_2.2.5]
     53171:	binding file /lib/x86_64-linux-gnu/libc.so.6 [0] to /lib/x86_64-linux-gnu/libc.so.6 [0]: normal symbol `re_syntax_options' [GLIBC_2.2.5]
     53171:	binding file /lib/x86_64-linux-gnu/libc.so.6 [0] to /lib/x86_64-linux-gnu/libc.so.6 [0]: normal symbol `rpc_createerr' [GLIBC_2.2.5]
     53171:	binding file /lib/x86_64-linux-gnu/libc.so.6 [0] to /lib/x86_64-linux-gnu/libc.so.6 [0]: normal symbol `stdout' [GLIBC_2.2.5]
     53171:	binding file /lib/x86_64-linux-gnu/libc.so.6 [0] to /lib/x86_64-linux-gnu/libc.so.6 [0]: normal symbol `__ctype32_toupper' [GLIBC_2.2.5]
     53171:	binding file /lib/x86_64-linux-gnu/libc.so.6 [0] to /lib/x86_64-linux-gnu/libc.so.6 [0]: normal symbol `opterr' [GLIBC_2.2.5]
     53171:	binding file /lib/x86_64-linux-gnu/libc.so.6 [0] to /lib/x86_64-linux-gnu/libc.so.6 [0]: normal symbol `getdate_err' [GLIBC_2.2.5]
     53171:	binding file /lib/x86_64-linux-gnu/libc.so.6 [0] to /lib/x86_64-linux-gnu/libc.so.6 [0]: normal symbol `__curbrk' [GLIBC_2.2.5]
     53171:	binding file /lib/x86_64-linux-gnu/libc.so.6 [0] to /lib/x86_64-linux-gnu/libc.so.6 [0]: normal symbol `loc2' [GLIBC_2.2.5]
     53171:	binding file /lib/x86_64-linux-gnu/libc.so.6 [0] to /lib/x86_64-linux-gnu/libc.so.6 [0]: normal symbol `program_invocation_name' [GLIBC_2.2.5]
     53171:	binding file /lib/x86_64-linux-gnu/libc.so.6 [0] to /lib/x86_64-linux-gnu/libc.so.6 [0]: normal symbol `__fpu_control' [GLIBC_2.2.5]
     53171:	binding file /lib/x86_64-linux-gnu/libc.so.6 [0] to /lib64/ld-linux-x86-64.so.2 [0]: normal symbol `__libc_enable_secure' [GLIBC_PRIVATE]
     53171:	binding file /lib/x86_64-linux-gnu/libc.so.6 [0] to /lib/x86_64-linux-gnu/libc.so.6 [0]: normal symbol `_IO_2_1_stderr_' [GLIBC_2.2.5]
     53171:	binding file /lib/x86_64-linux-gnu/libc.so.6 [0] to /lib/x86_64-linux-gnu/libc.so.6 [0]: normal symbol `__rcmd_errstr' [GLIBC_2.2.5]
     53171:	binding file /lib/x86_64-linux-gnu/libc.so.6 [0] to /lib/x86_64-linux-gnu/libc.so.6 [0]: normal symbol `__ctype_b' [GLIBC_2.2.5]
     53171:	binding file /lib/x86_64-linux-gnu/libc.so.6 [0] to /lib/x86_64-linux-gnu/libc.so.6 [0]: normal symbol `error_print_progname' [GLIBC_2.2.5]
     53171:	binding file /lib/x86_64-linux-gnu/libc.so.6 [0] to /lib/x86_64-linux-gnu/libc.so.6 [0]: normal symbol `stderr' [GLIBC_2.2.5]
     53171:	binding file /lib/x86_64-linux-gnu/libc.so.6 [0] to /lib/x86_64-linux-gnu/libc.so.6 [0]: normal symbol `obstack_exit_failure' [GLIBC_2.2.5]
     53171:	binding file /lib/x86_64-linux-gnu/libc.so.6 [0] to /lib64/ld-linux-x86-64.so.2 [0]: normal symbol `__libc_stack_end' [GLIBC_2.2.5]
     53171:	binding file /lib/x86_64-linux-gnu/libc.so.6 [0] to /lib/x86_64-linux-gnu/libc.so.6 [0]: normal symbol `__key_encryptsession_pk_LOCAL' [GLIBC_2.2.5]
     53171:	binding file /lib/x86_64-linux-gnu/libc.so.6 [0] to /lib64/ld-linux-x86-64.so.2 [0]: normal symbol `_rtld_global_ro' [GLIBC_PRIVATE]
     53171:	binding file /lib/x86_64-linux-gnu/libc.so.6 [0] to /lib/x86_64-linux-gnu/libc.so.6 [0]: normal symbol `argp_program_version' [GLIBC_2.2.5]
     53171:	binding file /lib/x86_64-linux-gnu/libc.so.6 [0] to /lib/x86_64-linux-gnu/libc.so.6 [0]: normal symbol `svcauthdes_stats' [GLIBC_2.2.5]
     53171:	binding file /lib/x86_64-linux-gnu/libc.so.6 [0] to /lib/x86_64-linux-gnu/libc.so.6 [0]: normal symbol `__check_rhosts_file' [GLIBC_2.2.5]
     53171:	binding file /lib/x86_64-linux-gnu/libc.so.6 [0] to /lib/x86_64-linux-gnu/libc.so.6 [0]: normal symbol `optind' [GLIBC_2.2.5]
     53171:	binding file /lib/x86_64-linux-gnu/libc.so.6 [0] to /lib/x86_64-linux-gnu/libc.so.6 [0]: normal symbol `_IO_2_1_stdin_' [GLIBC_2.2.5]
     53171:	binding file /lib/x86_64-linux-gnu/libc.so.6 [0] to /lib/x86_64-linux-gnu/libc.so.6 [0]: normal symbol `program_invocation_short_name' [GLIBC_2.2.5]
     53171:	binding file /lib/x86_64-linux-gnu/libc.so.6 [0] to /lib/x86_64-linux-gnu/libc.so.6 [0]: normal symbol `__ctype32_tolower' [GLIBC_2.2.5]
     53171:	binding file /lib/x86_64-linux-gnu/libc.so.6 [0] to /lib/x86_64-linux-gnu/libc.so.6 [0]: normal symbol `error_message_count' [GLIBC_2.2.5]
     53171:	binding file /lib/x86_64-linux-gnu/libc.so.6 [0] to /lib/x86_64-linux-gnu/libc.so.6 [0]: normal symbol `optopt' [GLIBC_2.2.5]
     53171:	binding file /lib/x86_64-linux-gnu/libc.so.6 [0] to /lib/x86_64-linux-gnu/libc.so.6 [0]: normal symbol `__ctype32_b' [GLIBC_2.2.5]
     53171:	binding file /lib/x86_64-linux-gnu/libc.so.6 [0] to /lib/x86_64-linux-gnu/libc.so.6 [0]: normal symbol `_nl_msg_cat_cntr' [GLIBC_2.2.5]
     53171:	binding file /lib/x86_64-linux-gnu/libc.so.6 [0] to /lib/x86_64-linux-gnu/libc.so.6 [0]: normal symbol `__daylight' [GLIBC_2.2.5]
     53171:	binding file /lib/x86_64-linux-gnu/libc.so.6 [0] to /lib/x86_64-linux-gnu/libc.so.6 [0]: normal symbol `_nl_domain_bindings' [GLIBC_2.2.5]
     53171:	binding file /lib/x86_64-linux-gnu/libc.so.6 [0] to /lib/x86_64-linux-gnu/libc.so.6 [0]: normal symbol `argp_program_bug_address' [GLIBC_2.2.5]
     53171:	binding file /lib/x86_64-linux-gnu/libc.so.6 [0] to /lib/x86_64-linux-gnu/libc.so.6 [0]: normal symbol `_IO_funlockfile' [GLIBC_2.2.5]
     53171:	binding file /lib/x86_64-linux-gnu/libc.so.6 [0] to /lib/x86_64-linux-gnu/libc.so.6 [0]: normal symbol `svc_fdset' [GLIBC_2.2.5]
     53171:	binding file /lib/x86_64-linux-gnu/libc.so.6 [0] to /lib/x86_64-linux-gnu/libc.so.6 [0]: normal symbol `__libc_dlerror_result' [GLIBC_PRIVATE]
     53171:	binding file /lib/x86_64-linux-gnu/libc.so.6 [0] to /lib/x86_64-linux-gnu/libc.so.6 [0]: normal symbol `stdin' [GLIBC_2.2.5]
     53171:	binding file /lib/x86_64-linux-gnu/libc.so.6 [0] to /lib/x86_64-linux-gnu/libc.so.6 [0]: normal symbol `__timezone' [GLIBC_2.2.5]
     53171:	binding file /lib/x86_64-linux-gnu/libc.so.6 [0] to /lib/x86_64-linux-gnu/libc.so.6 [0]: normal symbol `__ctype_tolower' [GLIBC_2.2.5]
     53171:	binding file /lib/x86_64-linux-gnu/libc.so.6 [0] to /lib/x86_64-linux-gnu/libc.so.6 [0]: normal symbol `_IO_2_1_stdout_' [GLIBC_2.2.5]
     53171:	binding file /lib/x86_64-linux-gnu/libc.so.6 [0] to /lib/x86_64-linux-gnu/libc.so.6 [0]: normal symbol `__tzname' [GLIBC_2.2.5]
     53171:	binding file /lib/x86_64-linux-gnu/libc.so.6 [0] to /lib/x86_64-linux-gnu/libc.so.6 [0]: normal symbol `error_one_per_line' [GLIBC_2.2.5]
     53171:	binding file /lib/x86_64-linux-gnu/libc.so.6 [0] to /lib/x86_64-linux-gnu/libc.so.6 [0]: normal symbol `_res_hconf' [GLIBC_2.2.5]
     53171:	binding file /lib/x86_64-linux-gnu/libc.so.6 [0] to /lib/x86_64-linux-gnu/libc.so.6 [0]: normal symbol `__key_decryptsession_pk_LOCAL' [GLIBC_2.2.5]
     53171:	binding file /lib/x86_64-linux-gnu/libc.so.6 [0] to /lib64/ld-linux-x86-64.so.2 [0]: normal symbol `_rtld_global' [GLIBC_PRIVATE]
     53171:	binding file /lib/x86_64-linux-gnu/libc.so.6 [0] to /lib/x86_64-linux-gnu/libc.so.6 [0]: normal symbol `__progname' [GLIBC_2.2.5]
     53171:	binding file /lib/x86_64-linux-gnu/libc.so.6 [0] to /lib/x86_64-linux-gnu/libc.so.6 [0]: normal symbol `h_errlist' [GLIBC_2.2.5]
     53171:	binding file /lib/x86_64-linux-gnu/libc.so.6 [0] to /lib/x86_64-linux-gnu/libc.so.6 [0]: normal symbol `__environ' [GLIBC_2.2.5]
     53171:	binding file /lib/x86_64-linux-gnu/libc.so.6 [0] to /lib/x86_64-linux-gnu/libc.so.6 [0]: normal symbol `argp_err_exit_status' [GLIBC_2.2.5]
     53171:	binding file /lib/x86_64-linux-gnu/libc.so.6 [0] to /lib/x86_64-linux-gnu/libc.so.6 [0]: normal symbol `svc_pollfd' [GLIBC_2.2.5]
     53171:	binding file /lib/x86_64-linux-gnu/libc.so.6 [0] to /lib/x86_64-linux-gnu/libc.so.6 [0]: normal symbol `__progname_full' [GLIBC_2.2.5]
     53171:	binding file /lib/x86_64-linux-gnu/libc.so.6 [0] to /lib/x86_64-linux-gnu/libc.so.6 [0]: normal symbol `argp_program_version_hook' [GLIBC_2.2.5]
     53171:	binding file /lib/x86_64-linux-gnu/libc.so.6 [0] to /lib/x86_64-linux-gnu/libc.so.6 [0]: normal symbol `optarg' [GLIBC_2.2.5]
     53171:	binding file /lib/x86_64-linux-gnu/libc.so.6 [0] to /lib/x86_64-linux-gnu/libc.so.6 [0]: normal symbol `malloc' [GLIBC_2.2.5]
     53171:	binding file /lib/x86_64-linux-gnu/libc.so.6 [0] to /lib/x86_64-linux-gnu/libc.so.6 [0]: normal symbol `realloc' [GLIBC_2.2.5]
     53171:	binding file /lib/x86_64-linux-gnu/libc.so.6 [0] to /lib/x86_64-linux-gnu/libc.so.6 [0]: normal symbol `calloc' [GLIBC_2.2.5]
     53171:	binding file /lib/x86_64-linux-gnu/libc.so.6 [0] to /lib64/ld-linux-x86-64.so.2 [0]: normal symbol `_dl_find_dso_for_object' [GLIBC_PRIVATE]
     53171:	binding file /lib/x86_64-linux-gnu/libc.so.6 [0] to /lib64/ld-linux-x86-64.so.2 [0]: normal symbol `_dl_deallocate_tls' [GLIBC_PRIVATE]
     53171:	binding file /lib/x86_64-linux-gnu/libc.so.6 [0] to /lib64/ld-linux-x86-64.so.2 [0]: normal symbol `__tls_get_addr' [GLIBC_2.3]
     53171:	binding file /lib/x86_64-linux-gnu/libc.so.6 [0] to /lib64/ld-linux-x86-64.so.2 [0]: normal symbol `_dl_signal_error' [GLIBC_PRIVATE]
     53171:	binding file /lib/x86_64-linux-gnu/libc.so.6 [0] to /lib64/ld-linux-x86-64.so.2 [0]: normal symbol `_dl_signal_exception' [GLIBC_PRIVATE]
     53171:	binding file /lib/x86_64-linux-gnu/libc.so.6 [0] to /lib64/ld-linux-x86-64.so.2 [0]: normal symbol `_dl_audit_symbind_alt' [GLIBC_PRIVATE]
     53171:	binding file /lib/x86_64-linux-gnu/libc.so.6 [0] to /lib64/ld-linux-x86-64.so.2 [0]: normal symbol `__tunable_is_initialized' [GLIBC_PRIVATE]
     53171:	binding file /lib/x86_64-linux-gnu/libc.so.6 [0] to /lib64/ld-linux-x86-64.so.2 [0]: normal symbol `_dl_rtld_di_serinfo' [GLIBC_PRIVATE]
     53171:	binding file /lib/x86_64-linux-gnu/libc.so.6 [0] to /lib64/ld-linux-x86-64.so.2 [0]: normal symbol `_dl_allocate_tls' [GLIBC_PRIVATE]
     53171:	binding file /lib/x86_64-linux-gnu/libc.so.6 [0] to /lib64/ld-linux-x86-64.so.2 [0]: normal symbol `__tunable_get_val' [GLIBC_PRIVATE]
     53171:	binding file /lib/x86_64-linux-gnu/libc.so.6 [0] to /lib64/ld-linux-x86-64.so.2 [0]: normal symbol `_dl_catch_exception' [GLIBC_PRIVATE]
     53171:	binding file /lib/x86_64-linux-gnu/libc.so.6 [0] to /lib64/ld-linux-x86-64.so.2 [0]: normal symbol `_dl_allocate_tls_init' [GLIBC_PRIVATE]
     53171:	binding file /lib/x86_64-linux-gnu/libc.so.6 [0] to /lib64/ld-linux-x86-64.so.2 [0]: normal symbol `__nptl_change_stack_perm' [GLIBC_PRIVATE]
     53171:	binding file /lib/x86_64-linux-gnu/libc.so.6 [0] to /lib64/ld-linux-x86-64.so.2 [0]: normal symbol `_dl_audit_preinit' [GLIBC_PRIVATE]
     53171:
     53171:	relocation processing: /home/zoe/workspace/compling_lab/libcalc.so (lazy)
     53171:	binding file /home/zoe/workspace/compling_lab/libcalc.so [0] to /lib/x86_64-linux-gnu/libc.so.6 [0]: normal symbol `__cxa_finalize'
     53171:	binding file /home/zoe/workspace/compling_lab/libcalc.so [0] to ./elf_shared [0]: normal symbol `global_counter'
     53171:	binding file /home/zoe/workspace/compling_lab/libcalc.so [0] to ./elf_shared [0]: normal symbol `uninitialized_value'
     53171:
/*
 * 将 elf_shared 中涉及的符号引用绑定到对应的实现中。
 *
 * 这里涉及两个文件：
 *   - libcalc.so：这是我们自己写的 shared object file。
 *   - libc.so.6：这是 glibc 生成的 shared object file。
 */
     53171:	relocation processing: ./elf_shared
     53171:	binding file ./elf_shared [0] to /lib/x86_64-linux-gnu/libc.so.6 [0]: normal symbol `__libc_start_main' [GLIBC_2.34]
     53171:	binding file ./elf_shared [0] to /lib/x86_64-linux-gnu/libc.so.6 [0]: normal symbol `__cxa_finalize' [GLIBC_2.2.5]
     53171:	binding file ./elf_shared [0] to /home/zoe/workspace/compling_lab/libcalc.so [0]: normal symbol `uninitialized_value'
     53171:	binding file ./elf_shared [0] to /home/zoe/workspace/compling_lab/libcalc.so [0]: normal symbol `global_counter'
     53171:	binding file ./elf_shared [0] to /home/zoe/workspace/compling_lab/libcalc.so [0]: normal symbol `update_counter'
     53171:	binding file ./elf_shared [0] to /home/zoe/workspace/compling_lab/libcalc.so [0]: normal symbol `add'
     53171:	binding file ./elf_shared [0] to /home/zoe/workspace/compling_lab/libcalc.so [0]: normal symbol `multiply'
/* Implemented in libc.so.6 */
     53171:	binding file ./elf_shared [0] to /lib/x86_64-linux-gnu/libc.so.6 [0]: normal symbol `puts' [GLIBC_2.2.5]
     53171:	binding file ./elf_shared [0] to /lib/x86_64-linux-gnu/libc.so.6 [0]: normal symbol `printf' [GLIBC_2.2.5]
     53171:	binding file ./elf_shared [0] to /lib/x86_64-linux-gnu/libc.so.6 [0]: normal symbol `calloc' [GLIBC_2.2.5]
     53171:	binding file ./elf_shared [0] to /lib/x86_64-linux-gnu/libc.so.6 [0]: normal symbol `free' [GLIBC_2.2.5]
     53171:	binding file ./elf_shared [0] to /lib/x86_64-linux-gnu/libc.so.6 [0]: normal symbol `malloc' [GLIBC_2.2.5]
     53171:	binding file ./elf_shared [0] to /lib/x86_64-linux-gnu/libc.so.6 [0]: normal symbol `realloc' [GLIBC_2.2.5]
     53171:
     53171:	relocation processing: /lib64/ld-linux-x86-64.so.2
     53171:	binding file /lib64/ld-linux-x86-64.so.2 [0] to /lib64/ld-linux-x86-64.so.2 [0]: normal symbol `__rseq_offset' [GLIBC_2.35]
     53171:	binding file /lib64/ld-linux-x86-64.so.2 [0] to /lib64/ld-linux-x86-64.so.2 [0]: normal symbol `__rseq_size' [GLIBC_2.35]
     53171:
     53171:	calling init: /lib64/ld-linux-x86-64.so.2
     53171:
     53171:
     53171:	calling init: /lib/x86_64-linux-gnu/libc.so.6
     53171:
     53171:
     53171:	calling init: /home/zoe/workspace/compling_lab/libcalc.so
     53171:
     53171:
     53171:	initialize program: ./elf_shared
     53171:
     53171:
     53171:	transferring control: ./elf_shared
     53171:
     53171:
     53171:	calling fini:  [0]
     53171:
     53171:
     53171:	calling fini: /home/zoe/workspace/compling_lab/libcalc.so [0]
     53171:
     53171:
     53171:	calling fini: /lib/x86_64-linux-gnu/libc.so.6 [0]
     53171:
     53171:
     53171:	calling fini: /lib64/ld-linux-x86-64.so.2 [0]
     53171:
```

`elf_shared`的`.rela.dyn`和`.rela.plt`为：  
```
zoe@HUANGZS7-2V8W0R:~/workspace/compling_lab$ readelf -r elf_shared

Relocation section '.rela.dyn' at offset 0x648 contains 10 entries:
  Offset          Info           Type           Sym. Value    Sym. Name + Addend
000000003d78  000000000008 R_X86_64_RELATIVE                    11c0
000000003d80  000000000008 R_X86_64_RELATIVE                    1180
000000004008  000000000008 R_X86_64_RELATIVE                    4008
000000003fd8  000200000006 R_X86_64_GLOB_DAT 0000000000000000 __libc_start_main@GLIBC_2.34 + 0
000000003fe0  000300000006 R_X86_64_GLOB_DAT 0000000000000000 _ITM_deregisterTM[...] + 0
000000003fe8  000800000006 R_X86_64_GLOB_DAT 0000000000000000 __gmon_start__ + 0
000000003ff0  000900000006 R_X86_64_GLOB_DAT 0000000000000000 _ITM_registerTMCl[...] + 0
000000003ff8  000b00000006 R_X86_64_GLOB_DAT 0000000000000000 __cxa_finalize@GLIBC_2.2.5 + 0
000000004018  000a00000005 R_X86_64_COPY     0000000000004018 uninitialized_value + 0
000000004020  000c00000005 R_X86_64_COPY     0000000000004020 global_counter + 0

Relocation section '.rela.plt' at offset 0x738 contains 5 entries:
  Offset          Info           Type           Sym. Value    Sym. Name + Addend
000000003fb0  000100000007 R_X86_64_JUMP_SLO 0000000000000000 update_counter + 0
000000003fb8  000400000007 R_X86_64_JUMP_SLO 0000000000000000 add + 0
000000003fc0  000500000007 R_X86_64_JUMP_SLO 0000000000000000 multiply + 0
000000003fc8  000600000007 R_X86_64_JUMP_SLO 0000000000000000 puts@GLIBC_2.2.5 + 0
000000003fd0  000700000007 R_X86_64_JUMP_SLO 0000000000000000 printf@GLIBC_2.2.5 + 0
```

使用`strace`跟踪`elf_shared`的执行过程：  
```sh
strace -f -e trace=execve,openat,mmap,mprotect,brk ./elf_shared
```

输出：  

```

zoe@HUANGZS7-2V8W0R:~/workspace/compling_lab$ strace -f -e trace=execve,openat,mmap,mprotect,brk ./elf_shared
execve("./elf_shared", ["./elf_shared"], 0x7ffdfd1d3368 /* 35 vars */) = 0
brk(NULL)                               = 0x61f90f66f000
mmap(NULL, 8192, PROT_READ|PROT_WRITE, MAP_PRIVATE|MAP_ANONYMOUS, -1, 0) = 0x7f46eab92000
openat(AT_FDCWD, "/home/zoe/workspace/compling_lab/glibc-hwcaps/x86-64-v3/libcalc.so", O_RDONLY|O_CLOEXEC) = -1 ENOENT (No such file or directory)
openat(AT_FDCWD, "/home/zoe/workspace/compling_lab/glibc-hwcaps/x86-64-v2/libcalc.so", O_RDONLY|O_CLOEXEC) = -1 ENOENT (No such file or directory)
openat(AT_FDCWD, "/home/zoe/workspace/compling_lab/libcalc.so", O_RDONLY|O_CLOEXEC) = 3
mmap(NULL, 16408, PROT_READ, MAP_PRIVATE|MAP_DENYWRITE, 3, 0) = 0x7f46eab8d000
mmap(0x7f46eab8e000, 4096, PROT_READ|PROT_EXEC, MAP_PRIVATE|MAP_FIXED|MAP_DENYWRITE, 3, 0x1000) = 0x7f46eab8e000
mmap(0x7f46eab8f000, 4096, PROT_READ, MAP_PRIVATE|MAP_FIXED|MAP_DENYWRITE, 3, 0x2000) = 0x7f46eab8f000
mmap(0x7f46eab90000, 8192, PROT_READ|PROT_WRITE, MAP_PRIVATE|MAP_FIXED|MAP_DENYWRITE, 3, 0x2000) = 0x7f46eab90000
openat(AT_FDCWD, "/home/zoe/workspace/compling_lab/libc.so.6", O_RDONLY|O_CLOEXEC) = -1 ENOENT (No such file or directory)
openat(AT_FDCWD, "/etc/ld.so.cache", O_RDONLY|O_CLOEXEC) = 3
mmap(NULL, 26115, PROT_READ, MAP_PRIVATE, 3, 0) = 0x7f46eab86000
openat(AT_FDCWD, "/lib/x86_64-linux-gnu/libc.so.6", O_RDONLY|O_CLOEXEC) = 3
mmap(NULL, 2174352, PROT_READ, MAP_PRIVATE|MAP_DENYWRITE, 3, 0) = 0x7f46ea800000
mmap(0x7f46ea828000, 1609728, PROT_READ|PROT_EXEC, MAP_PRIVATE|MAP_FIXED|MAP_DENYWRITE, 3, 0x28000) = 0x7f46ea828000
mmap(0x7f46ea9b1000, 323584, PROT_READ, MAP_PRIVATE|MAP_FIXED|MAP_DENYWRITE, 3, 0x1b1000) = 0x7f46ea9b1000
mmap(0x7f46eaa00000, 24576, PROT_READ|PROT_WRITE, MAP_PRIVATE|MAP_FIXED|MAP_DENYWRITE, 3, 0x1ff000) = 0x7f46eaa00000
mmap(0x7f46eaa06000, 52624, PROT_READ|PROT_WRITE, MAP_PRIVATE|MAP_FIXED|MAP_ANONYMOUS, -1, 0) = 0x7f46eaa06000
mmap(NULL, 12288, PROT_READ|PROT_WRITE, MAP_PRIVATE|MAP_ANONYMOUS, -1, 0) = 0x7f46eab83000
mprotect(0x7f46eaa00000, 16384, PROT_READ) = 0
mprotect(0x7f46eab90000, 4096, PROT_READ) = 0
mprotect(0x61f8fe156000, 4096, PROT_READ) = 0
mprotect(0x7f46eabd2000, 8192, PROT_READ) = 0
brk(NULL)                               = 0x61f90f66f000
brk(0x61f90f690000)                     = 0x61f90f690000
ELF compilation and linking laboratory
add(6, 7) = 13
multiply(6, 7) = 42
global_counter = 110
uninitialized_value = 3
+++ exited with 0 +++

```

