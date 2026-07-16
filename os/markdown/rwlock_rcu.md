# RWLOCK AND READ-COPY-UPDATE

Rwlock and RCU are two completely different synchronization mechanisms provided by linux kernel.  
**RCU** is not a simple **faster rwlock**, in fact, it's a different syncronize approach to rwlock, which reader and writer will block each other in some scenarios.In contrast to this, RCU's readers will never be blocked.However, readers might encounter outdated data in **grace period**.

## Table 1: Reader-Writer Lock / RCU Substitutions

| Reader-Writer Lock | Read-Copy Update |
|--------------------|------------------|
| `rwlock_t` | `spinlock_t` |
| `read_lock()` | `rcu_read_lock()` **\*** |
| `read_unlock()` | `rcu_read_unlock()` **\*** |
| `write_lock()` | `spin_lock()` |
| `write_unlock()` | `spin_unlock()` |
| `list_add()` | `list_add_rcu()` |
| `list_add_tail()` | `list_add_tail_rcu()` |
| `list_del()` | `list_del_rcu()` |
| `list_for_each()` | `list_for_each_rcu()` |

**\*** `rcu_read_lock()` and `rcu_read_unlock()` are no-ops unless `CONFIG_PREEMPT` is enabled. When preemption is enabled, they suppress preemption.

## RWLOCK

**Reader-writer locking - concurrent reads, exclusivie writes.**  

two varient:
1. rwlock_t -- spinning variant 
2. rw_semaphore -- sleeping variant

### rw_lock_t

Reader/writer stand spinning while waiting for the data. Interfaces looks like:

``` c

/* Read side */
read_lock(&my_rwlock);
/* read critical section — concurrent with other readers */
read_unlock(&my_rwlock);

/* Write side */
write_lock(&my_rwlock);
/* write critical section — exclusive */
write_unlock(&my_rwlock);

```

### rw_semaphpre 

rw_semaphore is the sleeping counterpart to rwlock_t. Contended waiters go to sleep rather than spinning (after a brief optimistic spin phase, like mutex).

``` c

/* include/linux/rwsem.h */
struct rw_semaphore {
    atomic_long_t count;   /* reader count + RWSEM_WRITER_LOCKED bit */
    atomic_long_t owner;   /* writer task_struct* */
    struct osq_lock osq;   /* optimistic spinners */
    raw_spinlock_t wait_lock;
    struct list_head wait_list;
};

```

example:(To be supplemented)
Need to be supplemented at source code level. 
``` c 

#include <linux/rwsem.h>

/* Initialization */
DECLARE_RWSEM(my_rwsem);       /* static */
struct rw_semaphore my_rwsem;
init_rwsem(&my_rwsem);         /* dynamic */

/* Read side */
down_read(&my_rwsem);          /* may sleep */
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
down_write(&my_rwsem);         /* may sleep, exclusive */
/* write critical section */
up_write(&my_rwsem);

/* Downgrade from write to read (without releasing) */
/**
    * atomically converts a write lock to a read lock.
    * used when write process finished, and need to change to 
    * reader, while let other reader in
**/
downgrade_write(&my_rwsem);    /* demote exclusive → shared */
/* now in read-side critical section */
up_read(&my_rwsem);
```
### rwlock_irqsave variant
(To be suplemented)

### writer starvation problem 

Linux make sure readers arrived after the waiting writer need to be queued to prevent "writer starvation". 

## RCU

A sample code fragment that does an RCU read-to-update upgrade follows:
```c 
  1 rcu_read_lock();
  2 list_for_each_entry_rcu(p, head, list_field) {
  3   do_something_with(p);
  4   if (need_update(p)) {
  5     spin_lock(&my_lock);
  6     do_update(p);
  7     spin_unlock(&my_lock);
  8   }
  9 }
 10 rcu_read_unlock();

```

## reference
[RCU Publication](https://docs.google.com/document/d/1X0lThx8OK0ZgLMqVoXiR4ZrGURHrXK6NyLRbeXe3Xac/edit?pli=1&tab=t.0)  
[Reader-Writer-Locking/RCU Analogy ](https://www.usenix.org/legacy/publications/library/proceedings/usenix03/tech/freenix03/full_papers/arcangeli/arcangeli_html/node7.html)  
[what's rcu--usage](https://lwn.net/Articles/263130/#RCU%20is%20a%20Reader-Writer%20Lock%20Replacement)  
[The design of preemptible read-copy-update](https://lwn.net/Articles/253651/)  
[relock and rwsem](https://kernel-internals.org/locking/rwlock-rwsem/)
[what is Rcu, fundamentally?](https://lwn.net/Articles/262464/)
