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

`caller(callee-saved)`寄存器: `%rbp, %rbx, %r12-%r15`  
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

# refs

[AMD64_ABI](https://gitlab.com/x86-psABIs/x86-64-ABI)
