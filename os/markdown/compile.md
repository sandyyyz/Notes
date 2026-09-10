# *.c -> elf

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

## assemble

使用`$cc -c`选项将c文件编译至.o文件后停止。  

