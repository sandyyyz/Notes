# Linux 中的同步机制

若多个内核路径同时访问和操作同一个数据，可能导致数据之间相互覆盖，从而造成数据不一致，这需要在内核中极力避免。值得一提的是，并发访问不只是发生在多处理器环境下。单核环境下虽然同一时刻只能执行一个线程，但由于线程调度、中断抢占等机制，共享数据的读改写操作可能被分割并交错执行，因此仍然会产生并发访问问题。这种由执行时序不可预测导致的数据竞争称为竞态条件，其本质与多核环境中的并发问题相同。如下图：

```text
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
```

## 机制速览

| 机制 | 典型用途 | 关键约束 |
| --- | --- | --- |
| 原子操作 | 简单计数、位操作、无锁状态更新 | 只能表达有限的单变量操作；内存序需要额外关注 |
| 内存屏障 | 约束 CPU/编译器重排序 | 不提供互斥，只提供可见性与顺序保证 |
| spinlock | 短临界区、不能睡眠的上下文 | 持锁期间不能睡眠；竞争时自旋消耗 CPU |
| mutex / semaphore | 可睡眠上下文中的互斥 | 不能在中断上下文使用 |
| rwlock / rwsem | 读多写少场景 | 读写语义不同，写者公平性与延迟需评估 |
| RCU | 读路径极多、读侧低开销 | 更新和回收路径复杂，需要 grace period |

## 原子变量与操作

Linux 内核提供了原子变量，其实现依赖于不同的体系结构：

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

现代计算机结构中，为了提高性能，CPU 都引入了乱序执行技术。然而，CPU 只知道数据依赖，不知道程序员定义的同步关系，因此硬件允许的合法重排序未必符合并发逻辑所要求的执行顺序。即，乱序执行只保证单线程语义正确，不保证多线程观察结果正确。除此以外，编译器也可能重排指令以提高性能。

```c
/* include/linux/compiler.h */
/* Optimization barrier */
#ifndef barrier
/* The "volatile" is due to gcc bugs */
# define barrier() __asm__ __volatile__("": : :"memory")
#endif

/* arch/x86/include/asm/barrier.h */
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

选择锁时首先确认上下文是否允许睡眠，其次再考虑临界区长短和读写比例。不能睡眠的路径通常选择 spinlock 或原子操作；可能阻塞的长临界区应使用 mutex/rwsem 等睡眠锁。

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
