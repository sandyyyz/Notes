# Heterogeneous Memory Management

HMM is a set of helpers to facilitate several aspects of address space
sharing and device memory management.  
Unlike existing sharing mechanism
that rely on pining pages use by a device, HMM relies on mmu_notifier to
propagate CPU page table update to device page table.  

Design purpose:  
1. Avoiding pinning pages device need to access in host-memory.
2. Allow to migrate range of memory to the device to take advantage of its lower latency and higer bandwidth.
3. Share virtual address space between device and cpu (by copy cpu-pgtble to device's mmu or sign a device memory page in host mem-table, so the device need is supposed to have its own mmu witha page table per process it wants to mirror)
4. provide a common API that can be used by any such devices in order to mirror process address.

## patches

### v1

1. differentiate unmap for vmscan for other unmap.
2. Add action information to address invalidation(mmu_action, maybe removed in the future? it said: *The action information will be usefull for new user of mmu_notifier API.*)
3. mmu_notifier: pass through vma to invalidate_range and invalidate_page. redoing a vma lookup inside the callback -> pass through the vma hwere it is already available.
4. interval_tree: helper to find previous item of a node in rb interval tree.
5. mm/memcg: support accounting null page and
 transfering null charge to new page(null page -- page tansferred from memory to device memory.)
6. hmm: heterogeneous memory management.
7. hmm: support moving anonymous page to remote memory.
8. hmm: support for migrate file backed pages to remote memory.
9. fs/ext4: add support for hmm migration to remote
 memory of pagecache.
10. hmm/dummy: dummy driver to showcase the hmm api.
11. hmm/dummy_driver: add support for fake remote memory
 using pages.

### v25


## refs

[lwn_hmm_v25](https://lwn.net/Articles/731259/)
