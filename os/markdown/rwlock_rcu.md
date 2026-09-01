# Read-Writer Lock 与 RCU

Rwlock 和 RCU 是 Linux 内核提供的两种完全不同的同步机制。
**RCU** 不是简单的"更快的 rwlock"，而是与 rwlock 不同的同步思路：rwlock 的读者和写者在某些场景下会相互阻塞；相比之下，RCU 的读者永远不会被阻塞，但在 **grace period** 内可能读到旧数据。

## Reader-Writer Lock / RCU 对照

| Reader-Writer Lock | Read-Copy Update |
|--------------------|------------------|
| `rwlock_t` | `spinlock_t` |
| `read_lock()` | `rcu_read_lock()` \* |
| `read_unlock()` | `rcu_read_unlock()` \* |
| `write_lock()` | `spin_lock()` |
| `write_unlock()` | `spin_unlock()` |
| `list_add()` | `list_add_rcu()` |
| `list_add_tail()` | `list_add_tail_rcu()` |
| `list_del()` | `list_del_rcu()` |
| `list_for_each()` | `list_for_each_rcu()` |

\* `rcu_read_lock()` 和 `rcu_read_unlock()` 在未开启 `CONFIG_PREEMPT` 时是空操作；开启抢占后，它们用于抑制抢占。

## RWLOCK

**Reader-writer locking —— 并发读、互斥写。**

两种变体：

1. `rwlock_t` —— 自旋变体
2. `rw_semaphore` —— 睡眠变体

### rwlock_t

读者/写者在等待数据时自旋。接口如下：

```c
/* Read side */
read_lock(&my_rwlock);
/* read critical section — 与其他读者并发 */
read_unlock(&my_rwlock);

/* Write side */
write_lock(&my_rwlock);
/* write critical section — 互斥 */
write_unlock(&my_rwlock);
```

### rw_semaphore

`rw_semaphore` 是 `rwlock_t` 的睡眠版本。竞争的等待者会睡眠而非自旋（与 mutex 类似，睡前有一段乐观自旋阶段）。

```c
/* include/linux/rwsem.h */
struct rw_semaphore {
	atomic_long_t count;	/* reader count + RWSEM_WRITER_LOCKED bit */
	atomic_long_t owner;	/* writer task_struct* */
	struct osq_lock osq;	/* optimistic spinners */
	raw_spinlock_t wait_lock;
	struct list_head wait_list;
};
```

使用示例：

```c
#include <linux/rwsem.h>

/* Initialization */
DECLARE_RWSEM(my_rwsem);	/* static */
struct rw_semaphore my_rwsem;
init_rwsem(&my_rwsem);		/* dynamic */

/* Read side */
down_read(&my_rwsem);		/* may sleep */
/* read critical section */
up_read(&my_rwsem);

/* Interruptible read lock */
if (down_read_interruptible(&my_rwsem))
	return -ERESTARTSYS;
up_read(&my_rwsem);

/* Trylock (non-blocking) */
if (down_read_trylock(&my_rwsem)) {
	/* got it */
	up_read(&my_rwsem);
}

/* Write side */
down_write(&my_rwsem);		/* may sleep, exclusive */
/* write critical section */
up_write(&my_rwsem);

/*
 * 将写锁原子地降级为读锁（不释放）。
 * 用于写处理完成后需要转为读者、同时放行其他读者的场景。
 */
downgrade_write(&my_rwsem);	/* demote exclusive → shared */
/* now in read-side critical section */
up_read(&my_rwsem);
```

### rwlock_irqsave 变体

TODO: 待补充。

### writer starvation 问题

Linux 保证在等待中的写者之后到达的读者必须排队，以防止"写者饿死"。

## RCU

RCU 通过维护对象的多个版本，并确保在所有已存在的读侧临界区完成之前不释放旧版本，来保证读取的一致性。

RCU 由三个基本机制组成：

1. publish-subscribe（发布-订阅）
2. 等待已有读者完成
3. 维护最近更新对象的多个版本

### publish-subscribe

#### rcu_assign_pointer —— publish

考虑如下代码片段：

```c
struct foo {
	int a;
	int b;
	int c;
};
struct foo *gp = NULL;

/* ... */

p = kmalloc(sizeof(*p), GFP_KERNEL);
p->a = 1;
p->b = 2;
p->c = 3;
gp = p;
```

没有任何机制强制编译器和 CPU 按顺序执行四条赋值语句，并发读者可能在字段赋值完成前就看到指针 `gp`，从而读到未初始化的值。

因此最后一行应替换为：

