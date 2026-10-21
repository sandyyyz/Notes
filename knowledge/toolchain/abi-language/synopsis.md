# SYNOPSIS syntax

在通过`man command`阅读指令手册时， 常常看到以下格式的指令描述，该描述遵循 *SYNOPSIS* 规范。

```sh

NAME
       strace - trace system calls and signals

SYNOPSIS
       strace [-ACdffhikqqrtttTvVwxxyyzZ] [-I n] [-b execve] [-e expr]... [-O overhead] [-S sortby] [-U columns] [-a column] [-o file] [-s strsize] [-X format]
              [-P path]... [-p pid]... [--seccomp-bpf] { -p pid | [-DDD] [-E var[=val]]... [-u username] command [args] }

       strace -c [-dfwzZ] [-I n] [-b execve] [-e expr]... [-O overhead] [-S sortby] [-U columns] [-P path]... [-p pid]... [--seccomp-bpf] { -p pid | [-DDD]
```
在这里对其语法规范做总结：   

## 字面量

命令名、选项以及固定关键字需要原样输入。如 `strace -p pid` 中的 `strace`

## 参数占位符 <>

`pid`、`file`、`command` 等名词表示需要替换为实际值的参数。如 `strace -p pid` 中的 `pid`

## 可选项[...]

可选项表示其中内容可省略，如`[-o file]`

## 必选组{...}

花括号表示其中的内容必须出现，通常与 | 配合表示必须选择一个分支。如

```sh
{ -p pid | command }
```
## 互斥选择 |

竖线表示从两侧或多个分支中选择一种，不表示 Shell 管道。如：`-p pid | command`

## 重复项...

省略号表示其前面的参数或参数组可以重复出现。如

```sh
[-e expr]...

strace -e trace=openat -e trace=read command
```

## 可选后缀

嵌套方括号表示参数的一部分可选，其余部分仍为必需。

```sh
var[=val]

strace -E LANG=C command
```

其中 var 必须提供，=val 可以省略。

## 带参数的选项

选项后的占位符是该选项所需的参数。选项本身可以省略，但一旦使用，就必须提供对应参数。
```sh
[-s strsize]

strace -s 256 command
```

## 合并短选项

不带参数的单字符短选项通常可以合并书写。

```sh
[-fTt]

strace -fTt command

等价于：

strace -f -T -t command

```

## 命令及其参数

command 表示待执行的命令，[args] 表示该命令的可选参数。

```sh
command [args]

strace ls -l
```

其中 ls 是 command，-l 是 args。

## 结束选项解析 --

-- 表示当前工具的选项解析到此结束，后续内容作为命令或普通参数处理。

```sh

-- command [args]

strace -- command -x
```

## 在man中搜索

注意如果直接搜索关键字，很可能会有非常多无关匹配项，需要结合正则表达式搜索。
一个搜索"行首缩进 + 选项名 + 空格或逗号"的例子如下：

```regex
/^ *-e[ ,]
```

TODO: 后续单独做一个笔记概述正则表达式常用语法。

## command/args

对于：

```sh
command [args]
```
- command：需要由 strace 启动并追踪的程序，必需；
- [args]：传递给该程序的命令行参数，可选；
- 方括号只表示 args 可选，不需要实际输入。

如：

```sh
strace ls -l /tmp
```

## markdown 代码块常用支持渲染类型

| 标识符        | 内容类型          |
| ------------- | ----------------- |
| `text`        | 纯文本，不进行语法高亮 |
| `c`           | C                 |
| `cpp`         | C++               |
| `rust`        | Rust              |
| `go`          | Go                |
| `java`        | Java              |
| `python`      | Python            |
| `javascript`  | JavaScript        |
| `typescript`  | TypeScript        |
| `bash`        | Bash 或 Shell 命令 |
| `sh`          | POSIX Shell       |
| `powershell`  | PowerShell        |
| `sql`         | SQL               |
| `html`        | HTML              |
| `css`         | CSS               |
| `json`        | JSON              |
| `yaml`        | YAML              |
| `xml`         | XML               |
| `markdown`    | Markdown 源码     |
| `diff`        | 补丁或文本差异     |
| `makefile`    | Makefile          |
| `cmake`       | CMake             |
| `assembly`    | 汇编语言          |
| `ini`         | INI 配置文件      |
| `toml`        | TOML 配置文件     |
| `dockerfile`  | Dockerfile        |
| `regex`       | 正则表达式，依赖渲染器支持 |

