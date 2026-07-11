# RWLOCK AND READ-COPY-UPDATE

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
[what's rcu--usage](https://lwn.net/Articles/263130/#RCU%20is%20a%20Reader-Writer%20Lock%20Replacement)
[The design of preemptible read-copy-update](https://lwn.net/Articles/253651/)


