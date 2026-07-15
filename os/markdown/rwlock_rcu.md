# RWLOCK AND READ-COPY-UPDATE

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


