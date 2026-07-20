# linux 中的同步机制

若多个内核路径同时访问和操作同一个数据，可能导致数据之间相互覆盖，从而导致数据不一致，这需要在内核中极力避免。值得一提的是，并发访问的情况不只是仅仅发生在多处理器的环境下。单核环境下虽然同一时刻只能执行一个线程，但由于线程调度、中断抢占等机制，共享数据的读改写操作可能被分割并交错执行，因此仍然会产生并发访问问题。这种由执行时序不可预测导致的数据竞争称为竞态条件，其本质与多核环境中的并发问题相同。如下图：  

        Thread A                  Thread B
            │                         │
            │ read counter = 0        │
            │──────────────┐          │
            │              │          │
            │<---被抢占----│          │
            │              │          │
            │              │ read counter = 0
            │              │ counter = 1
            │              │ write 1
            │              │
            │<--恢复运行---│
            │ counter = 1
            │ write 1
            │
            ▼

      最终 counter = 1


## 原子变量与操作

Linux内核而提供了原子变量，其实现依赖于不同的体系结构

```c
/* atomic_t */
typedef struct {
	int __aligned(sizeof(int)) counter;
} atomic_t;


/**
 * atomic_inc() - atomic increment with relaxed ordering
 * @v: pointer to atomic_t
 *
 * Atomically updates @v to (@v + 1) with relaxed ordering.
 *
 * Unsafe to use in noinstr code; use raw_atomic_inc() there.
 *
 * Return: Nothing.
 */
static __always_inline void
atomic_inc(atomic_t *v)
{
	instrument_atomic_read_write(v, sizeof(*v));
	raw_atomic_inc(v);
}
```
## 内存屏障

现代计算机结构中，为了提高性能，CPU都引入了乱序执行技术。然而，CPU 只知道数据依赖，不知道程序员定义的同步关系，因此硬件允许的合法重排序未必符合并发逻辑所要求的执行顺序。即，乱序执行只保证单线程语义正确，不保证多线程观察结果正确。除此以外，编译器也可能重排指令以提高性能。

```c

/* include/linux/compiler.h
/* Optimization barrier */
#ifndef barrier
/* The "volatile" is due to gcc bugs */
# define barrier() __asm__ __volatile__("": : :"memory")
#endif

/*linux/arch/x86/incllude/asm/barrier.h*/
/* 64bits - 单处理器 */
#define __mb()	asm volatile("mfence":::"memory")
#define __rmb()	asm volatile("lfence":::"memory")
#define __wmb()	asm volatile("sfence" ::: "memory")
/* 多核 */
#define __smp_mb()	asm volatile("lock addl $0,-4(%%" _ASM_SP ")" ::: "memory", "cc")

#define __smp_rmb()	dma_rmb()
#define __smp_wmb()	barrier()
#define __smp_store_mb(var, value) do { (void)xchg(&var, value); } while (0)
```

## 锁机制

### spinlock

```c

/* spinlock -> raw_spinlock -> arch_spinlock -> qspinlock */
/* include/asm-generic/qspinlock_types.h */ 
typedef struct qspinlock {
	union {
		atomic_t val;

		/*
		 * By using the whole 2nd least significant byte for the
		 * pending bit, we can allow better optimization of the lock
		 * acquisition for the pending bit holder.
		 */
#ifdef __LITTLE_ENDIAN
		struct {
			u8	locked;
			u8	pending;
		};
		struct {
			u16	locked_pending;
			u16	tail;
		};
#else
		struct {
			u16	tail;
			u16	locked_pending;
		};
		struct {
			u8	reserved[2];
			u8	pending;
			u8	locked;
		};
#endif
	};
} arch_spinlock_t;
```
