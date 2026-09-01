# System V Application Binary Interface

Arch: `AMD64`

## Machine Interface

### Data Representation

![scalar_types](https://raw.githubusercontent.com/sandyyyz/Image-hosting/main/img/scalar_types.png)

## Function Calling Sequence

### Registers

1. 16 通用 64-bit 寄存器
2. AMD64: 16 128-bit-SSE寄存器
3. Intel AVX (Advanced Vector Extensions), 16 256-bit wide AVX registers (%ymm0- %ymm15).The lower 128-bits of %ymm0- %ymm15 are aliased to the respective 128b-bit
SSE registers (%xmm0- %xmm15).
4.  Intel AVX-512 provides 32 512-bit wide SIMD registers
(%zmm0- %zmm31). The lower 128-bits of %zmm0- %zmm31 are aliased to the respective 128b
bit SSE registers (%xmm0- %xmm317). The lower 256-bits of %zmm0- %zmm31 are aliased to the
respective 256-bit AVX registers (%ymm0- %ymm318). For purposes of parameter passing and
function return, %xmmN, %ymmN and %zmmN refer to the same register. Only one of them can
be used at the same time.
5. Intel AVX-512 also provides 8 vector mask registers (%k0- %k7), each
64-bit wide.
6. vector register: 用于指代 SSE, AVX 或者 AVX-512寄存器。
7. 8 80-bit-x87 浮点寄存器, 注意，这些x87寄存器不是传统的平坦寄存器， 而是一个寄存器栈， 需要通过`fldt`或者`fstpt`操作。逻辑上分为`%st0`-`%st7`
8. Intel APX (Advanced Performance Extensions) provides 16 general purpose 64-bit
registers (%r16- %r31).

`caller(callee-saved)`寄存器: `%rsp, %rbp, %rbx, %r12-%r15`  
`callee(caller-saved)`寄存器: others  
这里的`caller/ee`指的是寄存器*属于谁*， 即在函数调用过程中，当前过程需要*保护*寄存器从属者的值。而`callee/er-saved`指的是在函数调用的过程中，*寄存器的值由谁保存*。举个例子：  
`%rbp, %rbx, %r12-%r15` 寄存器*属于*`caller`，`callee`如果需要使用这些寄存器，需要在使用前保存，并在返回时恢复寄存器的值。而其他的`callee`寄存器，如果`caller`需要保证寄存器内的值不改变，需要在调用函数前主动保存于自身的栈帧内，函数返回时手动恢复。

### Stack Frame

![Stack_frame](https://raw.githubusercontent.com/sandyyyz/Image-hosting/main/img/amd64_abi_stackframe.png)
在`call`指令调用之前，栈帧必须保证16字节对齐。  

在 `System V AMD64 ABI` 中，当前 `%rsp` 以下的 128 字节被定义为 `red zone`。信号和中断处理程序不得破坏这一区域，因此普通用户态函数可以在不移动 `%rsp` 的情况下，将其作为临时存储空间。由于函数调用可能覆盖该区域，它主要用于不调用其他函数的叶子函数，以省略建立和销毁栈帧的指令。

### Parameter Pasisng

由于是64位架构，自然的，The size of each argument gets rounded up to eightbytes.  

由于参数的位长不同，且架构有不同类型的寄存器，ABI因此规定了一系列类型，用于决定其应该如何传递：  

`INTERGER`: 存入一个通用寄存器。  
`SSE`: 存入一个向量寄存器。  
`SSEUP`: 可以存入一个向量寄存器，且 `can be passed and returned in the upper bytes of it.`  
`X87, X87UP, COMPLEX_X87 `: returned via `x87 FPU`.  
`NO_CLASS`: This class is used as initializer in the algorithms. It will be used for padding
and empty structures and unions.(?)  
`MEMORY`: 使用内存(stack)进行传递。  

#### Classification

对于基本数据类型，如 (signed and unsigned) _Bool, char, short, int, long, long long, and pointers ), `INTERGER`  
浮点类型等，( _Float16, float, double, _Decimal32, _Decimal64 and __m64), `SSE`  
长浮点类型等，(__float128, _Decimal128 and __m128 )，分为两个部分， 高位部分`SSEUP`, 低位部分`SSE`  
__m256, The least significant one belongs to class SSE and all the others to class SSEUP  
注意__mxx类型是编译器为x86 SIMD指令集提供的内建向量类型， 用来抽象 MMX、SSE、AVX 和 AVX-512 寄存器中的数据。它们不是标准 C/C++ 基本类型，而是 GCC、Clang、Intel 编译器和 MSVC 等提供的扩展类型，通常配合 intrinsic 函数使用。  
long double: `X87`
__int128, 高位低位分别视为一个`INTERGER`,即：  
```c
typedef struct {
long low, high;
} __int128;
```
此类参数需要通过内存传递时，必须按照16字节对齐。  

Arguments of type _BitInt(N) with N <= 64 are in the INTEGER class.  
• Arguments of type _BitInt(N) with N > 64 are classified as if they were imple
mented as struct of 64-bit integer fields.  
• Arguments of complex T where T is one of the types _Float16, float, double or
__float128 are treated as if they are implemented as:  

```c
struct complexT {
T real;
T imag;
};
```

complex long double is classified as type COMPLEX_X87  

对于array, union, arrays:  
1. 如果对象大小大于8个eightbyte, 即64个字节， 或者包含未对齐的字段，为`MEMORY`类型。  
2. 如果一个 C++ 对象按照 C++ ABI 的规定，在函数调用意义上属于 non-trivial，那么该对象通过“不可见引用”传递.即此时传递一个`INTERGER`类型的pointer。这里的`non-trival`的意思是，某个对象操作不能被视为无需特殊语义的普通操作，而必须执行用户提供的函数，或递归执行成员、基类所要求的非平凡构造、复制、移动或析构逻辑。该对象不适合被简单拆分成寄存器值进行参数传递。编译器需先构造一个具有完整生命周期的形参对象，再通过隐藏指针将其地址传给被调用函数。
3. 当总大小超过八字节时， 以八字节为单位，对每个部分进行单独分类。每个部分被初始化为`NO_CLASS`  
单独分类后，对每个部分单独进行递归的分类，分类规则如下：  

```text
(a) If both classes are equal, this is the resulting class.
(b) If one of the classes is NO_CLASS, the resulting class is the other class.
(c) If one of the classes is MEMORY, the result is the MEMORY class.
(d) If one of the classes is INTEGER, the result is the INTEGER.
(e) If one of the classes is X87, X87UP, COMPLEX_X87 class, MEMORY is
used as class.
(f) Otherwise class SSE is used
```
在对各个部分单独进行递归分类后， 进行类别合并操作：  
```text
(a) If one of the classes is MEMORY, the whole argument is passed in memory.
(b) If X87UP is not preceded by X87, the whole argument is passed in memory.
(c) If the size of the aggregate exceeds two eightbytes and the first eightbyte isn’t
SSE or any other eightbyte isn’t SSEUP, the whole argument is passed in mem
ory.
(d) If SSEUP is not preceded by SSE or SSEUP, it is converted to SSE
```
该步骤将决定此对象整体应该是何种类型。  

总结的流程如下：  

```
聚合类型参数
    │
    ├─ 对象大小 > 8 个 eightbyte（64 字节）
    │  或包含未对齐字段？
    │        └─ 是 → MEMORY
    │
    ├─ C++ 对象属于 non-trivial for calls？
    │        └─ 是 → invisible reference
    │                以 INTEGER 类指针代替原参数
    │
    └─ 否
         │
         ├─ 按 8 字节划分为若干 eightbyte
         │
         ├─ 每个 eightbyte 初始化为 NO_CLASS
         │
         ├─ 递归分类其中的字段
         │
         ├─ 合并同一 eightbyte 内的字段类别
         │
         └─ 执行分类结果清理
                  │
                  ├─ 合法 → INTEGER、SSE、SSEUP 等
                  └─ 非法 → MEMORY
```

| 条件                                | 合并结果      |
| --------------------------------- | --------- |
| `A == B`                          | 保持该类别     |
| 一方为 `NO_CLASS`                    | 取另一方      |
| 一方为 `MEMORY`                      | `MEMORY`  |
| 一方为 `INTEGER`                     | `INTEGER` |
| 一方为 `X87`、`X87UP` 或 `COMPLEX_X87` | `MEMORY`  |
| 其他组合                              | `SSE`     |

即：
```
MEMORY
   >
INTEGER
   >
SSE
   >
NO_CLASS
```

对于清理规则：  
```
初步分类结果
    │
    ├─ 任意 eightbyte 为 MEMORY
    │       └─ 整个参数通过内存传递
    │
    ├─ X87UP 前面不是 X87
    │       └─ 整个参数通过内存传递
    │
    ├─ 聚合体超过两个 eightbyte
    │       ├─ 第一个不是 SSE
    │       └─ 或后续任一不是 SSEUP
    │               └─ 整个参数通过内存传递
    │
    └─ SSEUP 前面不是 SSE 或 SSEUP
            └─ 将该 SSEUP 修正为 SSE
```

总结如下：  

| 阶段       | 操作                              | 结果                     |
| -------- | ------------------------------- | ---------------------- |
| 预检查      | 大于 64 字节或含未对齐字段                 | `MEMORY`               |
| C++ 特殊检查 | `non-trivial for calls`         | 以 `INTEGER` 类隐藏指针传递    |
| 分块       | 按连续 8 字节划分                      | 每块初始化为 `NO_CLASS`      |
| 递归分类     | 分类成员和嵌套对象                       | 得到各字段类别                |
| 类别合并     | 合并同一 eightbyte 内的类别             | 得到每块的初步类别              |
| 后处理      | 校验 `MEMORY`、`X87UP`、`SSEUP` 等组合 | 保留合法分类，否则整体转为 `MEMORY` |
| 参数传递     | 根据最终类别分配位置                      | 通用寄存器、SSE 寄存器或内存       |

总而言之，该过程，先排除必须间接或内存传递的对象，再按 eightbyte 递归分类和合并字段，最后校验类别组合；任何不满足 ABI 约束的结果都回退为整体内存传递。

#### Passing

![registers](https://raw.githubusercontent.com/sandyyyz/Image-hosting/main/img/amd64_registers.png)
当参数分类完成后， 将进入传递阶段。首先分配寄存器作为参数传递的载体(in left-to-right order)  

传递参数，无非是使用寄存器传递或是使用栈传递，而寄存器包括整数寄存器和向量寄存器，在使用寄存器传递参数时，可以使用的通用寄存器有：  
1.  `%rdi`, `%rsi`, `%rdx`, `%rcx`, `%r8` and `%r9`
2. `%xmm0 - %xmm7`
3. 80bit-x87 floating point registers.

判定规则如下：
```text

1. If the class is MEMORY, pass the argument on the stack at an address respecting the
arguments alignment (which might be more than its natural alignement).
2. If the class is INTEGER, the next available register of the sequence %rdi, %rsi, %rdx,
%rcx, %r8 and %r9 is used19.
3. If the class is SSE, the next available vector register is used, the registers are taken
in the order from %xmm0 to %xmm7.
4. If the class is SSEUP, the eightbyte is passed in the next available eightbyte chunk
of the last used vector register.
5. If the class is X87, X87UP or COMPLEX_X87, it is passed in memory
```
与此同时， ABI 只保证窄整数类型自身的有效位正确，不保证承载它的更宽寄存器或栈槽中的额外高位；接收方必须按类型宽度读取，或显式执行符号扩展、零扩展。  
此时，参数列表中可以通过寄存器传递的参数已经被标记，但是存在以下一种情况：一个聚合体中的不同部分分别被标记为使用栈或是寄存器进行传递。ABI保证一个参数不会同时被拆分为使用栈和寄存器进行传递，此时将产生回退。该参数将统一使用栈进行传递。  
当一个参数发生回退时，其空出的寄存器可供后续的参数使用。  

此时完成了需要使用寄存器进行传递的参数的寄存器分配， 随后逆序将需要通过栈传递的参数压栈(right-to-left order).逆序压栈的过程保证了计算第一个参数的位置非常简单，可以静态计算出。如果顺序压栈，则很难计算。  
对于可变参数调用和无原型调用(在调用某个函数时，编译器只知道函数名和返回类型，却不知道该函数参数的数量及具体类型)，可变参数调用通过 `%al` 向被调用方提供向量参数寄存器使用数量的上界。此时ABI只保证`%al`，即`%rax`的低八位被定义  

对于__m256、__m512 参数, 要求调用点存在函数原型.  

#### Returning of Values

首先，通过前面的分类算法判断返回值的类型。  

`MEMORY`: caller负责为返回值保留空间，并且通过`%rdi`将相应地址传递给callee, 此时`%rdi`相当于一个隐藏的第一个参数。返回时`%rax`将保存caller通过`%rdi`传递的地址。  
`INTERGER`: 放入以`%rax`为首的整数寄存器。  
`SSE`: next avaliable vector register(`%xmm0, %xmm1`)...  
`SSEUP`:  the eightbyte is returned in the next available eightbyte chunk of the last used vector register.  
`X87`:  returned on the X87 stack in %st0 as 80-bit x87 number.  
`X87UP`:  returned together with the previous X87 value in `%st0`  
`COMPLEX_X87`: the real part of the value is returned in `%st0` and the imaginary part in `%st1`  

总结：  

```
先分类返回类型
      │
      ├─ MEMORY
      │    └─ caller 分配空间
      │       %rdi 传入地址
      │       callee 写入结果
      │       %rax 返回同一地址
      │
      ├─ INTEGER
      │    └─ %rax → %rdx
      │
      ├─ SSE
      │    └─ %xmm0 → %xmm1
      │
      ├─ SSEUP
      │    └─ 上一个向量寄存器的后续 eightbyte
      │
      ├─ X87 + X87UP
      │    └─ 共同组成 %st0 中的 80 位值
      │
      └─ COMPLEX_X87
           └─ 实部 %st0，虚部 %st1

```

| 返回类别          | 返回位置                  | 含义                      |
| ------------- | --------------------- | ----------------------- |
| `MEMORY`      | 调用者空间，地址通过 `%rdi` 传入  | 被调用函数写内存，并在 `%rax` 返回地址 |
| `INTEGER`     | `%rax`、`%rdx`         | 整数、指针或整数类聚合块            |
| `SSE`         | `%xmm0`、`%xmm1`       | 浮点或独立的向量类块              |
| `SSEUP`       | 上一个向量寄存器的高位部分         | 不分配新的向量寄存器              |
| `X87`         | `%st0`                | 80 位扩展精度值               |
| `X87UP`       | 与前一个 `X87` 合并在 `%st0` | 80 位值的高位部分              |
| `COMPLEX_X87` | 实部 `%st0`，虚部 `%st1`   | 扩展精度复数                  |

## debug

code:  

```c

[AMD64_ABI](https://gitlab.com/x86-psABIs/x86-64-ABI)
#include <immintrin.h>
#include <stdio.h>

typedef struct {
    int a;
    int b;
    double d;
} structparm;

/*
 * noinline 防止内联。
 * noclone 防止 GCC 生成使用非标准内部调用约定的克隆函数。
 */
__attribute__((noinline, noclone))
void func(int e,
          int f,
          structparm s,
          int g,
          int h,
          long double ld,
          double m,
          __m256 y,
          __m256 z,
          double n,
          int i,
          int j,
          int k)
{
    float y_values[8];
    float z_values[8];

    /*
     * 将向量保存到普通数组中，以便验证参数值。
     * storeu 不要求目标地址按 32 字节对齐。
     */
    _mm256_storeu_ps(y_values, y);
    _mm256_storeu_ps(z_values, z);

    printf("integer arguments:\n");
    printf("  e=%d f=%d g=%d h=%d i=%d j=%d k=%d\n",
           e, f, g, h, i, j, k);

    printf("structparm:\n");
    printf("  s.a=%d s.b=%d s.d=%.2f\n",
           s.a, s.b, s.d);

    printf("floating-point arguments:\n");
    printf("  ld=%.2Lf m=%.2f n=%.2f\n",
           ld, m, n);

    printf("vector y:\n");
    for (int index = 0; index < 8; ++index) {
        printf("  y[%d]=%.2f\n", index, y_values[index]);
    }

    printf("vector z:\n");
    for (int index = 0; index < 8; ++index) {
        printf("  z[%d]=%.2f\n", index, z_values[index]);
    }
}

__attribute__((noinline, noclone))
void caller(void)
{
    int e = 11;
    int f = 22;
    int g = 33;
    int h = 44;
    int i = 55;
    int j = 66;
    int k = 77;

    structparm s = {
        .a = 101,
        .b = 202,
        .d = 303.5
    };

    long double ld = 404.25L;
    double m = 505.5;
    double n = 606.75;

    __m256 y = _mm256_setr_ps(
        1.0f, 2.0f, 3.0f, 4.0f,
        5.0f, 6.0f, 7.0f, 8.0f
    );

    __m256 z = _mm256_setr_ps(
        11.0f, 12.0f, 13.0f, 14.0f,
        15.0f, 16.0f, 17.0f, 18.0f
    );

    /*
     * 在 GDB 中重点观察下面这个调用之前和之后的状态。
     */
    func(e, f, s, g, h, ld, m, y, z, n, i, j, k);
}

int main(void)
{
    caller();
    return 0;
}

```

`call`指令的作用等效于：  
```
1. push rip + 8 (call 指令的下一条指令)
2. jmp dest
```

注意到汇编代码中有一部分使用相对于`rip`的地址读取浮点数， 是.rodata段.  

rodata section of abi_args:  

```sh

zoe@HUANGZS7-2V8W0R:~/workspace/amd64abitest/code$ objdump -s -j .rodata ./abi_args
``

./abi_args:     file format elf64-x86-64

Contents of section .rodata:
 402000 01000200 00000000 00000000 00000000  ................
 402010 696e7465 67657220 61726775 6d656e74  integer argument
 402020 733a0000 00000000 2020653d 25642066  s:......  e=%d f
 402030 3d256420 673d2564 20683d25 6420693d  =%d g=%d h=%d i=
 402040 2564206a 3d256420 6b3d2564 0a007374  %d j=%d k=%d..st
 402050 72756374 7061726d 3a002020 732e613d  ructparm:.  s.a=
 402060 25642073 2e623d25 6420732e 643d252e  %d s.b=%d s.d=%.
 402070 32660a00 666c6f61 74696e67 2d706f69  2f..floating-poi
 402080 6e742061 7267756d 656e7473 3a002020  nt arguments:.
 402090 6c643d25 2e324c66 206d3d25 2e326620  ld=%.2Lf m=%.2f
 4020a0 6e3d252e 32660a00 76656374 6f722079  n=%.2f..vector y
 4020b0 3a002020 795b2564 5d3d252e 32660a00  :.  y[%d]=%.2f..
 4020c0 76656374 6f72207a 3a002020 7a5b2564  vector z:.  z[%d


 4020d0 5d3d252e 32660a00 00000000 00f87240  ]=%.2f........r@  # 0x4020d8
# value: 0x407f9800

# long double ld
# value:0x4007ca20000000000000
# 80 bit valid, 80 位 x87 扩展精度
# 48bit zero
# overall 128bit

 4020e0 00000000 000020ca 07400000 00000000  ...... ..@......
 4020f0 00000000 00987f40 00000000 00f68240  .......@.......@
 402100 0000803f 00000040 00004040 00008040  ...?...@..@@...@
 402110 0000a040 0000c040 0000e040 00000041  ...@...@...@...A
 402120 00003041 00004041 00005041 00006041  ..0A..@A..PA..`A
 402130 00007041 00008041 00008841 00009041  ..pA...A...A...A
```

完整反汇编代码：  

```asm

./abi_args:     file format elf64-x86-64


Disassembly of section .init:

0000000000401000 <_init>:
  401000:	f3 0f 1e fa          	endbr64
  401004:	48 83 ec 08          	sub    rsp,0x8
  401008:	48 8b 05 d1 2f 00 00 	mov    rax,QWORD PTR [rip+0x2fd1]        # 403fe0 <__gmon_start__@Base>
  40100f:	48 85 c0             	test   rax,rax
  401012:	74 02                	je     401016 <_init+0x16>
  401014:	ff d0                	call   rax
  401016:	48 83 c4 08          	add    rsp,0x8
  40101a:	c3                   	ret

Disassembly of section .plt:

0000000000401020 <.plt>:
  401020:	ff 35 ca 2f 00 00    	push   QWORD PTR [rip+0x2fca]        # 403ff0 <_GLOBAL_OFFSET_TABLE_+0x8>
  401026:	ff 25 cc 2f 00 00    	jmp    QWORD PTR [rip+0x2fcc]        # 403ff8 <_GLOBAL_OFFSET_TABLE_+0x10>
  40102c:	0f 1f 40 00          	nop    DWORD PTR [rax+0x0]
  401030:	f3 0f 1e fa          	endbr64
  401034:	68 00 00 00 00       	push   0x0
  401039:	e9 e2 ff ff ff       	jmp    401020 <_init+0x20>
  40103e:	66 90                	xchg   ax,ax
  401040:	f3 0f 1e fa          	endbr64
  401044:	68 01 00 00 00       	push   0x1
  401049:	e9 d2 ff ff ff       	jmp    401020 <_init+0x20>
  40104e:	66 90                	xchg   ax,ax
  401050:	f3 0f 1e fa          	endbr64
  401054:	68 02 00 00 00       	push   0x2
  401059:	e9 c2 ff ff ff       	jmp    401020 <_init+0x20>
  40105e:	66 90                	xchg   ax,ax

Disassembly of section .plt.sec:

0000000000401060 <puts@plt>:
  401060:	f3 0f 1e fa          	endbr64
  401064:	ff 25 96 2f 00 00    	jmp    QWORD PTR [rip+0x2f96]        # 404000 <puts@GLIBC_2.2.5>
  40106a:	66 0f 1f 44 00 00    	nop    WORD PTR [rax+rax*1+0x0]

0000000000401070 <__stack_chk_fail@plt>:
  401070:	f3 0f 1e fa          	endbr64
  401074:	ff 25 8e 2f 00 00    	jmp    QWORD PTR [rip+0x2f8e]        # 404008 <__stack_chk_fail@GLIBC_2.4>
  40107a:	66 0f 1f 44 00 00    	nop    WORD PTR [rax+rax*1+0x0]

0000000000401080 <printf@plt>:
  401080:	f3 0f 1e fa          	endbr64
  401084:	ff 25 86 2f 00 00    	jmp    QWORD PTR [rip+0x2f86]        # 404010 <printf@GLIBC_2.2.5>
  40108a:	66 0f 1f 44 00 00    	nop    WORD PTR [rax+rax*1+0x0]

Disassembly of section .text:

0000000000401090 <_start>:
  401090:	f3 0f 1e fa          	endbr64
  401094:	31 ed                	xor    ebp,ebp
  401096:	49 89 d1             	mov    r9,rdx
  401099:	5e                   	pop    rsi
  40109a:	48 89 e2             	mov    rdx,rsp
  40109d:	48 83 e4 f0          	and    rsp,0xfffffffffffffff0
  4010a1:	50                   	push   rax
  4010a2:	54                   	push   rsp
  4010a3:	45 31 c0             	xor    r8d,r8d
  4010a6:	31 c9                	xor    ecx,ecx
  4010a8:	48 c7 c7 d4 17 40 00 	mov    rdi,0x4017d4
  4010af:	ff 15 23 2f 00 00    	call   QWORD PTR [rip+0x2f23]        # 403fd8 <__libc_start_main@GLIBC_2.34>
  4010b5:	f4                   	hlt
  4010b6:	66 2e 0f 1f 84 00 00 	cs nop WORD PTR [rax+rax*1+0x0]
  4010bd:	00 00 00 

00000000004010c0 <_dl_relocate_static_pie>:
  4010c0:	f3 0f 1e fa          	endbr64
  4010c4:	c3                   	ret
  4010c5:	66 2e 0f 1f 84 00 00 	cs nop WORD PTR [rax+rax*1+0x0]
  4010cc:	00 00 00 
  4010cf:	90                   	nop

00000000004010d0 <deregister_tm_clones>:
  4010d0:	b8 28 40 40 00       	mov    eax,0x404028
  4010d5:	48 3d 28 40 40 00    	cmp    rax,0x404028
  4010db:	74 13                	je     4010f0 <deregister_tm_clones+0x20>
  4010dd:	b8 00 00 00 00       	mov    eax,0x0
  4010e2:	48 85 c0             	test   rax,rax
  4010e5:	74 09                	je     4010f0 <deregister_tm_clones+0x20>
  4010e7:	bf 28 40 40 00       	mov    edi,0x404028
  4010ec:	ff e0                	jmp    rax
  4010ee:	66 90                	xchg   ax,ax
  4010f0:	c3                   	ret
  4010f1:	66 66 2e 0f 1f 84 00 	data16 cs nop WORD PTR [rax+rax*1+0x0]
  4010f8:	00 00 00 00 
  4010fc:	0f 1f 40 00          	nop    DWORD PTR [rax+0x0]

0000000000401100 <register_tm_clones>:
  401100:	be 28 40 40 00       	mov    esi,0x404028
  401105:	48 81 ee 28 40 40 00 	sub    rsi,0x404028
  40110c:	48 89 f0             	mov    rax,rsi
  40110f:	48 c1 ee 3f          	shr    rsi,0x3f
  401113:	48 c1 f8 03          	sar    rax,0x3
  401117:	48 01 c6             	add    rsi,rax
  40111a:	48 d1 fe             	sar    rsi,1
  40111d:	74 11                	je     401130 <register_tm_clones+0x30>
  40111f:	b8 00 00 00 00       	mov    eax,0x0
  401124:	48 85 c0             	test   rax,rax
  401127:	74 07                	je     401130 <register_tm_clones+0x30>
  401129:	bf 28 40 40 00       	mov    edi,0x404028
  40112e:	ff e0                	jmp    rax
  401130:	c3                   	ret
  401131:	66 66 2e 0f 1f 84 00 	data16 cs nop WORD PTR [rax+rax*1+0x0]
  401138:	00 00 00 00 
  40113c:	0f 1f 40 00          	nop    DWORD PTR [rax+0x0]

0000000000401140 <__do_global_dtors_aux>:
  401140:	f3 0f 1e fa          	endbr64
  401144:	80 3d dd 2e 00 00 00 	cmp    BYTE PTR [rip+0x2edd],0x0        # 404028 <__TMC_END__>
  40114b:	75 13                	jne    401160 <__do_global_dtors_aux+0x20>
  40114d:	55                   	push   rbp
  40114e:	48 89 e5             	mov    rbp,rsp
  401151:	e8 7a ff ff ff       	call   4010d0 <deregister_tm_clones>
  401156:	c6 05 cb 2e 00 00 01 	mov    BYTE PTR [rip+0x2ecb],0x1        # 404028 <__TMC_END__>
  40115d:	5d                   	pop    rbp
  40115e:	c3                   	ret
  40115f:	90                   	nop
  401160:	c3                   	ret
  401161:	66 66 2e 0f 1f 84 00 	data16 cs nop WORD PTR [rax+rax*1+0x0]
  401168:	00 00 00 00 
  40116c:	0f 1f 40 00          	nop    DWORD PTR [rax+0x0]

0000000000401170 <frame_dummy>:
  401170:	f3 0f 1e fa          	endbr64
  401174:	eb 8a                	jmp    401100 <register_tm_clones>

0000000000401176 <func>:
          __m256 z,
          double n,
          int i,
          int j,
          int k)
{
  401176:	f3 0f 1e fa          	endbr64
  40117a:	4c 8d 54 24 08       	lea    r10,[rsp+0x8]
  40117f:	48 83 e4 e0          	and    rsp,0xffffffffffffffe0
  401183:	41 ff 72 f8          	push   QWORD PTR [r10-0x8]
  401187:	55                   	push   rbp
  401188:	48 89 e5             	mov    rbp,rsp
  40118b:	41 52                	push   r10
  40118d:	53                   	push   rbx
  40118e:	48 81 ec 40 01 00 00 	sub    rsp,0x140
  401195:	4c 89 d3             	mov    rbx,r10
  401198:	89 bd 2c ff ff ff    	mov    DWORD PTR [rbp-0xd4],edi
  40119e:	89 b5 28 ff ff ff    	mov    DWORD PTR [rbp-0xd8],esi
  4011a4:	48 89 d0             	mov    rax,rdx
  4011a7:	c4 e1 f9 7e c2       	vmovq  rdx,xmm0
  4011ac:	48 89 85 10 ff ff ff 	mov    QWORD PTR [rbp-0xf0],rax
  4011b3:	48 89 95 18 ff ff ff 	mov    QWORD PTR [rbp-0xe8],rdx
  4011ba:	89 8d 24 ff ff ff    	mov    DWORD PTR [rbp-0xdc],ecx
  4011c0:	44 89 85 20 ff ff ff 	mov    DWORD PTR [rbp-0xe0],r8d
  4011c7:	c5 fb 11 8d 08 ff ff 	vmovsd QWORD PTR [rbp-0xf8],xmm1
  4011ce:	ff 
  4011cf:	c5 fc 29 95 d0 fe ff 	vmovaps YMMWORD PTR [rbp-0x130],ymm2
  4011d6:	ff 
  4011d7:	c5 fc 29 9d b0 fe ff 	vmovaps YMMWORD PTR [rbp-0x150],ymm3
  4011de:	ff 
  4011df:	c5 fb 11 a5 00 ff ff 	vmovsd QWORD PTR [rbp-0x100],xmm4
  4011e6:	ff 
  4011e7:	44 89 8d fc fe ff ff 	mov    DWORD PTR [rbp-0x104],r9d
  4011ee:	64 48 8b 04 25 28 00 	mov    rax,QWORD PTR fs:0x28
  4011f5:	00 00 
  4011f7:	48 89 45 e8          	mov    QWORD PTR [rbp-0x18],rax
  4011fb:	31 c0                	xor    eax,eax
  4011fd:	48 8d 45 a0          	lea    rax,[rbp-0x60]
  401201:	48 89 85 48 ff ff ff 	mov    QWORD PTR [rbp-0xb8],rax
  401208:	c5 fc 28 85 d0 fe ff 	vmovaps ymm0,YMMWORD PTR [rbp-0x130]
  40120f:	ff 
  401210:	c5 fc 29 85 70 ff ff 	vmovaps YMMWORD PTR [rbp-0x90],ymm0
  401217:	ff 
}

extern __inline void __attribute__((__gnu_inline__, __always_inline__, __artificial__))
_mm256_storeu_ps (float *__P, __m256 __A)
{
  *(__m256_u *)__P = __A;
  401218:	c5 fc 28 85 70 ff ff 	vmovaps ymm0,YMMWORD PTR [rbp-0x90]
  40121f:	ff 
  401220:	48 8b 85 48 ff ff ff 	mov    rax,QWORD PTR [rbp-0xb8]
  401227:	c5 fc 11 00          	vmovups YMMWORD PTR [rax],ymm0
}
  40122b:	90                   	nop
  40122c:	48 8d 45 c0          	lea    rax,[rbp-0x40]
  401230:	48 89 85 40 ff ff ff 	mov    QWORD PTR [rbp-0xc0],rax
  401237:	c5 fc 28 85 b0 fe ff 	vmovaps ymm0,YMMWORD PTR [rbp-0x150]
  40123e:	ff 
  40123f:	c5 fc 29 85 50 ff ff 	vmovaps YMMWORD PTR [rbp-0xb0],ymm0
  401246:	ff 
  *(__m256_u *)__P = __A;
  401247:	c5 fc 28 85 50 ff ff 	vmovaps ymm0,YMMWORD PTR [rbp-0xb0]
  40124e:	ff 
  40124f:	48 8b 85 40 ff ff ff 	mov    rax,QWORD PTR [rbp-0xc0]
  401256:	c5 fc 11 00          	vmovups YMMWORD PTR [rax],ymm0
}
  40125a:	90                   	nop
     * storeu 不要求目标地址按 32 字节对齐。
     */
    _mm256_storeu_ps(y_values, y);
    _mm256_storeu_ps(z_values, z);

    printf("integer arguments:\n");
  40125b:	bf 10 20 40 00       	mov    edi,0x402010
  401260:	e8 fb fd ff ff       	call   401060 <puts@plt>
    printf("  e=%d f=%d g=%d h=%d i=%d j=%d k=%d\n",
  401265:	44 8b 85 fc fe ff ff 	mov    r8d,DWORD PTR [rbp-0x104]
  40126c:	8b bd 20 ff ff ff    	mov    edi,DWORD PTR [rbp-0xe0]
  401272:	8b 8d 24 ff ff ff    	mov    ecx,DWORD PTR [rbp-0xdc]
  401278:	8b 95 28 ff ff ff    	mov    edx,DWORD PTR [rbp-0xd8]
  40127e:	8b 85 2c ff ff ff    	mov    eax,DWORD PTR [rbp-0xd4]
  401284:	8b 73 18             	mov    esi,DWORD PTR [rbx+0x18]
  401287:	56                   	push   rsi
  401288:	8b 73 10             	mov    esi,DWORD PTR [rbx+0x10]
  40128b:	56                   	push   rsi
  40128c:	45 89 c1             	mov    r9d,r8d
  40128f:	41 89 f8             	mov    r8d,edi
  401292:	89 c6                	mov    esi,eax
  401294:	bf 28 20 40 00       	mov    edi,0x402028
  401299:	b8 00 00 00 00       	mov    eax,0x0
  40129e:	e8 dd fd ff ff       	call   401080 <printf@plt>
  4012a3:	48 83 c4 10          	add    rsp,0x10
           e, f, g, h, i, j, k);

    printf("structparm:\n");
  4012a7:	bf 4e 20 40 00       	mov    edi,0x40204e
  4012ac:	e8 af fd ff ff       	call   401060 <puts@plt>
    printf("  s.a=%d s.b=%d s.d=%.2f\n",
  4012b1:	48 8b 8d 18 ff ff ff 	mov    rcx,QWORD PTR [rbp-0xe8]
  4012b8:	8b 95 14 ff ff ff    	mov    edx,DWORD PTR [rbp-0xec]
  4012be:	8b 85 10 ff ff ff    	mov    eax,DWORD PTR [rbp-0xf0]
  4012c4:	c4 e1 f9 6e c1       	vmovq  xmm0,rcx
  4012c9:	89 c6                	mov    esi,eax
  4012cb:	bf 5a 20 40 00       	mov    edi,0x40205a
  4012d0:	b8 01 00 00 00       	mov    eax,0x1
  4012d5:	e8 a6 fd ff ff       	call   401080 <printf@plt>
           s.a, s.b, s.d);

    printf("floating-point arguments:\n");
  4012da:	bf 74 20 40 00       	mov    edi,0x402074
  4012df:	e8 7c fd ff ff       	call   401060 <puts@plt>
    printf("  ld=%.2Lf m=%.2f n=%.2f\n",
  4012e4:	c5 fb 10 85 00 ff ff 	vmovsd xmm0,QWORD PTR [rbp-0x100]
  4012eb:	ff 
  4012ec:	48 8b 85 08 ff ff ff 	mov    rax,QWORD PTR [rbp-0xf8]
  4012f3:	ff 73 08             	push   QWORD PTR [rbx+0x8]
  4012f6:	ff 33                	push   QWORD PTR [rbx]
  4012f8:	c5 fb 10 c8          	vmovsd xmm1,xmm0,xmm0
  4012fc:	c4 e1 f9 6e c0       	vmovq  xmm0,rax
  401301:	bf 8e 20 40 00       	mov    edi,0x40208e
  401306:	b8 02 00 00 00       	mov    eax,0x2
  40130b:	e8 70 fd ff ff       	call   401080 <printf@plt>
  401310:	48 83 c4 10          	add    rsp,0x10
           ld, m, n);

    printf("vector y:\n");
  401314:	bf a8 20 40 00       	mov    edi,0x4020a8
  401319:	e8 42 fd ff ff       	call   401060 <puts@plt>
    for (int index = 0; index < 8; ++index) {
  40131e:	c7 85 38 ff ff ff 00 	mov    DWORD PTR [rbp-0xc8],0x0
  401325:	00 00 00 
  401328:	eb 3a                	jmp    401364 <func+0x1ee>
        printf("  y[%d]=%.2f\n", index, y_values[index]);
  40132a:	8b 85 38 ff ff ff    	mov    eax,DWORD PTR [rbp-0xc8]
  401330:	48 98                	cdqe
  401332:	c5 fa 10 44 85 a0    	vmovss xmm0,DWORD PTR [rbp+rax*4-0x60]
  401338:	c5 fa 5a e8          	vcvtss2sd xmm5,xmm0,xmm0
  40133c:	c4 e1 f9 7e ea       	vmovq  rdx,xmm5
  401341:	8b 85 38 ff ff ff    	mov    eax,DWORD PTR [rbp-0xc8]
  401347:	c4 e1 f9 6e c2       	vmovq  xmm0,rdx
  40134c:	89 c6                	mov    esi,eax
  40134e:	bf b2 20 40 00       	mov    edi,0x4020b2
  401353:	b8 01 00 00 00       	mov    eax,0x1
  401358:	e8 23 fd ff ff       	call   401080 <printf@plt>
    for (int index = 0; index < 8; ++index) {
  40135d:	83 85 38 ff ff ff 01 	add    DWORD PTR [rbp-0xc8],0x1
  401364:	83 bd 38 ff ff ff 07 	cmp    DWORD PTR [rbp-0xc8],0x7
  40136b:	7e bd                	jle    40132a <func+0x1b4>
    }

    printf("vector z:\n");
  40136d:	bf c0 20 40 00       	mov    edi,0x4020c0
  401372:	e8 e9 fc ff ff       	call   401060 <puts@plt>
    for (int index = 0; index < 8; ++index) {
  401377:	c7 85 3c ff ff ff 00 	mov    DWORD PTR [rbp-0xc4],0x0
  40137e:	00 00 00 
  401381:	eb 3a                	jmp    4013bd <func+0x247>
        printf("  z[%d]=%.2f\n", index, z_values[index]);
  401383:	8b 85 3c ff ff ff    	mov    eax,DWORD PTR [rbp-0xc4]
  401389:	48 98                	cdqe
  40138b:	c5 fa 10 44 85 c0    	vmovss xmm0,DWORD PTR [rbp+rax*4-0x40]
  401391:	c5 fa 5a f0          	vcvtss2sd xmm6,xmm0,xmm0
  401395:	c4 e1 f9 7e f2       	vmovq  rdx,xmm6
  40139a:	8b 85 3c ff ff ff    	mov    eax,DWORD PTR [rbp-0xc4]
  4013a0:	c4 e1 f9 6e c2       	vmovq  xmm0,rdx
  4013a5:	89 c6                	mov    esi,eax
  4013a7:	bf ca 20 40 00       	mov    edi,0x4020ca
  4013ac:	b8 01 00 00 00       	mov    eax,0x1
  4013b1:	e8 ca fc ff ff       	call   401080 <printf@plt>
    for (int index = 0; index < 8; ++index) {
  4013b6:	83 85 3c ff ff ff 01 	add    DWORD PTR [rbp-0xc4],0x1
  4013bd:	83 bd 3c ff ff ff 07 	cmp    DWORD PTR [rbp-0xc4],0x7
  4013c4:	7e bd                	jle    401383 <func+0x20d>
    }
}
  4013c6:	90                   	nop
  4013c7:	48 8b 45 e8          	mov    rax,QWORD PTR [rbp-0x18]
  4013cb:	64 48 2b 04 25 28 00 	sub    rax,QWORD PTR fs:0x28
  4013d2:	00 00 
  4013d4:	74 05                	je     4013db <func+0x265>
  4013d6:	e8 95 fc ff ff       	call   401070 <__stack_chk_fail@plt>
  4013db:	48 8d 65 f0          	lea    rsp,[rbp-0x10]
  4013df:	5b                   	pop    rbx
  4013e0:	41 5a                	pop    r10
  4013e2:	5d                   	pop    rbp
  4013e3:	49 8d 62 f8          	lea    rsp,[r10-0x8]
  4013e7:	c3                   	ret

00000000004013e8 <caller>:

__attribute__((noinline, noclone))
void caller(void)
{
  4013e8:	f3 0f 1e fa          	endbr64
  4013ec:	4c 8d 54 24 08       	lea    r10,[rsp+0x8]
  4013f1:	48 83 e4 e0          	and    rsp,0xffffffffffffffe0
  4013f5:	41 ff 72 f8          	push   QWORD PTR [r10-0x8]
  4013f9:	55                   	push   rbp
  4013fa:	48 89 e5             	mov    rbp,rsp
  4013fd:	41 52                	push   r10
  4013ff:	48 81 ec 28 01 00 00 	sub    rsp,0x128
    int e = 11;
  401406:	c7 85 e4 fe ff ff 0b 	mov    DWORD PTR [rbp-0x11c],0xb
  40140d:	00 00 00 
    int f = 22;
  401410:	c7 85 e8 fe ff ff 16 	mov    DWORD PTR [rbp-0x118],0x16
  401417:	00 00 00 
    int g = 33;
  40141a:	c7 85 ec fe ff ff 21 	mov    DWORD PTR [rbp-0x114],0x21
  401421:	00 00 00 
    int h = 44;
  401424:	c7 85 f0 fe ff ff 2c 	mov    DWORD PTR [rbp-0x110],0x2c
  40142b:	00 00 00 
    int i = 55;
  40142e:	c7 85 f4 fe ff ff 37 	mov    DWORD PTR [rbp-0x10c],0x37
  401435:	00 00 00 
    int j = 66;
  401438:	c7 85 f8 fe ff ff 42 	mov    DWORD PTR [rbp-0x108],0x42
  40143f:	00 00 00 
    int k = 77;
  401442:	c7 85 fc fe ff ff 4d 	mov    DWORD PTR [rbp-0x104],0x4d
  401449:	00 00 00 

    structparm s = {
  40144c:	c7 45 90 65 00 00 00 	mov    DWORD PTR [rbp-0x70],0x65
  401453:	c7 45 94 ca 00 00 00 	mov    DWORD PTR [rbp-0x6c],0xca
  40145a:	c5 fb 10 05 76 0c 00 	vmovsd xmm0,QWORD PTR [rip+0xc76]        # 4020d8 <_IO_stdin_used+0xd8>
  401461:	00 
  401462:	c5 fb 11 45 98       	vmovsd QWORD PTR [rbp-0x68],xmm0
        .a = 101,
        .b = 202,
        .d = 303.5
    };

    long double ld = 404.25L;
# push the valid value of ld to $st[0]
# value: 0x4007ca20000000000000
  401467:	db 2d 73 0c 00 00    	fld    TBYTE PTR [rip+0xc73]        # 4020e0 <_IO_stdin_used+0xe0>
# copy the value of $st[0] to rbp - 0x60 (size 80 bit)
# then pop the float-stack
  40146d:	db 7d a0             	fstp   TBYTE PTR [rbp-0x60]
    double m = 505.5;
  401470:	c5 fb 10 05 78 0c 00 	vmovsd xmm0,QWORD PTR [rip+0xc78]        # 4020f0 <_IO_stdin_used+0xf0>
  401477:	00 
  401478:	c5 fb 11 45 80       	vmovsd QWORD PTR [rbp-0x80],xmm0
    double n = 606.75;
  40147d:	c5 fb 10 05 73 0c 00 	vmovsd xmm0,QWORD PTR [rip+0xc73]        # 4020f8 <_IO_stdin_used+0xf8>
  401484:	00 
  401485:	c5 fb 11 45 88       	vmovsd QWORD PTR [rbp-0x78],xmm0
  40148a:	c5 fa 10 05 6e 0c 00 	vmovss xmm0,DWORD PTR [rip+0xc6e]        # 402100 <_IO_stdin_used+0x100>
  401491:	00 
  401492:	c5 fa 11 85 40 ff ff 	vmovss DWORD PTR [rbp-0xc0],xmm0
  401499:	ff 
  40149a:	c5 fa 10 05 62 0c 00 	vmovss xmm0,DWORD PTR [rip+0xc62]        # 402104 <_IO_stdin_used+0x104>
  4014a1:	00 
  4014a2:	c5 fa 11 85 44 ff ff 	vmovss DWORD PTR [rbp-0xbc],xmm0
  4014a9:	ff 
  4014aa:	c5 fa 10 05 56 0c 00 	vmovss xmm0,DWORD PTR [rip+0xc56]        # 402108 <_IO_stdin_used+0x108>
  4014b1:	00 
  4014b2:	c5 fa 11 85 48 ff ff 	vmovss DWORD PTR [rbp-0xb8],xmm0
  4014b9:	ff 
  4014ba:	c5 fa 10 05 4a 0c 00 	vmovss xmm0,DWORD PTR [rip+0xc4a]        # 40210c <_IO_stdin_used+0x10c>
  4014c1:	00 
  4014c2:	c5 fa 11 85 4c ff ff 	vmovss DWORD PTR [rbp-0xb4],xmm0
  4014c9:	ff 
  4014ca:	c5 fa 10 05 3e 0c 00 	vmovss xmm0,DWORD PTR [rip+0xc3e]        # 402110 <_IO_stdin_used+0x110>
  4014d1:	00 
  4014d2:	c5 fa 11 85 50 ff ff 	vmovss DWORD PTR [rbp-0xb0],xmm0
  4014d9:	ff 
  4014da:	c5 fa 10 05 32 0c 00 	vmovss xmm0,DWORD PTR [rip+0xc32]        # 402114 <_IO_stdin_used+0x114>
  4014e1:	00 
  4014e2:	c5 fa 11 85 54 ff ff 	vmovss DWORD PTR [rbp-0xac],xmm0
  4014e9:	ff 
  4014ea:	c5 fa 10 05 26 0c 00 	vmovss xmm0,DWORD PTR [rip+0xc26]        # 402118 <_IO_stdin_used+0x118>
  4014f1:	00 
  4014f2:	c5 fa 11 85 58 ff ff 	vmovss DWORD PTR [rbp-0xa8],xmm0
  4014f9:	ff 
  4014fa:	c5 fa 10 05 1a 0c 00 	vmovss xmm0,DWORD PTR [rip+0xc1a]        # 40211c <_IO_stdin_used+0x11c>
  401501:	00 
  401502:	c5 fa 11 85 5c ff ff 	vmovss DWORD PTR [rbp-0xa4],xmm0
  401509:	ff 
  40150a:	c5 fa 10 85 5c ff ff 	vmovss xmm0,DWORD PTR [rbp-0xa4]
  401511:	ff 
  401512:	c5 fa 11 85 60 ff ff 	vmovss DWORD PTR [rbp-0xa0],xmm0
  401519:	ff 
  40151a:	c5 fa 10 85 58 ff ff 	vmovss xmm0,DWORD PTR [rbp-0xa8]
  401521:	ff 
  401522:	c5 fa 11 85 64 ff ff 	vmovss DWORD PTR [rbp-0x9c],xmm0
  401529:	ff 
  40152a:	c5 fa 10 85 54 ff ff 	vmovss xmm0,DWORD PTR [rbp-0xac]
  401531:	ff 
  401532:	c5 fa 11 85 68 ff ff 	vmovss DWORD PTR [rbp-0x98],xmm0
  401539:	ff 
  40153a:	c5 fa 10 85 50 ff ff 	vmovss xmm0,DWORD PTR [rbp-0xb0]
  401541:	ff 
  401542:	c5 fa 11 85 6c ff ff 	vmovss DWORD PTR [rbp-0x94],xmm0
  401549:	ff 
  40154a:	c5 fa 10 85 4c ff ff 	vmovss xmm0,DWORD PTR [rbp-0xb4]
  401551:	ff 
  401552:	c5 fa 11 85 70 ff ff 	vmovss DWORD PTR [rbp-0x90],xmm0
  401559:	ff 
  40155a:	c5 fa 10 85 48 ff ff 	vmovss xmm0,DWORD PTR [rbp-0xb8]
  401561:	ff 
  401562:	c5 fa 11 85 74 ff ff 	vmovss DWORD PTR [rbp-0x8c],xmm0
  401569:	ff 
  40156a:	c5 fa 10 85 44 ff ff 	vmovss xmm0,DWORD PTR [rbp-0xbc]
  401571:	ff 
  401572:	c5 fa 11 85 78 ff ff 	vmovss DWORD PTR [rbp-0x88],xmm0
  401579:	ff 
  40157a:	c5 fa 10 85 40 ff ff 	vmovss xmm0,DWORD PTR [rbp-0xc0]
  401581:	ff 
  401582:	c5 fa 11 85 7c ff ff 	vmovss DWORD PTR [rbp-0x84],xmm0
  401589:	ff 
/* Create the vector [A B C D E F G H].  */
extern __inline __m256 __attribute__((__gnu_inline__, __always_inline__, __artificial__))
_mm256_set_ps (float __A, float __B, float __C, float __D,
	       float __E, float __F, float __G, float __H)
{
  return __extension__ (__m256){ __H, __G, __F, __E,
  40158a:	c5 fa 10 8d 60 ff ff 	vmovss xmm1,DWORD PTR [rbp-0xa0]
  401591:	ff 
  401592:	c5 fa 10 85 64 ff ff 	vmovss xmm0,DWORD PTR [rbp-0x9c]
  401599:	ff 
  40159a:	c5 f8 14 c9          	vunpcklps xmm1,xmm0,xmm1
  40159e:	c5 fa 10 95 68 ff ff 	vmovss xmm2,DWORD PTR [rbp-0x98]
  4015a5:	ff 
  4015a6:	c5 fa 10 85 6c ff ff 	vmovss xmm0,DWORD PTR [rbp-0x94]
  4015ad:	ff 
  4015ae:	c5 f8 14 c2          	vunpcklps xmm0,xmm0,xmm2
  4015b2:	c5 f8 16 c9          	vmovlhps xmm1,xmm0,xmm1
  4015b6:	c5 fa 10 95 70 ff ff 	vmovss xmm2,DWORD PTR [rbp-0x90]
  4015bd:	ff 
  4015be:	c5 fa 10 85 74 ff ff 	vmovss xmm0,DWORD PTR [rbp-0x8c]
  4015c5:	ff 
  4015c6:	c5 f8 14 d2          	vunpcklps xmm2,xmm0,xmm2
  4015ca:	c5 fa 10 9d 78 ff ff 	vmovss xmm3,DWORD PTR [rbp-0x88]
  4015d1:	ff 
  4015d2:	c5 fa 10 85 7c ff ff 	vmovss xmm0,DWORD PTR [rbp-0x84]
  4015d9:	ff 
  4015da:	c5 f8 14 c3          	vunpcklps xmm0,xmm0,xmm3
  4015de:	c5 f8 16 c2          	vmovlhps xmm0,xmm0,xmm2
  4015e2:	c4 e3 7d 18 c1 01    	vinsertf128 ymm0,ymm0,xmm1,0x1

extern __inline __m256 __attribute__((__gnu_inline__, __always_inline__, __artificial__))
_mm256_setr_ps (float __A, float __B, float __C, float __D,
		float __E, float __F, float __G, float __H)
{
  return _mm256_set_ps (__H, __G, __F, __E, __D, __C, __B, __A);
  4015e8:	90                   	nop

    __m256 y = _mm256_setr_ps(
  4015e9:	c5 fc 29 45 b0       	vmovaps YMMWORD PTR [rbp-0x50],ymm0
  4015ee:	c5 fa 10 05 2a 0b 00 	vmovss xmm0,DWORD PTR [rip+0xb2a]        # 402120 <_IO_stdin_used+0x120>
  4015f5:	00 
  4015f6:	c5 fa 11 85 00 ff ff 	vmovss DWORD PTR [rbp-0x100],xmm0
  4015fd:	ff 
  4015fe:	c5 fa 10 05 1e 0b 00 	vmovss xmm0,DWORD PTR [rip+0xb1e]        # 402124 <_IO_stdin_used+0x124>
  401605:	00 
  401606:	c5 fa 11 85 04 ff ff 	vmovss DWORD PTR [rbp-0xfc],xmm0
  40160d:	ff 
  40160e:	c5 fa 10 05 12 0b 00 	vmovss xmm0,DWORD PTR [rip+0xb12]        # 402128 <_IO_stdin_used+0x128>
  401615:	00 
  401616:	c5 fa 11 85 08 ff ff 	vmovss DWORD PTR [rbp-0xf8],xmm0
  40161d:	ff 
  40161e:	c5 fa 10 05 06 0b 00 	vmovss xmm0,DWORD PTR [rip+0xb06]        # 40212c <_IO_stdin_used+0x12c>
  401625:	00 
  401626:	c5 fa 11 85 0c ff ff 	vmovss DWORD PTR [rbp-0xf4],xmm0
  40162d:	ff 
  40162e:	c5 fa 10 05 fa 0a 00 	vmovss xmm0,DWORD PTR [rip+0xafa]        # 402130 <_IO_stdin_used+0x130>
  401635:	00 
  401636:	c5 fa 11 85 10 ff ff 	vmovss DWORD PTR [rbp-0xf0],xmm0
  40163d:	ff 
  40163e:	c5 fa 10 05 ee 0a 00 	vmovss xmm0,DWORD PTR [rip+0xaee]        # 402134 <_IO_stdin_used+0x134>
  401645:	00 
  401646:	c5 fa 11 85 14 ff ff 	vmovss DWORD PTR [rbp-0xec],xmm0
  40164d:	ff 
  40164e:	c5 fa 10 05 e2 0a 00 	vmovss xmm0,DWORD PTR [rip+0xae2]        # 402138 <_IO_stdin_used+0x138>
  401655:	00 
  401656:	c5 fa 11 85 18 ff ff 	vmovss DWORD PTR [rbp-0xe8],xmm0
  40165d:	ff 
  40165e:	c5 fa 10 05 d6 0a 00 	vmovss xmm0,DWORD PTR [rip+0xad6]        # 40213c <_IO_stdin_used+0x13c>
  401665:	00 
  401666:	c5 fa 11 85 1c ff ff 	vmovss DWORD PTR [rbp-0xe4],xmm0
  40166d:	ff 
  40166e:	c5 fa 10 85 1c ff ff 	vmovss xmm0,DWORD PTR [rbp-0xe4]
  401675:	ff 
  401676:	c5 fa 11 85 20 ff ff 	vmovss DWORD PTR [rbp-0xe0],xmm0
  40167d:	ff 
  40167e:	c5 fa 10 85 18 ff ff 	vmovss xmm0,DWORD PTR [rbp-0xe8]
  401685:	ff 
  401686:	c5 fa 11 85 24 ff ff 	vmovss DWORD PTR [rbp-0xdc],xmm0
  40168d:	ff 
  40168e:	c5 fa 10 85 14 ff ff 	vmovss xmm0,DWORD PTR [rbp-0xec]
  401695:	ff 
  401696:	c5 fa 11 85 28 ff ff 	vmovss DWORD PTR [rbp-0xd8],xmm0
  40169d:	ff 
  40169e:	c5 fa 10 85 10 ff ff 	vmovss xmm0,DWORD PTR [rbp-0xf0]
  4016a5:	ff 
  4016a6:	c5 fa 11 85 2c ff ff 	vmovss DWORD PTR [rbp-0xd4],xmm0
  4016ad:	ff 
  4016ae:	c5 fa 10 85 0c ff ff 	vmovss xmm0,DWORD PTR [rbp-0xf4]
  4016b5:	ff 
  4016b6:	c5 fa 11 85 30 ff ff 	vmovss DWORD PTR [rbp-0xd0],xmm0
  4016bd:	ff 
  4016be:	c5 fa 10 85 08 ff ff 	vmovss xmm0,DWORD PTR [rbp-0xf8]
  4016c5:	ff 
  4016c6:	c5 fa 11 85 34 ff ff 	vmovss DWORD PTR [rbp-0xcc],xmm0
  4016cd:	ff 
  4016ce:	c5 fa 10 85 04 ff ff 	vmovss xmm0,DWORD PTR [rbp-0xfc]
  4016d5:	ff 
  4016d6:	c5 fa 11 85 38 ff ff 	vmovss DWORD PTR [rbp-0xc8],xmm0
  4016dd:	ff 
  4016de:	c5 fa 10 85 00 ff ff 	vmovss xmm0,DWORD PTR [rbp-0x100]
  4016e5:	ff 
  4016e6:	c5 fa 11 85 3c ff ff 	vmovss DWORD PTR [rbp-0xc4],xmm0
  4016ed:	ff 
  return __extension__ (__m256){ __H, __G, __F, __E,
  4016ee:	c5 fa 10 8d 20 ff ff 	vmovss xmm1,DWORD PTR [rbp-0xe0]
  4016f5:	ff 
  4016f6:	c5 fa 10 85 24 ff ff 	vmovss xmm0,DWORD PTR [rbp-0xdc]
  4016fd:	ff 
  4016fe:	c5 f8 14 c9          	vunpcklps xmm1,xmm0,xmm1
  401702:	c5 fa 10 95 28 ff ff 	vmovss xmm2,DWORD PTR [rbp-0xd8]
  401709:	ff 
  40170a:	c5 fa 10 85 2c ff ff 	vmovss xmm0,DWORD PTR [rbp-0xd4]
  401711:	ff 
  401712:	c5 f8 14 c2          	vunpcklps xmm0,xmm0,xmm2
  401716:	c5 f8 16 c9          	vmovlhps xmm1,xmm0,xmm1
  40171a:	c5 fa 10 95 30 ff ff 	vmovss xmm2,DWORD PTR [rbp-0xd0]
  401721:	ff 
  401722:	c5 fa 10 85 34 ff ff 	vmovss xmm0,DWORD PTR [rbp-0xcc]
  401729:	ff 
  40172a:	c5 f8 14 d2          	vunpcklps xmm2,xmm0,xmm2
  40172e:	c5 fa 10 9d 38 ff ff 	vmovss xmm3,DWORD PTR [rbp-0xc8]
  401735:	ff 
  401736:	c5 fa 10 85 3c ff ff 	vmovss xmm0,DWORD PTR [rbp-0xc4]
  40173d:	ff 
  40173e:	c5 f8 14 c3          	vunpcklps xmm0,xmm0,xmm3
  401742:	c5 f8 16 c2          	vmovlhps xmm0,xmm0,xmm2
  401746:	c4 e3 7d 18 c1 01    	vinsertf128 ymm0,ymm0,xmm1,0x1
  return _mm256_set_ps (__H, __G, __F, __E, __D, __C, __B, __A);
  40174c:	90                   	nop
        1.0f, 2.0f, 3.0f, 4.0f,
        5.0f, 6.0f, 7.0f, 8.0f
    );

    __m256 z = _mm256_setr_ps(
  40174d:	c5 fc 29 45 d0       	vmovaps YMMWORD PTR [rbp-0x30],ymm0
    );
  /*
     * 在 GDB 中重点观察下面这个调用之前和之后的状态。
     */
    func(e, f, s, g, h, ld, m, y, z, n, i, j, k);
# 11. i -> r9d
  401752:	44 8b 8d f4 fe ff ff 	mov    r9d,DWORD PTR [rbp-0x10c]
# 10. n->xmm2, move to xmm4 later
  401759:	c5 fb 10 55 88       	vmovsd xmm2,QWORD PTR [rbp-0x78]
# 9. __m256 z -> ymm1, move to ymm3 later
  40175e:	c5 fc 28 4d d0       	vmovaps ymm1,YMMWORD PTR [rbp-0x30]
# 8. __m256 y -> ymm0, move to ymm2 later
  401763:	c5 fc 28 45 b0       	vmovaps ymm0,YMMWORD PTR [rbp-0x50]
# 7. m->xmm5, move to xmm1 later
  401768:	c5 fb 10 6d 80       	vmovsd xmm5,QWORD PTR [rbp-0x80]
# 5. h -> r10d, move to r8d later
  40176d:	44 8b 95 f0 fe ff ff 	mov    r10d,DWORD PTR [rbp-0x110]
# 4. g->ecx
  401774:	8b 8d ec fe ff ff    	mov    ecx,DWORD PTR [rbp-0x114]
# rpb-0x70: (high)| s.b (4bytes) | s.a (4bytes) |
# 3.1-2: s.b, b.a -> rdx
# rdx : | s.b | s.a |
  40177a:	48 8b 55 90          	mov    rdx,QWORD PTR [rbp-0x70]
# 3.3 s.d -> rdi, mov to xmm0 later
  40177e:	48 8b 7d 98          	mov    rdi,QWORD PTR [rbp-0x68]
# 2. f -> esi
  401782:	8b b5 e8 fe ff ff    	mov    esi,DWORD PTR [rbp-0x118]
# 1. e-> eax, mov to edi later
  401788:	8b 85 e4 fe ff ff    	mov    eax,DWORD PTR [rbp-0x11c]
# 13. push k to stack
  40178e:	44 8b 85 fc fe ff ff 	mov    r8d,DWORD PTR [rbp-0x104]
  401795:	41 50                	push   r8
# 12. push j to stack
  401797:	44 8b 85 f8 fe ff ff 	mov    r8d,DWORD PTR [rbp-0x108]
  40179e:	41 50                	push   r8
# 6. ld -> stack
# 128bit
# higher bytes
  4017a0:	ff 75 a8             	push   QWORD PTR [rbp-0x58]
# lower bytes
  4017a3:	ff 75 a0             	push   QWORD PTR [rbp-0x60]
# so 32 bytes memory-args space totally

# 10. n -> xmm4
  4017a6:	c5 eb 10 e2          	vmovsd xmm4,xmm2,xmm2
# 9. z -> ymm3
  4017aa:	c5 fc 28 d9          	vmovaps ymm3,ymm1
# 8. y -> ymm2
  4017ae:	c5 fc 28 d0          	vmovaps ymm2,ymm0
# 7. m -> xmm1
  4017b2:	c5 d3 10 cd          	vmovsd xmm1,xmm5,xmm5
# 5. h -> r8d
  4017b6:	45 89 d0             	mov    r8d,r10d
# 3.3 s.d -> xmm0
  4017b9:	c4 e1 f9 6e c7       	vmovq  xmm0,rdi
# 1. e -> edi
  4017be:	89 c7                	mov    edi,eax
  4017c0:	e8 b1 f9 ff ff       	call   401176 <func>
  4017c5:	48 83 c4 20          	add    rsp,0x20
}
  4017c9:	90                   	nop
  4017ca:	4c 8b 55 f8          	mov    r10,QWORD PTR [rbp-0x8]
  4017ce:	c9                   	leave
  4017cf:	49 8d 62 f8          	lea    rsp,[r10-0x8]
  4017d3:	c3                   	ret

00000000004017d4 <main>:

int main(void)
{
  4017d4:	f3 0f 1e fa          	endbr64
  4017d8:	55                   	push   rbp
  4017d9:	48 89 e5             	mov    rbp,rsp
    caller();
  4017dc:	e8 07 fc ff ff       	call   4013e8 <caller>
    return 0;
  4017e1:	b8 00 00 00 00       	mov    eax,0x0
}
  4017e6:	5d                   	pop    rbp
  4017e7:	c3                   	ret

Disassembly of section .fini:

00000000004017e8 <_fini>:
  4017e8:	f3 0f 1e fa          	endbr64
  4017ec:	48 83 ec 08          	sub    rsp,0x8
  4017f0:	48 83 c4 08          	add    rsp,0x8
  4017f4:	c3                   	ret
```

最终的参数分配结果：  

```
func(
    e=%edi,
    f=%esi,
    s={%rdx,%xmm0},
    g=%ecx,
    h=%r8d,
    ld=stack,
    m=%xmm1,
    y=%ymm2,
    z=%ymm3,
    n=%xmm4,
    i=%r9d,
    j=stack,
    k=stack
)
```
| 参数   | 大小 | eightbyte 分类    | 最终位置           |
| ---- | -: | --------------- | -------------- |
| `e`  |  4 | `INTEGER`       | `%edi`         |
| `f`  |  4 | `INTEGER`       | `%esi`         |
| `s`  | 16 | `INTEGER + SSE` | `%rdx + %xmm0` |
| `g`  |  4 | `INTEGER`       | `%ecx`         |
| `h`  |  4 | `INTEGER`       | `%r8d`         |
| `ld` | 16 | `X87 + X87UP`   | 栈              |
| `m`  |  8 | `SSE`           | `%xmm1`        |
| `y`  | 32 | `SSE + 3×SSEUP` | `%ymm2`        |
| `z`  | 32 | `SSE + 3×SSEUP` | `%ymm3`        |
| `n`  |  8 | `SSE`           | `%xmm4`        |
| `i`  |  4 | `INTEGER`       | `%r9d`         |
| `j`  |  4 | `INTEGER`，寄存器耗尽 | 栈              |
| `k`  |  4 | `INTEGER`，寄存器耗尽 | 栈              |

注意，abi文档中提到的  
`Once arguments are classified, the registers get assigned (in left-to-right order)`  
这里的`left to right`指的是寄存器`assigned`的顺序，而非代码实际赋值的顺序。abi保证了最终寄存器的分配规则，而编译器可以决定先将后部分的参数存入寄存器。  
至少在我的调试过程中，实际代码赋值和操作顺序，不论是针对寄存器或是栈，都是从右到左的。  

总结：  

| 内容                              | 是否由 ABI 规定 |
| ------------------------------- | ---------- |
| `INTEGER` 使用 `%rdi` 至 `%r9`     | 是          |
| `SSE/SSEUP` 使用向量寄存器             | 是          |
| `X87` 参数通过内存                    | 是          |
| 栈参数从右向左布置                       | 是          |
| `__m256` 使用一个 YMM 寄存器           | 是          |
| 调用点满足所需栈对齐                      | 是          |
| 参数进入函数后保存到局部栈帧                  | 否          |
| 局部帧大小为 `0x140`                  | 否          |
| 使用 `%rbp` 作为帧指针                 | 否          |
| `_mm256_setr_ps` 使用多条 unpack 指令 | 否          |
| 使用 stack canary                 | 否          |
| 使用 `r10` 保存原始 `%rsp`            | 否          |

# refs


