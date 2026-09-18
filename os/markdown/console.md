# console

```c
/**
 * struct console - The console descriptor structure
 * @name:		The name of the console driver
 * @write:		Write callback to output messages (Optional)
 * @read:		Read callback for console input (Optional)
 * @device:		The underlying TTY device driver (Optional)
 * @unblank:		Callback to unblank the console (Optional)
 * @setup:		Callback for initializing the console (Optional)
 * @exit:		Callback for teardown of the console (Optional)
 * @match:		Callback for matching a console (Optional)
 * @flags:		Console flags. See enum cons_flags
 * @index:		Console index, e.g. port number
 * @cflag:		TTY control mode flags
 * @ispeed:		TTY input speed
 * @ospeed:		TTY output speed
 * @seq:		Sequence number of the next ringbuffer record to print
 * @dropped:		Number of unreported dropped ringbuffer records
 * @data:		Driver private data
 * @node:		hlist node for the console list
 *
 * @write_atomic:	Write callback for atomic context
 * @write_thread:	Write callback for non-atomic context
 * @driver_enter:	Callback to begin synchronization with driver code
 * @driver_exit:	Callback to finish synchronization with driver code
 * @nbcon_state:	State for nbcon consoles
 * @nbcon_seq:		Sequence number of the next record for nbcon to print
 * @pbufs:		Pointer to nbcon private buffer
 * @kthread:		Printer kthread for this console
 * @rcuwait:		RCU-safe wait object for @kthread waking
 * @irq_work:		Defer @kthread waking to IRQ work context
 */
struct console {
	char			name[16];
	void			(*write)(struct console *co, const char *s, unsigned int count);
	int			(*read)(struct console *co, char *s, unsigned int count);
	struct tty_driver	*(*device)(struct console *co, int *index);
	void			(*unblank)(void);
	int			(*setup)(struct console *co, char *options);
	int			(*exit)(struct console *co);
	int			(*match)(struct console *co, char *name, int idx, char *options);
	short			flags;
	short			index;
	int			cflag;
	uint			ispeed;
	uint			ospeed;
	u64			seq;
	unsigned long		dropped;
	void			*data;
	struct hlist_node	node;

	/* nbcon console specific members */
	bool			(*write_atomic)(struct console *con,
						struct nbcon_write_context *wctxt);
	bool			(*write_thread)(struct console *con,
						struct nbcon_write_context *wctxt);
	void			(*driver_enter)(struct console *con, unsigned long *flags);
	void			(*driver_exit)(struct console *con, unsigned long flags);
	atomic_t		__private nbcon_state;
	atomic_long_t		__private nbcon_seq;
	struct printk_buffers	*pbufs;
	struct task_struct	*kthread;
	struct rcuwait		rcuwait;
	struct irq_work		irq_work;
};

```

## cons_flags

```c

/*
 * The interface for a console, or any other device that wants to capture
 * console messages (printer driver?)
 */

/**
 * cons_flags - General console flags
 * @CON_PRINTBUFFER:	Used by newly registered consoles to avoid duplicate
 *			output of messages that were already shown by boot
 *			consoles or read by userspace via syslog() syscall.
 * @CON_CONSDEV:	Indicates that the console driver is backing
 *			/dev/console.
 * @CON_ENABLED:	Indicates if a console is allowed to print records. If
 *			false, the console also will not advance to later
 *			records.
 * @CON_BOOT:		Marks the console driver as early console driver which
 *			is used during boot before the real driver becomes
 *			available. It will be automatically unregistered
 *			when the real console driver is registered unless
 *			"keep_bootcon" parameter is used.
 * @CON_ANYTIME:	A misnomed historical flag which tells the core code
 *			that the legacy @console::write callback can be invoked
 *			on a CPU which is marked OFFLINE. That is misleading as
 *			it suggests that there is no contextual limit for
 *			invoking the callback. The original motivation was
 *			readiness of the per-CPU areas.
 * @CON_BRL:		Indicates a braille device which is exempt from
 *			receiving the printk spam for obvious reasons.
 * @CON_EXTENDED:	The console supports the extended output format of
 *			/dev/kmesg which requires a larger output buffer.
 * @CON_SUSPENDED:	Indicates if a console is suspended. If true, the
 *			printing callbacks must not be called.
 * @CON_NBCON:		Console can operate outside of the legacy style console_lock
 *			constraints.
 */
enum cons_flags {
	CON_PRINTBUFFER		= BIT(0),
	CON_CONSDEV		= BIT(1),
	CON_ENABLED		= BIT(2),
	CON_BOOT		= BIT(3),
	CON_ANYTIME		= BIT(4),
	CON_BRL			= BIT(5),
	CON_EXTENDED		= BIT(6),
	CON_SUSPENDED		= BIT(7),
	CON_NBCON		= BIT(8),
};

```

## `register_console(struct console *newconsole)`

