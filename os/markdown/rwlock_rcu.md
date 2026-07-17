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

RCU is the mechanism that ensuring reads are coherent by maintaining multiple vserions of object and ensuring that they are not freed up untill all pre-existing read-side critical sections complete.  


RCU is made up of three fundamental mechanisms:  
1. publish-subscribe
2. wait for pre-readers to complete
3. multiple versions of recently updated objects

### publish-subscribe

#### rcu_assign_pointer -- publish 

Think about the code fragment:  

``` c
  1 struct foo {
  2   int a;
  3   int b;
  4   int c;
  5 };
  6 struct foo *gp = NULL;
  7 
  8 /* . . . */
  9 
 10 p = kmalloc(sizeof(*p), GFP_KERNEL);
/** 
    * nothing forcing the compiler and CPU
    * to execute the four assignment statement in order
    * which may cause a comcurrent reader see pointer p
    * before asisgnment of the value of the struct is completed
    * which could see the uninitialized values
* */
 11 p->a = 1;
 12 p->b = 2;
 13 p->c = 3;
 14 gp = p;
```

so the line-14 should be replaced with:  

```c

rcu_assign_pointer(gp, p)

```
The **rcu_assign_pointer** is encapsulated to realize a **memory barriers** semantics, which forcing both the compiler and the cpu to execute the assignment to gp after the assignments to the fields referenced by p.*(publish)*

#### rcu_dereference -- subscribe

Without additional memory-barrier instructions, the code:  

``` c

  1 p = gp;
  2 if (p != NULL) {
  /**
    * compiler optimization may cause the values of 
    *  p->a, p->b, and p->c to be fetched before 
    *  the value of p is assigned correctly.
    **/
  3   do_something_with(p->a, p->b, p->c);
  4 }

```
will be effected by compiler optimizations, which will guess the value of p, the featch p->a and so on.  
The **rcu_dereference()** primitive can thus be thought of as subscribing to a given value of the specified pointer, guaranteeing that subsequent dereference operations will see any initialization that occurred before the corresponding publish (rcu_assign_pointer()) operation.  

so the correct code will be like:

```c

  1 rcu_read_lock();
  2 p = rcu_dereference(gp);
  3 if (p != NULL) {
  4   do_something_with(p->a, p->b, p->c);
  5 }
  6 rcu_read_unlock();
```
#### rcu_read_lock and rcu_read_unlock
Just define the extent of the RCU read-side critical section.  

#### higher-level interface for list_head -- list_add_rcu(publish) and list_for_each_entry_rcu(subscribe)

Code fragment:  
```c
    /* list_add_rcu */
  1 struct foo {
  2   struct list_head list;
  3   int a;
  4   int b;
  5   int c;
  6 };
  7 LIST_HEAD(head);
  8 
  9 /* . . . */
 10 
 11 p = kmalloc(sizeof(*p), GFP_KERNEL);
 12 p->a = 1;
 13 p->b = 2;
 14 p->c = 3;
 15 list_add_rcu(&p->list, &head);

 /* list_for_each_entry_rcu */
  1 rcu_read_lock();
  2 list_for_each_entry_rcu(p, head, list) {
  3   do_something_with(p->a, p->b, p->c);
  4 }
  5 rcu_read_unlock();
```
The list_add_rcu() primitive publishes an entry into the specified list, guaranteeing that the corresponding list_for_each_entry_rcu() invocation will properly subscribe to this same entry.

### wait for pre-reader to exit 
![grace_priod](https://static.lwn.net/images/ns/kernel/rcu/GracePeriodGood.png)

The following pseudocode shows the basic form of algorithms that use RCU to wait for readers:

Make a change, for example, replace an element in a linked list.

Wait for all pre-existing RCU read-side critical sections to completely finish (for example, by using the synchronize_rcu() primitive). The key observation here is that subsequent RCU read-side critical sections have no way to gain a reference to the newly removed element.

Clean up, for example, free the element that was replaced above.

Code fragment:  
``` c

  1 struct foo {
  2   struct list_head list;
  3   int a;
  4   int b;
  5   int c;
  6 };
  7 LIST_HEAD(head);
  8
  9 /* . . . */
 10
 11 p = search(head, key);
 12 if (p == NULL) {
 13   /* Take appropriate action, unlock, and return. */
 14 }
 15 q = kmalloc(sizeof(*p), GFP_KERNEL);
 16 *q = *p;
 17 q->b = 2;
 18 q->c = 3;
 19 list_replace_rcu(&p->list, &q->list);
 20 synchronize_rcu(); /* grace period start */
 21 kfree(p);
 ```
 RCU Classic's synchronize_rcu() can conceptually be as simple as the following:
```c 
  1 for_each_online_cpu(cpu)
  2   run_on(cpu);
  ```
RCU classic sections delimited by *rcu_read_lock* and *rcu_read_unlock* are not permitted to block or sleep.so:  

when a given CPU executes a context switch, we are guaranteed that any prior RCU read-side critical sections will have completed.   

Attention:  
Does works on realtime kernels.See realtime-rcu.  

### maintain multiple versions of recently updated objects

#### during deletion

concurrent readers might or might not see the newly removed element, depending on timing.  
But, readers are not permitted to maintain references to the old object after exiting from their RCU read-side critical sections.After that old object can be freed.

#### during replacement 

Same as deletion.The old period will be freed when grace period ends.During that, readers may see old object.  

command: : On all systems running Linux, loads from and stores to pointers are atomic.  

## references
[RCU Publication](https://docs.google.com/document/d/1X0lThx8OK0ZgLMqVoXiR4ZrGURHrXK6NyLRbeXe3Xac/edit?pli=1&tab=t.0)  
[Reader-Writer-Locking/RCU Analogy ](https://www.usenix.org/legacy/publications/library/proceedings/usenix03/tech/freenix03/full_papers/arcangeli/arcangeli_html/node7.html)  
[what's rcu--usage](https://lwn.net/Articles/263130/#RCU%20is%20a%20Reader-Writer%20Lock%20Replacement)  
[The design of preemptible read-copy-update](https://lwn.net/Articles/253651/)  
[relock and rwsem](https://kernel-internals.org/locking/rwlock-rwsem/)
[what is Rcu, fundamentally?](https://lwn.net/Articles/262464/)
[realtimem RCU](https://lwn.net/Articles/253651/)
## expands

- sleepable RCU 
- preemptible RCU
