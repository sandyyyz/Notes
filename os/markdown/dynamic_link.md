# Dynamic Link

编译阶段，各个源文件被编译成目标文件。目标文件中包含代码、数据、符号表和重定位信息，但通常不包含最终运行地址。链接阶段，链接器将多个目标文件组合成 ELF 文件，确定各段布局，并为动态库符号生成 `.plt`、`.got.plt`、`.rela.plt` 等结构。对于动态库函数调用，调用点会跳转到对应的 PLT 表项。

链接器会初始化 GOT 表项，使其最初指向 PLT 内部的解析路径。程序执行时，内核通过 `execve()` 加载 ELF 和动态链接器 ld.so，建立进程地址空间后将控制权交给 ld.so。动态链接器加载所需共享库，完成必要重定位、TLS 初始化以及构造函数执行。

## 核心结构

| 结构 | 作用 |
| --- | --- |
| PLT | Procedure Linkage Table，函数调用跳板 |
| GOT | Global Offset Table，保存运行时地址 |
| `.got.plt` | 保存 PLT 相关的动态解析入口和最终函数地址 |
| `.rela.plt` | 描述需要为 PLT 解析的重定位项 |
| ld.so | 用户态动态链接器，负责加载共享库并完成重定位 |

## Lazy Binding

对于采用 Lazy Binding 的函数调用，第一次执行时：

```text
main
  ↓
foo@plt
  ↓
GOT[foo]
  ↓
foo@plt+6
  ↓
plt0
  ↓
ld.so
```

动态链接器根据重定位表找到 foo 在共享库中的真实地址，将其写回对应 GOT 表项，然后直接跳转到真实函数执行。

后续再次调用：

```text
foo@plt
  ↓
GOT[foo]
  ↓
real foo
```

由于 GOT 已经包含真实地址，因此无需再进入动态链接器。

## Eager Binding 与安全选项

如果启用 `LD_BIND_NOW=1` 或链接时使用 `-Wl,-z,now`，动态链接器会在程序启动阶段一次性解析 PLT 重定位，而不是等到第一次调用时再解析。这样会增加启动成本，但能减少运行时首次调用抖动，并常与 RELRO 配合使用。

| 选项 | 效果 |
| --- | --- |
| Partial RELRO | `.got` 只读，但 `.got.plt` 仍可能在 lazy binding 阶段被写入 |
| Full RELRO (`-z relro -z now`) | 启动时完成绑定，随后 GOT/PLT 相关表项只读，降低 GOT overwrite 风险 |
