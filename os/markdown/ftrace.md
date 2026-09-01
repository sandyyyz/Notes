# ftrace

事实上，`ftrace` 是一系列相关 tracing utilities 的统称。可以在 `/sys/kernel/tracing` 或 `/sys/kernel/debug/tracing` 目录下找到。

## test_hmm at Red Hat Enterprise Linux 9.7

Kernel: 5.14.0-611.5.1.el9_7.x86_64  

检查内核是否已经构建 HMM 测试模块：

```sh
KREL=$(uname -r)

echo "Kernel: $KREL"

grep -E 'CONFIG_(TEST_HMM|HMM_MIRROR|DEVICE_PRIVATE|TRANSPARENT_HUGEPAGE)=' \
    /boot/config-"$KREL"

find /lib/modules/"$KREL" -name 'test_hmm.ko*'

modinfo test_hmm
```

输出：

```text
Kernel: 5.14.0-611.5.1.el9_7.x86_64
CONFIG_TRANSPARENT_HUGEPAGE=y
CONFIG_HMM_MIRROR=y
CONFIG_DEVICE_PRIVATE=y
CONFIG_TEST_HMM=m
modinfo: ERROR: Module test_hmm not found.
```

显示 `CONFIG_TEST_HMM=m`，但 `modinfo test_hmm` 失败，说明 RHEL 构建配置启用了该模块，但当前安装的内核包没有交付它。需要取得对应 RHEL 内核源码并单独构建模块。

安装下载工具：

```sh
dnf install dnf-plugins-core rpm-build rpmdevtools
```

```sh
[root@localhost ~]# rpm -q --qf '%{NAME}-%{VERSION}-%{RELEASE}.%{ARCH}\n' kernel-core
kernel-core-5.14.0-611.5.1.el9_7.x86_64
kernel-core-5.14.0-503.40.1.el9.x86_64
```

## References

- [ftrace — Linux Kernel Documentation](https://docs.kernel.org/trace/ftrace.html)