```c
rcu_assign_pointer(gp, p);
```

`rcu_assign_pointer()` 封装了**内存屏障**语义，强制编译器和 CPU 在完成 `p` 所指字段的赋值之后，才执行对 `gp` 的赋值（publish）。

#### rcu_dereference —— subscribe

没有额外的内存屏障指令时，如下代码：

```c
p = gp;
if (p != NULL) {
	do_something_with(p->a, p->b, p->c);
}
```

会受编译器优化影响：编译器可能猜测 `p` 的值，提前 fetch `p->a` 等字段。

`rcu_dereference()` 原语可以看作订阅指定指针的值，保证后续的解引用能看到对应 publish（`rcu_assign_pointer()`）之前的所有初始化。

正确的代码如下：

```c
rcu_read_lock();
p = rcu_dereference(gp);
if (p != NULL) {
	do_something_with(p->a, p->b, p->c);
}
rcu_read_unlock();
```

#### rcu_read_lock / rcu_read_unlock

仅用于界定 RCU 读侧临界区的范围。

#### list_head 的高层接口 —— list_add_rcu（publish）与 list_for_each_entry_rcu（subscribe）

```c
/* list_add_rcu */
struct foo {
	struct list_head list;
	int a;
	int b;
	int c;
};
LIST_HEAD(head);

/* ... */

p = kmalloc(sizeof(*p), GFP_KERNEL);
p->a = 1;
p->b = 2;
p->c = 3;
list_add_rcu(&p->list, &head);

/* list_for_each_entry_rcu */
rcu_read_lock();
list_for_each_entry_rcu(p, head, list) {
	do_something_with(p->a, p->b, p->c);
}
rcu_read_unlock();
```

`list_add_rcu()` 向链表发布一个元素，保证对应的 `list_for_each_entry_rcu()` 能正确订阅到同一元素。

### 等待已有读者退出

![grace_period](https://static.lwn.net/images/ns/kernel/rcu/GracePeriodGood.png)

使用 RCU 等待读者的算法基本形式：

1. 做出变更，例如替换链表中的一个元素；
2. 等待所有已存在的 RCU 读侧临界区完成（例如使用 `synchronize_rcu()`）。关键在于：之后开始的读侧临界区已无法获得对被移除元素的引用；
3. 清理，例如释放被替换的元素。

代码片段：

```c
struct foo {
	struct list_head list;
	int a;
	int b;
	int c;
};
LIST_HEAD(head);

/* ... */

p = search(head, key);
if (p == NULL) {
	/* Take appropriate action, unlock, and return. */
}
q = kmalloc(sizeof(*p), GFP_KERNEL);
*q = *p;
q->b = 2;
q->c = 3;
list_replace_rcu(&p->list, &q->list);
synchronize_rcu();	/* grace period start */
kfree(p);
```

RCU Classic 的 `synchronize_rcu()` 概念上可以简单实现为：

```c
for_each_online_cpu(cpu)
	run_on(cpu);
```

由 `rcu_read_lock` 和 `rcu_read_unlock` 界定的 RCU Classic 临界区不允许阻塞或睡眠，因此：

当给定 CPU 执行上下文切换时，可以保证该 CPU 之前的 RCU 读侧临界区已全部完成。

注意：实时内核上的行为不同，参见 realtime RCU。

### 维护最近更新对象的多个版本

#### 删除时

并发读者可能看到、也可能看不到新移除的元素，取决于时序。
但读者在退出 RCU 读侧临界区后，不允许继续持有对旧对象的引用。此后旧对象即可释放。

#### 替换时

与删除相同。旧对象在 grace period 结束后释放，期间读者可能看到旧对象。

注：在所有运行 Linux 的系统上，指针的 load 和 store 都是原子的。

## TODO

- sleepable RCU
- preemptible RCU

## References

- [RCU Publication](https://docs.google.com/document/d/1X0lThx8OK0ZgLMqVoXiR4ZrGURHrXK6NyLRbeXe3Xac/edit?pli=1&tab=t.0)
- [Reader-Writer Locking/RCU Analogy](https://www.usenix.org/legacy/publications/library/proceedings/usenix03/tech/freenix03/full_papers/arcangeli/arcangeli_html/node7.html)
- [What is RCU, fundamentally?](https://lwn.net/Articles/262464/)
- [What is RCU? On the usage](https://lwn.net/Articles/263130/)
- [The design of preemptible read-copy-update](https://lwn.net/Articles/253651/)
- [rwlock and rwsem](https://kernel-internals.org/locking/rwlock-rwsem/)
