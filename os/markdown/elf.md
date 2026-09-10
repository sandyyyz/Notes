# ELF 文件格式核心要点

> 来源：《Executable and Linking Format (ELF) Specification, Version 1.2》，TIS Committee, May 1995（76 页正文，共 106 页）。
> 本文用凝练语言提炼 ELF（Executable and Linking Format）最核心的概念，帮助建立对 ELF 文件格式的基本认识。主要面向 32 位架构（Intel Architecture / System V），现行 64 位格式在布局逻辑上一致。

##  ELF

ELF 是一种**可执行与可链接文件格式**，最初由 UNIX System Laboratories 作为 ABI 的一部分发布，后由 TIS 委员会标准化。它是 Linux/Unix 等系统中目标文件、可执行文件和共享库的通用二进制格式。一条核心设计原则是：**同一文件从"链接"和"执行"两个视角观察，结构是并行的**。

ELF 定义三类主要目标文件：(事实上，这三种文件格式都是`object files`)

| 类型 | e_type 值 | 用途 |
|------|-----------|------|
| 可重定位文件 (Relocatable) | ET_REL (1) | 与其它目标文件链接后生成可执行文件或共享库 |
| 可执行文件 (Executable) | ET_EXEC (2) | 可直接运行的程序 |
| 共享目标文件 (Shared Object) | ET_DYN (3) | 可被链接进其它对象，也可被动态链接器装入进程 |

另有 ET_CORE (4) 保留给核心转储文件。

## 文件整体布局

ELF 文件从两种视图看：  

