# 在源码目录中构建 Ctags 和 Cscope 索引

本文档用于快速查阅如何在 C、C++ 或大型系统源码目录中构建 Ctags 与 Cscope 索引。推荐先生成统一的 `cscope.files` 文件列表，再让 Cscope 和 Ctags 共用该列表，以确保索引范围一致，并便于排除构建产物。

## 1. 前置工具

确认系统已经安装 Cscope 和 Ctags：

```bash
cscope --version
ctags --version
```

Debian、Ubuntu 等系统可以执行：

```bash
sudo apt install cscope universal-ctags
```

如果发行版没有提供 Universal Ctags，也可以安装 Exuberant Ctags，但部分扩展参数可能不受支持。

## 2. 构建源码文件列表

进入源码根目录：

```bash
cd /path/to/source
```

递归收集当前目录及所有子目录中的 C、C++ 和汇编源文件：

```bash
find . -type f \( \
    -name '*.c'   -o \
    -name '*.h'   -o \
    -name '*.cc'  -o \
    -name '*.cpp' -o \
    -name '*.cxx' -o \
    -name '*.hpp' -o \
    -name '*.S'   -o \
    -name '*.s' \
\) -print > cscope.files
```

生成的 `cscope.files` 保存了所有需要建立索引的源码文件路径。

> 必须使用 `\( ... \)` 将多个 `-name` 条件分组，否则 `find` 中 `-o` 的优先级可能导致 `-type f` 只约束第一个匹配条件。

## 3. 构建 Cscope 数据库

Linux 内核、glibc、Binutils 等大型源码树推荐执行：

```bash
cscope -b -q -k -i cscope.files
```

参数含义：

- `-b`：仅构建数据库，不进入交互界面。
- `-q`：生成反向索引，提高查询速度。
- `-k`：内核模式，不搜索系统头文件目录。
- `-i cscope.files`：从指定文件读取待索引的源码文件列表。

通常会生成以下文件：

```text
cscope.files
cscope.out
cscope.in.out
cscope.po.out
```

对于普通用户态小型工程，如果希望 Cscope 同时搜索系统头文件，可以去掉 `-k`：

```bash
cscope -b -q -i cscope.files
```

## 4. 构建 Ctags 数据库

推荐复用 `cscope.files`：

```bash
ctags -L cscope.files
```

生成的索引文件为：

```text
tags
```

如果使用 Universal Ctags，可以增加语言、字段和限定名称配置：

```bash
ctags \
    --languages=C,C++ \
    --fields=+iaS \
    --extras=+q \
    -L cscope.files
```

参数含义：

- `--languages=C,C++`：只解析 C 和 C++ 源文件。
- `--fields=+iaS`：增加继承关系、访问权限和函数签名等字段。
- `--extras=+q`：生成带作用域限定的额外标签。
- `-L cscope.files`：读取统一的源码文件列表。

也可以直接递归建立 Ctags 索引：

```bash
ctags -R .
```

但这种方法与 Cscope 的索引范围可能不一致，也不便统一排除构建目录，因此不作为首选。

## 5. 推荐的自动构建脚本

在源码根目录创建 `build-tags.sh`：

```bash
#!/bin/sh

set -eu

find . -type f \( \
    -name '*.c'   -o \
    -name '*.h'   -o \
    -name '*.cc'  -o \
    -name '*.cpp' -o \
    -name '*.cxx' -o \
    -name '*.hpp' -o \
    -name '*.S'   -o \
    -name '*.s' \
\) \
    -not -path './.git/*' \
    -not -path './build/*' \
    -not -path './build-*/*' \
    -not -path './out/*' \
    -not -path './output/*' \
    -print > cscope.files

cscope -b -q -k -i cscope.files
ctags -L cscope.files
```

增加执行权限并运行：

```bash
chmod +x build-tags.sh
./build-tags.sh
```

如果需要使用 Universal Ctags 的扩展参数，可以将脚本中的 Ctags 命令替换为：

```bash
ctags \
    --languages=C,C++ \
    --fields=+iaS \
    --extras=+q \
    -L cscope.files
```

根据实际源码树，可以继续增加排除规则：

```bash
-not -path './目录名/*'
```

## 6. 在 Vim 中使用 Cscope

建议从源码根目录启动 Vim：

```bash
vim main.c
```

手动加载 Cscope 数据库：

```vim
:cs add cscope.out
```

常用查询：

```vim
:cs find s symbol
:cs find g symbol
:cs find c function
:cs find d function
:cs find t text
:cs find f filename
:cs find i header.h
```

查询类型：

- `s`：查找符号出现位置。
- `g`：查找符号或函数定义。
- `c`：查找调用指定函数的位置。
- `d`：查找指定函数调用的其他函数。
- `t`：查找指定文本。
- `f`：查找文件。
- `i`：查找包含指定头文件的位置。

查看已经加载的 Cscope 数据库：

```vim
:cs show
```

重新加载数据库：

```vim
:cs reset
```

## 7. 在 Vim 中使用 Ctags

常用操作：

```text
Ctrl-]    跳转到光标所在符号的定义
Ctrl-t    返回上一个位置
:tn       跳转到下一个匹配定义
:tp       跳转到上一个匹配定义
:tselect  查看所有匹配定义
```

如果 Vim 没有自动加载当前目录中的 `tags` 文件，可以执行：

```vim
:set tags=./tags,tags;
```

末尾的分号表示 Vim 可以从当前文件所在目录开始，逐级向上查找 `tags` 文件。

## 8. 建议加入 `.gitignore`

将以下内容加入源码仓库的 `.gitignore`：

```gitignore
cscope.files
cscope.out
cscope.in.out
cscope.po.out
tags
```

## 9. 更新索引

源码发生较大变化后，在源码根目录重新执行：

```bash
./build-tags.sh
```

脚本会重新生成文件列表，并覆盖旧的 Cscope 和 Ctags 索引。

## 10. 推荐工作流程

```text
进入源码根目录
        |
        v
运行 build-tags.sh
        |
        v
生成 cscope.files
        |
        +----> Cscope：函数调用和符号引用查询
        |
        +----> Ctags：快速跳转到符号定义
        |
        v
从源码根目录启动 Vim
```

对于 Linux 内核、glibc、Binutils 等大型源码工程，采用统一文件列表的方式可以保证 Cscope 与 Ctags 索引范围一致，同时排除 `.git`、构建目录和生成文件，便于重复构建和维护。

