# early_prink

> **Early printk（早期内核打印）**是 Linux 内核在常规 console 驱动和完整设备子系统尚未初始化时，用于提前输出 printk() 日志的临时调试机制，主要作用是捕获内核启动最早阶段的初始化信息和崩溃现场，解决“内核已经出错但普通控制台尚不可用”的问题；它要求内核启用对应的早期输出后端、启动参数指定输出方式，并具备相应硬件条件，例如文档中的 CONFIG_EARLY_PRINTK_DBGP=y、earlyprintk=dbgp、支持 EHCI Debug Port 的目标机、专用 USB Debug Key、正确的物理 USB 端口及接收端设备；实现上，内核在启动早期根据命令行参数初始化并注册一个简化的 early console，使 printk() 产生的字符绕过尚未就绪的常规控制台和完整 USB 驱动栈，直接操作 EHCI Debug Port 寄存器，经 USB 物理链路发送到另一台机器的 /dev/ttyUSBx，待常规 console 初始化后默认停用，也可通过 earlyprintk=dbgp,keep 保留。

```
内核命令行：
earlyprintk=dbgp,keep
        |
        v
early_param("earlyprintk", setup_early_printk)
        |
        v
setup_early_printk()
        |
        +-- 识别 dbgp
        |
        +-- early_dbgp_init()
        |
        v
early_console_register()
        |
        v
register_console(&early_dbgp_console)


Bootloader 提供内核命令行
earlyprintk=serial,ttyS0,115200,keep
                    │
                    ▼
boot_command_line
                    │
                    ▼
start_kernel()
  └─ parse_early_param()
      └─ parse_early_options()
          └─ parse_args()
              ├─ param = "earlyprintk"
              └─ val   = "serial,ttyS0,115200,keep"
                         │
                         ▼
                  do_early_param()
                         │
                         ▼
                  p->setup_func(val)
                         │
                         ▼
setup_early_printk("serial,ttyS0,115200,keep")

```

## `static __init void setup_early_prink(char *s)`

`setup_early_printk(char *buf)` 的 `buf` 来自 `bootloader` 传给 `Linux` 内核的启动命令行中，`earlyprintk`= 等号后面的值。例如启动参数为 `earlyprintk=serial,ttyS0,115200,keep` 时，内核在 `start_kernel()` 阶段调用 `parse_early_param()` 解析整个 `boot_command_line`，`parse_args()` 将该参数拆分为 `param="earlyprintk"` 和 `val="serial,ttyS0,115200,keep"`, 随后 `do_early_param()` 在 `.init.setup` 段中找到由 `early_param("earlyprintk", setup_early_printk)` 注册的描述项，并通过 `p->setup_func(val)` 调用该函数，因此最终相当于执行 `setup_early_printk("serial,ttyS0,115200,keep")`

各个字段的含义： 

```
serial     选择早期串口输出后端
ttyS0      使用第一个传统串口，默认 I/O 基地址为 0x3f8
115200     配置 UART 波特率为 115200
keep       正式 console 注册后仍保留 early console
```

该函数将解析内核启动命令行中传入的参数，初始化对应硬件，并且注册`console`

### `static __init void early_serial_init(char *s)`

该函数识别到`serial`，将后续字符串作为参数，初始化串口(port、baud、HW)  

1. 解析`baud`->计算`divisor`, `divisor = 115200 / baud` 
2. `serial_in/out`=`io_serial_in/out`
3. `early_serial_hw_init(divisor)`

#### `early_serial_hw_init(divisor)`

该函数完成：
1. 设置每次传输的字符为8bit
2. disable FIFO,包括receiver fifo 和 transmitter fifo
3. 设置MCR=0X3，表示准备好发送和接收数据
4. 根据待设置的baud,将divisor latches寄存器设置成divisor

### `static early_console_register`

1. 首先根据`keep`决定是否set/unset con->flags `CON_BOOT`
2. `register_console(early_console)`

```c

static struct console early_serial_console = {
	.name =		"earlyser",
	.write =	early_serial_write,
	.flags =	CON_PRINTBUFFER,
	.index =	-1,
};

```

### static void early_serial_write(struct console *con, const char *s, unsigned n)

以字符为单位，通过`early_serial_putc`将字符串s中的n个字符输出

#### static int early_serial_putc(unsigned char ch)

1. `timeout`期间轮询`LCR[5]`,检查UART是否准备好 `accept a new character for transmission`
2. 调用`io_serial_out`将需要输出的字符传递给uart

#### `io_serial_out`

该函数底层将调用：  
```c
#if !defined(outb) && !defined(_outb)
#define _outb _outb
static inline void _outb(u8 value, unsigned long addr)
{
	__io_pbw();
	__raw_writeb(value, PCI_IOBASE + addr);
	__io_paw();
}
#endif
```

传统 x86 ttyS0/ttyS1 的 8250/16550 UART 寄存器位于 I/O Port 地址空间，例如 ttyS0 基地址通常为 0x3f8，因此可以通过 inb/outb 实现的 io_serial_in/out 读写寄存器。  