![object_file_format](https://raw.githubusercontent.com/sandyyyz/Image-hosting/main/img/object_file_format.png)
```
链接视图 (Linking View)            执行视图 (Execution View)
─────────────────────             ─────────────────────
ELF 头                             ELF 头
程序头表 (可选)(Program header table)                    程序头表 (必需)(program header table)
节 (Section) 1..n                 段 (Segment) 1..n
节头表 (Section Header Table)     节头表 (可选)
```

> An ELF header resides at the beginning and holds a "road map'' describing the file's 
organization. Sections hold the bulk of object file information for the linking view: instructions, 
data, symbol table, relocation information, and so on. Descriptions of special sections appear 
later in this section. Chapter 2 also describes segments and the program execution view of the 
file.

> A program header table, if present, tells the system how to create a process image. Files used 
to build a process image (execute a program) must have a program header table; relocatable 
files do not need one. A section header table contains information describing the file's sections. 
Every section has an entry in the table; each entry gives information such as the section name, 
the section size, and so on. Files used during linking must have a section header table; other 
object files may or may not have one. 

要点：
- **ELF 头**位于文件开头（固定位置），包含描述文件组织的"路标"。
- **Section**是链接视图的数据单元，承载指令、数据、符号表、重定位信息等。
- **Segment**是执行视图的数据单元，供系统创建进程映像。
- **可执行/共享文件必须有程序头表**；**可重定位文件必须（用于链接时）有节头表**。
- 只有 ELF 头位置固定，节与段的顺序、数量均未强制规定。


## ELF 头（Elf32_Ehdr）

```c
typedef struct {
    unsigned char e_ident[16];   // 文件标识
    Elf32_Half   e_type;         // 文件类型
    Elf32_Half   e_machine;      // 目标架构
    Elf32_Word   e_version;      // 版本 (EV_CURRENT=1)
    Elf32_Addr   e_entry;        // 入口点虚拟地址
    Elf32_Off    e_phoff;        // 程序头表偏移
    Elf32_Off    e_shoff;        // 节头表偏移
    Elf32_Word   e_flags;        // 处理器相关标志
    Elf32_Half   e_ehsize;       // ELF 头大小
    Elf32_Half   e_phentsize;    // 每个程序头大小
    Elf32_Half   e_phnum;        // 程序头数量
    Elf32_Half   e_shentsize;    // 每个节头大小
    Elf32_Half   e_shnum;        // 节头数量
    Elf32_Half   e_shstrndx;     // 节名字符串表所在节索引
} Elf32_Ehdr;
```

关键字段含义：
- `e_entry`：程序第一条指令的虚拟地址；无入口点则为 0。
- `e_phoff` / `e_shoff`：程序头表、节头表在文件中的字节偏移。
- `e_phnum` × `e_phentsize` = 程序头表总大小；`e_shnum` × `e_shentsize` = 节头表总大小。

## ELF 标识（e_ident）

`e_ident[16]` 的前 8 个字节提供了**与机器无关**的解析信息：

| 字节 | 名称 | 含义 |
|------|------|------|
| 0-3 | EI_MAG0..3 | 魔数：`0x7f 'E' 'L' 'F'` |
| 4 | EI_CLASS | 文件类别：ELFCLASS32=1（32 位），ELFCLASS64=2（64 位） |
| 5 | EI_DATA | 数据编码：ELFDATA2LSB=1（小端），ELFDATA2MSB=2（大端） |
| 6 | EI_VERSION | 版本，必须为 EV_CURRENT (1) |
| 7 | EI_PAD | 填充起始，保留字节置 0 |
| 8-15 | EI_PAD.. | 保留，程序应忽略 |

## 节（Section）

节头表是 `Elf32_Shdr` 结构数组，通过 `e_shoff` 定位。每个节有唯一对应的节头：

```c
typedef struct {
    Elf32_Word sh_name;         // 节名（指向字符串表）
    Elf32_Word sh_type;         // 节类型
    Elf32_Word sh_flags;        // 属性标志
    Elf32_Addr sh_addr;         // 该节在进程内存中的地址（若不驻留则为 0）
    Elf32_Off  sh_offset;       // 节内容在文件中的偏移
    Elf32_Word sh_size;         // 节大小（字节）
    Elf32_Word sh_link;         // 关联节索引，含义随类型而定
    Elf32_Word sh_info;         // 附加信息，含义随类型而定
    Elf32_Word sh_addralign;    // 地址对齐要求
    Elf32_Word sh_entsize;      // 固定大小表项时每项字节数,(Some sections hold a table of fixed-size entries, such as a symbol table.  
For such a section, this member gives the size in bytes of each entry. 
The member contains 0 if the section does not hold a table of fixed-size entries.)
} Elf32_Shdr;
```

**常见节类型 (sh_type)**：
- `SHT_NULL`(0)：空/未用节
- `SHT_PROGBITS`(1)：程序自定义数据
- `SHT_SYMTAB`(2) / `SHT_DYNSYM`(11)：符号表（后者为精简的动态链接符号表）
- `SHT_STRTAB`(3)：字符串表
- `SHT_RELA`(4) / `SHT_REL`(9)：重定位表（带/不带显式 addend）
- `SHT_HASH`(5)：符号哈希表
- `SHT_DYNAMIC`(6)：动态链接信息
- `SHT_NOTE`(7)：注解信息
- `SHT_NOBITS`(8)：仅占内存不占文件空间（如 `.bss`）

**节属性标志 (sh_flags)**：
- `SHF_WRITE`(0x1)：可写
- `SHF_ALLOC`(0x2)：进程执行时占用内存
- `SHF_EXECINSTR`(0x4)：包含可执行指令
- `SHF_MASKPROC`：处理器保留位掩码

> Various sections in ELF are pre-defined and hold program and control information. These 
Sections are used by the operating system and have different types and attributes for different 
operating systems.
Executable files are created from individual object files and libraries through the linking 
process.  The linker resolves the references (including subroutines and data references) among 
the different object files,  adjusts the absolute references in the object files, and relocates 
instructions.

**常用特殊节**：`.text`（代码）、`.data`（已初始化数据）、`.bss`（未初始化数据，SHT_NOBITS，装入时清零）、`.rodata`（只读数据）、`.symtab`（符号表）、`.strtab`（符号名表）、`.shstrtab`（节名表）、`.dynamic`(动态链接信息)、`.hash`(symbol hash table)、`.init`/`.fini`(程序初始化/退出代码)、`.comment`（version control information.）、`.debug`(This section holds information for symbolic debugging. )。

### 字符串表与符号表

**字符串表**：由以 `\0` 结尾的字符串组成，首个字节固定为 `\0`（索引 0 表示空名/无名）。引用字符串通过"字符串表索引"实现，可重复引用、引用子串。  
索引过程:  

![strtbl_index](https://raw.githubusercontent.com/sandyyyz/Image-hosting/main/img/strtbl_index.png)

**符号表 (Elf32_Sym)**：

> An object file's symbol table holds information needed to locate and relocate a program's 
symbolic definitions and references.( the symbol table entry for index 0 (STN_UNDEF) is reserved;)  
以下是symbol table entry 的格式  
```c
typedef struct {
    Elf32_Word    st_name;    // 符号名（字符串表索引）
    Elf32_Addr    st_value;   // 符号值
    Elf32_Word    st_size;    // 符号大小（可为 0）
    unsigned char st_info;    // 绑定 + 类型
    unsigned char st_other;   // 目前恒为 0
    Elf32_Half    st_shndx;   // 所在section在section header table中索引
} Elf32_Sym;
```

- **绑定 (st_info 高 4 位)**：`STB_LOCAL`(0) 仅文件内可见；`STB_GLOBAL`(1) 全局可见，可满足其它文件的未定义引用；`STB_WEAK`(2) 弱符号，优先级低于全局定义。
- **类型 (低 4 位)**：`STT_NOTYPE`(0) 未指定、`STT_OBJECT`(1) 数据对象(variable, array and so on)、`STT_FUNC`(2) 函数、`STT_SECTION`(3) 节、`STT_FILE`(4) 源文件名。
- **st_shndx 特殊值**：`SHN_UNDEF`(0) 未定义符号；`SHN_ABS`(0xfff1) 绝对值（重定位不影响）；`SHN_COMMON`(0xfff2) 公共块（如未分配的外部变量）。
- 每个符号表中 `STB_LOCAL` 符号排在全局/弱符号之前。
- **符号值 (st_value) 含义随文件类型变化**：可重定位文件中为节内偏移；可执行/共享文件中为虚拟地址。
- 索引 0（`STN_UNDEF`）为保留的空符号。
![symbol_types](https://raw.githubusercontent.com/sandyyyz/Image-hosting/main/img/symbol_types.png)
![symbol_binding](https://raw.githubusercontent.com/sandyyyz/Image-hosting/main/img/symbol_binding.png)
其中`STB_LOPROC`和`STB_HIPROC`保留` for processor-specific semantics`

### 重定位table（Relocation table）(SHT_RELA/SHT_REL)
>  relocatable files must have 
information that describes how to modify their section contents, thus allowing executable and 
shared object files to hold the right information for a process's program image. Relocation 
entries are these data.  

重定位把"符号引用"与"符号定义"连接起来（如将 `call` 指令的目标改写为函数的真实地址）。

```c
typedef struct {                 // Elf32_Rel（无显式 addend）
    Elf32_Addr r_offset;         // 修改位置：relocable file=节内偏移，executable file or shared object=虚拟地址
    Elf32_Word r_info;           // 符号表索引 + 重定位类型
} Elf32_Rel;

typedef struct {                 // Elf32_Rela（带显式 addend）
    Elf32_Addr r_offset;
    Elf32_Word r_info;
    Elf32_Sword r_addend;        //  a constant addend used to compute the value to be stored into the relocatable field
} Elf32_Rela;
```

常用宏解析 `r_info`：`ELF32_R_SYM(i)=i>>8`（符号索引），`ELF32_R_TYPE(i)=低8位`（类型）。`Elf32_Rel` 的加数隐含存放在被修改位置中，`Elf32_Rela` 显式给出 `r_addend`。重定位节通过节头的 `sh_link`（关联符号表）与 `sh_info`（被重定位的节）建立联系。

**Intel 386 基本重定位类型**（计算记号 A=加数、P=被改位置、S=符号值）：
- `R_386_32` = `S + A`
- `R_386_PC32` = `S + A - P`
- 动态相关：`R_386_GLOB_DAT`(S)、`R_386_JMP_SLOT`(S)、`R_386_RELATIVE`(B+A，B 为装载基址) 等。

## 程序头与程序加载（Elf32_Phdr）

程序头表描述如何创建进程映像，只对可执行和共享文件有意义。

```c
typedef struct {
    Elf32_Word p_type;    // 段类型
    Elf32_Off  p_offset;  // 段在文件中的偏移
    Elf32_Addr p_vaddr;   // 段在内存中的虚拟地址
    Elf32_Addr p_paddr;   // 物理地址（多数系统忽略）
    Elf32_Word p_filesz;  // 文件映像大小
    Elf32_Word p_memsz;   // 内存映像大小
    Elf32_Word p_flags;   // 访问权限
    Elf32_Word p_align;   // 对齐
} Elf32_Phdr;
```

**段类型 (p_type)**：`PT_NULL`(0) 空、`PT_LOAD`(1) 可装载段、`PT_DYNAMIC`(2) 动态信息、`PT_INTERP`(3) 程序解释器路径、`PT_NOTE`(4) 注解、`PT_PHDR`(6) 程序头表自身。

**段权限 (p_flags)**：`PF_X`(1) 执行、`PF_W`(2) 写、`PF_R`(4) 读。典型文本段为 R+X，数据段为 R+W+X。

**装载要点**：
- 可装载段的 `p_vaddr` 与 `p_offset` 必须按页大小（Intel 架构 4KB / 0x1000）同余，便于分页。
- `p_memsz > p_filesz` 的部分为未初始化数据，系统以 0 填充（对应 `.bss`）。
- **基址 (base address)**：单个可执行/共享对象在其加载中，内存 V.A. 与文件 V.A. 的差值恒为常量，动态链接时以此"重定位"内存映像。共享对象通常含位置无关代码 (PIC)，可被任意进程以不同基址装载。

## 9. 动态链接（Dynamic Linking）

动态链接在进程初始化或运行时解析符号引用。关键机制：

**程序解释器（Program Interpreter）**：可执行文件经 `PT_INTERP` 段指明解释器路径（Intel/System V 上为 `/usr/lib/libc.so.1`）。`exec` 时系统先装载解释器，把控制交给它，由它（通常是**动态链接器**）再装载程序及依赖的共享对象、完成重定位、最终移交控制给程序。

**动态节 (.dynamic)**：`_DYNAMIC` 数组，元素为 `{ d_tag, d_un }`，`DT_NULL` 标记数组结尾。关键标签：
- `DT_NEEDED`：依赖的共享库名（宽优先遍历解析符号）
- `DT_STRTAB` / `DT_SYMTAB` / `DT_STRSZ` / `DT_SYMENT`：符号表与字符串表及其大小
- `DT_HASH`：符号哈希表地址
- `DT_RELA`/`DT_REL` 及 `DT_RELASZ`/`DT_RELAENT`：重定位表
- `DT_INIT` / `DT_FINI`：初始化/终止函数（位于 `.init`/`.fini`）
- `DT_PLTGOT`：GOT 首项地址
- `DT_INIT` 之前依赖对象的初始化先执行，终止顺序与初始化相反
- `LD_BIND_NOW` 环境变量非空时立即完成全部重定位，否则 GOT/PLT 采用**惰性绑定 (lazy binding)**

**共享对象依赖查找**：依赖名含 `/` 则直接作为路径；否则按 `DT_RPATH` → `LD_LIBRARY_PATH` → `/usr/lib` 顺序查找（setuid 程序忽略环境变量以获得安全）。

**GOT（全局偏移表）**：存放绝对地址的私有数据表，使文本段保持位置无关。涉及 GOT 的重定位有 `R_386_GOT32`、`R_386_GOTOFF`、`R_386_GOTPC`。Intel 架构下 GOT 前三项保留，其中第 0 项指向动态结构 `_DYNAMIC`，供动态链接器自我初始化。

**PLT（过程链接表）**：将位置无关的函数调用重定向到绝对地址。首次调用经 PLT 跳转到动态链接器解析符号并回填 GOT，之后调用直接命中真实函数地址（惰性绑定），避免未调用函数产生开销。

**符号哈希表**：`nbucket + nchain` 数组结构，配合 `elf_hash()` 哈希函数加速符号查找。

## 10. 常用查看工具

```bash
readelf -h hello        # ELF 头
readelf -S hello        # 节头表
readelf -l hello        # 程序头表 / 段
readelf -s hello        # 符号表
readelf -d hello        # 动态节 (.dynamic)
readelf -r hello        # 重定位
objdump -d hello        # 反汇编
```

## 一句话总结

> ELF 用"节"承载链接所需的符号/重定位数据、用"段"承载执行所需的装载与权限信息，再通过 ELF 头串联两者；动态链接则依赖程序解释器、`.dynamic` 节、GOT/PLT 与哈希表，在运行时完成符号解析与重定位。
