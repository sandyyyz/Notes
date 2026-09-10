# Heterogeneous Memory Management

HMM is a set of helpers to facilitate several aspects of address space
sharing and device memory management.
Unlike existing sharing mechanisms that rely on pinning pages used by a
device, HMM relies on mmu_notifier to propagate CPU page table updates to
the device page table.

Design purpose:

1. Avoid pinning pages a device needs to access in host memory.
2. Allow migrating ranges of memory to the device to take advantage of its lower latency and higher bandwidth.
3. Share the virtual address space between device and CPU (by copying the CPU page table to the device's MMU, or assigning a device memory page in the host mem-table; the device is thus supposed to have its own MMU with a page table per process it wants to mirror).
4. Provide a common API that can be used by any such device in order to mirror a process address space.

## patches

### v1

1. Differentiate unmap for vmscan from other unmap.
2. Add action information to address invalidation (mmu_action, maybe removed in the future? it said: *The action information will be useful for new users of mmu_notifier API.*)
3. mmu_notifier: pass through vma to invalidate_range and invalidate_page. Redoing a vma lookup inside the callback -> pass through the vma where it is already available.
4. interval_tree: helper to find previous item of a node in rb interval tree.
5. mm/memcg: support accounting null page and transferring null charge to new page (null page -- page transferred from memory to device memory).
6. hmm: heterogeneous memory management.
7. hmm: support moving anonymous page to remote memory.
8. hmm: support for migrating file backed pages to remote memory.
9. fs/ext4: add support for hmm migration to remote
   memory of pagecache.
10. hmm/dummy: dummy driver to showcase the hmm api.
11. hmm/dummy_driver: add support for fake remote memory
    using pages.

### v25

APIS:


#### int hmm_mirror_register(struct hmm_mirror *mirror, struct mm_struct *mm);

A device driver that wants to mirror a process address space must start with registration of an hmm_mirror struct.

```c
/*
 * hmm_mirror_register() - register a mirror against an mm
 *
 * @mirror: new mirror struct to register
 * @mm: mm to register against
 *
 * To start mirroring a process address space, the device driver must register
 * an HMM mirror struct.
 *
 * THE mm->mmap_sem MUST BE HELD IN WRITE MODE !
 */
int hmm_mirror_register(struct hmm_mirror *mirror, struct mm_struct *mm)
{
	/* Sanity check */
	if (!mm || !mirror || !mirror->ops)
		return -EINVAL;

	mirror->hmm = hmm_register(mm);
	if (!mirror->hmm)
		return -ENOMEM;

	down_write(&mirror->hmm->mirrors_sem);
	list_add(&mirror->list, &mirror->hmm->mirrors);
	up_write(&mirror->hmm->mirrors_sem);

	return 0;
}
EXPORT_SYMBOL(hmm_mirror_register);
```
主要是将mirror添加到对应hmm的mirrors链表中。  

#### hmm_mirror

```c
/*
 * struct hmm_mirror - mirror struct for a device driver
 *
 * @hmm: pointer to struct hmm (which is unique per mm_struct)
 * @ops: device driver callback for HMM mirror operations
 * @list: for list of mirrors of a given mm
 *
 * Each address space (mm_struct) being mirrored by a device must register one
 * instance of an hmm_mirror struct with HMM. HMM will track the list of all
 * mirrors for each mm_struct.
 */
struct hmm_mirror {
	struct hmm			*hmm;
	const struct hmm_mirror_ops	*ops;
	struct list_head		list;
};
```
这是hmm中per device的一个数据结构，而hmm是mm-unique的。hmm将通过mirrors链表追踪address space中所有设备注册的mirror.  

#### struct hmm

```c
/*
 * struct hmm - HMM per mm struct
 *
 * @mm: mm struct this HMM struct is bound to
 * @lock: lock protecting ranges list
 * @sequence: we track updates to the CPU page table with a sequence number
 * @ranges: list of range being snapshotted
 * @mirrors: list of mirrors for this mm
 * @mmu_notifier: mmu notifier to track updates to CPU page table
 * @mirrors_sem: read/write semaphore protecting the mirrors list
 */
struct hmm {
	struct mm_struct	*mm;
	spinlock_t		lock;
	atomic_t		sequence;
	struct list_head	ranges;
	struct list_head	mirrors;
	struct mmu_notifier	mmu_notifier;
	struct rw_semaphore	mirrors_sem;
};
```

每个hmm_ mirror将会被放入hmm->mirrors 这个链表中，每个mirror的区别在于hmm_mirror_ops,其中定义了该device该如何同步cpu和device pagetable.

#### hmm_mirror_ops

a set of callbacks that are used to propagate CPU page table updates.
当 host 端更新页表时（turn page read-only、fully unmap 等），device driver 必须调用对应的 callback 更新设备端页表，并且保证完成后再返回。

```c

/*
 * struct hmm_mirror_ops - HMM mirror device operations callback
 *
 * @update: callback to update range on a device
 */
struct hmm_mirror_ops {
	/* sync_cpu_device_pagetables() - synchronize page tables
	 *
	 * @mirror: pointer to struct hmm_mirror
	 * @update_type: type of update that occurred to the CPU page table
	 * @start: virtual start address of the range to update
	 * @end: virtual end address of the range to update
	 *
	 * This callback ultimately originates from mmu_notifiers when the CPU
	 * page table is updated. The device driver must update its page table
	 * in response to this callback. The update argument tells what action
	 * to perform.
	 *
	 * The device driver must not return from this callback until the device
	 * page tables are completely updated (TLBs flushed, etc); this is a
	 * synchronous call.
	 */
	void (*sync_cpu_device_pagetables)(struct hmm_mirror *mirror,
					   enum hmm_update_type update_type,
					   unsigned long start,
					   unsigned long end);
};
```

一个调用点：  
```c
static void hmm_invalidate_range(struct hmm *hmm,
				 enum hmm_update_type action,
				 unsigned long start,
				 unsigned long end)
{
	struct hmm_mirror *mirror;
	struct hmm_range *range;

	spin_lock(&hmm->lock);
	list_for_each_entry(range, &hmm->ranges, list) {
		unsigned long addr, idx, npages;

		if (end < range->start || start >= range->end)
			continue;

		range->valid = false;
		addr = max(start, range->start);
		idx = (addr - range->start) >> PAGE_SHIFT;
		npages = (min(range->end, end) - addr) >> PAGE_SHIFT;
		memset(&range->pfns[idx], 0, sizeof(*range->pfns) * npages);
	}
	spin_unlock(&hmm->lock);

	down_read(&hmm->mirrors_sem);
	list_for_each_entry(mirror, &hmm->mirrors, list)
		mirror->ops->sync_cpu_device_pagetables(mirror, action,
							start, end);
	up_read(&hmm->mirrors_sem);
}
```

该函数实际上先使 HMM 缓存的 PFN 映射失效，再通知所有设备镜像同步对应地址范围的页表。  
在调用点处广播所有mirror更新对应范围的页表，这部分由驱动自己管理。  

#### struct hmm_range

这里还提到了hmm中另一个关键的结构体，hmm_range.

```c
/*
 * struct hmm_range - track invalidation lock on virtual address range
 *
 * @list: all range lock are on a list
 * @start: range virtual start address (inclusive)
 * @end: range virtual end address (exclusive)
 * @pfns: array of pfns (big enough for the range)
 * @valid: pfns array did not change since it has been fill by an HMM function
 */
struct hmm_range {
	struct list_head	list;
	unsigned long		start;
	unsigned long		end;
	hmm_pfn_t		*pfns;
	bool			valid;
};
```
注释的表述有点令人误解，它的意思是跟踪指定虚拟地址范围上的页表失效事件。
Q: pfns 数组追踪 [start, end) 内所有 pfns？


#### int hmm_vma_get_pfns(struct vm_area_struct *vma, struct hmm_range *range, unsigned long start, unsigned long end, hmm_pfn_t *pfns);

snap shot CPU page table for a range of virtual addresses.

```c
/*
 * hmm_vma_get_pfns() - snapshot CPU page table for a range of virtual addresses
 * @vma: virtual memory area containing the virtual address range
 * @range: used to track snapshot validity
 * @start: range virtual start address (inclusive)
 * @end: range virtual end address (exclusive)
 * @entries: array of hmm_pfn_t: provided by the caller, filled in by function
 * Returns: -EINVAL if invalid argument, -ENOMEM out of memory, 0 success
 *
 * This snapshots the CPU page table for a range of virtual addresses. Snapshot
 * validity is tracked by range struct. See hmm_vma_range_done() for further
 * information.
 *
 * The range struct is initialized here. It tracks the CPU page table, but only
 * if the function returns success (0), in which case the caller must then call
 * hmm_vma_range_done() to stop CPU page table update tracking on this range.
 *
 * NOT CALLING hmm_vma_range_done() IF FUNCTION RETURNS 0 WILL LEAD TO SERIOUS
 * MEMORY CORRUPTION ! YOU HAVE BEEN WARNED !
 */
int hmm_vma_get_pfns(struct vm_area_struct *vma,
		     struct hmm_range *range,
		     unsigned long start,
		     unsigned long end,
		     hmm_pfn_t *pfns)
{
	struct hmm_vma_walk hmm_vma_walk;
	struct mm_walk mm_walk;
	struct hmm *hmm;

	/* FIXME support hugetlb fs */
	if (is_vm_hugetlb_page(vma) || (vma->vm_flags & VM_SPECIAL)) {
		hmm_pfns_special(pfns, start, end);
		return -EINVAL;
	}

	/* Sanity check, this really should not happen ! */
	if (start < vma->vm_start || start >= vma->vm_end)
		return -EINVAL;
	if (end < vma->vm_start || end > vma->vm_end)
		return -EINVAL;

	hmm = hmm_register(vma->vm_mm);
	if (!hmm)
		return -ENOMEM;
	/* Caller must have registered a mirror, via hmm_mirror_register() ! */
	if (!hmm->mmu_notifier.ops)
		return -EINVAL;

	/* Initialize range to track CPU page table update */
	range->start = start;
	range->pfns = pfns;
	range->end = end;
	spin_lock(&hmm->lock);
	range->valid = true;
	list_add_rcu(&range->list, &hmm->ranges);
	spin_unlock(&hmm->lock);

	hmm_vma_walk.fault = false;
	hmm_vma_walk.range = range;
	mm_walk.private = &hmm_vma_walk;

	mm_walk.vma = vma;
	mm_walk.mm = vma->vm_mm;
	mm_walk.pte_entry = NULL;
	mm_walk.test_walk = NULL;
	mm_walk.hugetlb_entry = NULL;
	mm_walk.pmd_entry = hmm_vma_walk_pmd;
	mm_walk.pte_hole = hmm_vma_walk_hole;

	walk_page_range(start, end, &mm_walk);
	return 0;
}
EXPORT_SYMBOL(hmm_vma_get_pfns);

那么 `pfns` 是在哪里被更新的呢？
这里还有一个非常重要的结构体 `mm_walk`。

#### struct mm_walk

```c
/**
 * mm_walk - callbacks for walk_page_range
 * @pud_entry: if set, called for each non-empty PUD (2nd-level) entry
 *	       this handler should only handle pud_trans_huge() puds.
 *	       the pmd_entry or pte_entry callbacks will be used for
 *	       regular PUDs.
 * @pmd_entry: if set, called for each non-empty PMD (3rd-level) entry
 *	       this handler is required to be able to handle
 *	       pmd_trans_huge() pmds.  They may simply choose to
 *	       split_huge_page() instead of handling it explicitly.
 * @pte_entry: if set, called for each non-empty PTE (4th-level) entry
 * @pte_hole: if set, called for each hole at all levels
 * @hugetlb_entry: if set, called for each hugetlb entry
 * @test_walk: caller specific callback function to determine whether
 *             we walk over the current vma or not. Returning 0
 *             value means "do page table walk over the current vma,"
 *             and a negative one means "abort current page table walk
 *             right now." 1 means "skip the current vma."
 * @mm:        mm_struct representing the target process of page table walk
 * @vma:       vma currently walked (NULL if walking outside vmas)
 * @private:   private data for callbacks' usage
 *
 * (see the comment on walk_page_range() for more details)
 */
struct mm_walk {
	int (*pud_entry)(pud_t *pud, unsigned long addr,
			 unsigned long next, struct mm_walk *walk);
	int (*pmd_entry)(pmd_t *pmd, unsigned long addr,
			 unsigned long next, struct mm_walk *walk);
	int (*pte_entry)(pte_t *pte, unsigned long addr,
			 unsigned long next, struct mm_walk *walk);
	int (*pte_hole)(unsigned long addr, unsigned long next,
			struct mm_walk *walk);
	int (*hugetlb_entry)(pte_t *pte, unsigned long hmask,
			     unsigned long addr, unsigned long next,
			     struct mm_walk *walk);
	int (*test_walk)(unsigned long addr, unsigned long next,
			struct mm_walk *walk);
	struct mm_struct *mm;
	struct vm_area_struct *vma;
	void *private;
};
```
这里的 `private` 字段在 `hmm_vma_get_pfns` 中将被赋值 `&hmm_vma_walk`。

```c
struct hmm_vma_walk {
	struct hmm_range	*range;
	unsigned long		last;
	bool			fault;
	bool			block;
	bool			write;
};
```

`hmm_range` 用于追踪指定虚拟地址范围内的页表失效事件，其中包含我们关注的 `pfns`。
由于 `hmm_vma_get_pfns` 中的

```c
mm_walk.pmd_entry = hmm_vma_walk_pmd;
```

这行单独设置了 `pmd` 的 callback function，`walk_page_range(start, end, walk)` 遍历页表时，会将对应的 `pfns` 状态更新。
在 walk page table 的过程中，会通过 `*private` 找到 `hmm_vma_walk`，从而找到 `range->pfns`，并更新 `pfns` 的有效状态。

#### hmm_devmem_ops

callback for `ZONE_DEVICE` memory events.

```c

/*
 * struct hmm_devmem_ops - callback for ZONE_DEVICE memory events
 *
 * @free: call when refcount on page reach 1 and thus is no longer use
 * @fault: call when there is a page fault to unaddressable memory
 *
 * Both callback happens from page_free() and page_fault() callback of struct
 * dev_pagemap respectively. See include/linux/memremap.h for more details on
 * those.
 *
 * The hmm_devmem_ops callback are just here to provide a coherent and
 * uniq API to device driver and device driver should not register their
 * own page_free() or page_fault() but rely on the hmm_devmem_ops call-
 * back.
 */
struct hmm_devmem_ops {
	/*
	 * free() - free a device page
	 * @devmem: device memory structure (see struct hmm_devmem)
	 * @page: pointer to struct page being freed
	 *
	 * Call back occurs whenever a device page refcount reach 1 which
	 * means that no one is holding any reference on the page anymore
	 * (ZONE_DEVICE page have an elevated refcount of 1 as default so
	 * that they are not release to the general page allocator).
	 *
	 * Note that callback has exclusive ownership of the page (as no
	 * one is holding any reference).
	 */
	void (*free)(struct hmm_devmem *devmem, struct page *page);
	/*
	 * fault() - CPU page fault or get user page (GUP)
	 * @devmem: device memory structure (see struct hmm_devmem)
	 * @vma: virtual memory area containing the virtual address
	 * @addr: virtual address that faulted or for which there is a GUP
	 * @page: pointer to struct page backing virtual address (unreliable)
	 * @flags: FAULT_FLAG_* (see include/linux/mm.h)
	 * @pmdp: page middle directory
	 * Returns: VM_FAULT_MINOR/MAJOR on success or one of VM_FAULT_ERROR
	 *   on error
	 *
	 * The callback occurs whenever there is a CPU page fault or GUP on a
	 * virtual address. This means that the device driver must migrate the
	 * page back to regular memory (CPU accessible).
	 *
	 * The device driver is free to migrate more than one page from the
	 * fault() callback as an optimization. However if device decide to
	 * migrate more than one page it must always priotirize the faulting
	 * address over the others.
	 *
	 * The struct page pointer is only given as an hint to allow quick
	 * lookup of internal device driver data. A concurrent migration
	 * might have already free that page and the virtual address might
	 * not longer be back by it. So it should not be modified by the
	 * callback.
	 *
	 * Note that mmap semaphore is held in read mode at least when this
	 * callback occurs, hence the vma is valid upon callback entry.
	 */
	int (*fault)(struct hmm_devmem *devmem,
		     struct vm_area_struct *vma,
		     unsigned long addr,
		     const struct page *page,
		     unsigned int flags,
		     pmd_t *pmdp);
};

```

按照描述，这两个函数是 device memory 相关的 callback。此时页表指向的内存并不在 CPU 这端：需要 free 一块 device memory，或者是 CPU 访问到这块内存时产生一个 page fault，将对应设备内存迁移回 CPU 端。

#### struct hmm_devmem

struct to track device memory.  

```c
/*
 * struct hmm_devmem - track device memory
 *
 * @completion: completion object for device memory
 * @pfn_first: first pfn for this resource (set by hmm_devmem_add())
 * @pfn_last: last pfn for this resource (set by hmm_devmem_add())
 * @resource: IO resource reserved for this chunk of memory
 * @pagemap: device page map for that chunk
 * @device: device to bind resource to
 * @ops: memory operations callback
 * @ref: per CPU refcount
 *
 * This an helper structure for device drivers that do not wish to implement
 * the gory details related to hotplugging new memoy and allocating struct
 * pages.
 *
 * Device drivers can directly use ZONE_DEVICE memory on their own if they
 * wish to do so.
 */
struct hmm_devmem {
	struct completion		completion;
	unsigned long			pfn_first;
	unsigned long			pfn_last;
	struct resource			*resource;
	struct device			*device;
	struct dev_pagemap		pagemap;
	const struct hmm_devmem_ops	*ops;
	struct percpu_ref		ref;
};
```


##### struct completion


struct completion 是 Linux 内核中的一种一次性事件同步机制，用于让一个执行上下文等待另一个执行上下文完成某项工作。这里是使用一个FIFO队列实现的。  

```c
/*
 * struct completion - structure used to maintain state for a "completion"
 *
 * This is the opaque structure used to maintain the state for a "completion".
 * Completions currently use a FIFO to queue threads that have to wait for
 * the "completion" event.
 *
 * See also:  complete(), wait_for_completion() (and friends _timeout,
 * _interruptible, _interruptible_timeout, and _killable), init_completion(),
 * reinit_completion(), and macros DECLARE_COMPLETION(),
 * DECLARE_COMPLETION_ONSTACK().
 */
struct completion {
	unsigned int done;
	wait_queue_head_t wait;
#ifdef CONFIG_LOCKDEP_COMPLETIONS
	struct lockdep_map_cross map;
#endif
};

```

##### struct resource

```c
/*
 * Resources are tree-like, allowing
 * nesting etc..
 */
struct resource {
	resource_size_t start;
	resource_size_t end;
	const char *name;
	unsigned long flags;
	unsigned long desc;
	struct resource *parent, *sibling, *child;
};
```
struct resource 用于描述并管理 Linux 内核中的一段硬件资源区间，例如物理内存、I/O 端口、PCI BAR 和中断号等。内核把资源组织成树，以表达资源的包含、并列关系，并检测区间冲突。

##### struct dev_pagemap

dev_pagemap 是一段 ZONE_DEVICE 内存的描述符，使设备内存能够拥有 struct page，并接入内核的缺页、引用和回收机制。

```c
/**
 * struct dev_pagemap - metadata for ZONE_DEVICE mappings
 * @page_fault: callback when CPU fault on an unaddressable device page
 * @page_free: free page callback when page refcount reaches 1
 * @altmap: pre-allocated/reserved memory for vmemmap allocations
 * @res: physical address range covered by @ref
 * @ref: reference count that pins the devm_memremap_pages() mapping
 * @dev: host device of the mapping for debug
 * @data: private data pointer for page_free()
 * @type: memory type: see MEMORY_* in memory_hotplug.h
 */
struct dev_pagemap {
	dev_page_fault_t page_fault;
	dev_page_free_t page_free;
	struct vmem_altmap *altmap;
	const struct resource *res;
	struct percpu_ref *ref;
	struct device *dev;
	void *data;
	enum memory_type type;
};

```

##### struct percpu_ref

percpu_ref 是针对高频 get/put 优化的引用计数，平时使用每 CPU 计数提高性能，销毁阶段切换为原子计数以准确判断引用是否归零。

```c
struct percpu_ref {
	atomic_long_t		count;
	/*
	 * The low bit of the pointer indicates whether the ref is in percpu
	 * mode; if set, then get/put will manipulate the atomic_t.
	 */
	unsigned long		percpu_count_ptr;
	percpu_ref_func_t	*release;
	percpu_ref_func_t	*confirm_switch;
	bool			force_atomic:1;
	struct rcu_head		rcu;
};
```

#### Add or remove device memory

所谓"hotplug device memory",指的是将设备内存动态接入内核物理页管理模型。  

```c
/*
 * To add (hotplug) device memory, HMM assumes that there is no real resource
 * that reserves a range in the physical address space (this is intended to be
 * use by unaddressable device memory). It will reserve a physical range big
 * enough and allocate struct page for it.
 *
 * The device driver can wrap the hmm_devmem struct inside a private device
 * driver struct. The device driver must call hmm_devmem_remove() before the
 * device goes away and before freeing the hmm_devmem struct memory.
 */
struct hmm_devmem *hmm_devmem_add(const struct hmm_devmem_ops *ops,
				  struct device *device,
				  unsigned long size);
struct hmm_devmem *hmm_devmem_add_resource(const struct hmm_devmem_ops *ops,
					   struct device *device,
					   struct resource *res);
void hmm_devmem_remove(struct hmm_devmem *devmem);

```

#### migrate to and from device memory

```c
/*
 * migrate_vma() - migrate a range of memory inside vma
 *
 * @ops: migration callback for allocating destination memory and copying
 * @vma: virtual memory area containing the range to be migrated
 * @start: start address of the range to migrate (inclusive)
 * @end: end address of the range to migrate (exclusive)
 * @src: array of hmm_pfn_t containing source pfns
 * @dst: array of hmm_pfn_t containing destination pfns
 * @private: pointer passed back to each of the callback
 * returns: 0 on success, error code otherwise
 *
 * this function tries to migrate a range of memory virtual address range, using
 * callbacks to allocate and copy memory from source to destination. first it
 * collects all the pages backing each virtual address in the range, saving this
 * inside the src array. then it locks those pages and unmaps them. once the pages
 * are locked and unmapped, it checks whether each page is pinned or not. pages
 * that aren't pinned have the migrate_pfn_migrate flag set (by this function)
 * in the corresponding src array entry. it then restores any pages that are
 * pinned, by remapping and unlocking those pages.
 *
 * at this point it calls the alloc_and_copy() callback. for documentation on
 * what is expected from that callback, see struct migrate_vma_ops comments in
 * include/linux/migrate.h
 *
 * after the alloc_and_copy() callback, this function goes over each entry in
 * the src array that has the migrate_pfn_valid and migrate_pfn_migrate flag
 * set. if the corresponding entry in dst array has migrate_pfn_valid flag set,
 * then the function tries to migrate struct page information from the source
 * struct page to the destination struct page. if it fails to migrate the struct
 * page information, then it clears the migrate_pfn_migrate flag in the src
 * array.
 *
 * at this point all successfully migrated pages have an entry in the src
 * array with migrate_pfn_valid and migrate_pfn_migrate flag set and the dst
 * array entry with migrate_pfn_valid flag set.
 *
 * it then calls the finalize_and_map() callback. see comments for "struct
 * migrate_vma_ops", in include/linux/migrate.h for details about
 * finalize_and_map() behavior.
 *
 * after the finalize_and_map() callback, for successfully migrated pages, this
 * function updates the cpu page table to point to new pages, otherwise it
 * restores the cpu page table to point to the original source pages.
 *
 * function returns 0 after the above steps, even if no pages were migrated
 * (the function only returns an error if any of the arguments are invalid.)
 *
 * both src and dst array must be big enough for (end - start) >> page_shift
 * unsigned long entries.
 */
 ```

memory allocation - copy and cleanup.

```c
/*
 * struct migrate_vma_ops - migrate operation callback
 *
 * @alloc_and_copy: alloc destination memory and copy source memory to it
 * @finalize_and_map: allow caller to map the successfully migrated pages
 *
 *
 * The alloc_and_copy() callback happens once all source pages have been locked,
 * unmapped and checked (checked whether pinned or not). All pages that can be
 * migrated will have an entry in the src array set with the pfn value of the
 * page and with the MIGRATE_PFN_VALID and MIGRATE_PFN_MIGRATE flag set (other
 * flags might be set but should be ignored by the callback).
 *
 * The alloc_and_copy() callback can then allocate destination memory and copy
 * source memory to it for all those entries (ie with MIGRATE_PFN_VALID and
 * MIGRATE_PFN_MIGRATE flag set). Once these are allocated and copied, the
 * callback must update each corresponding entry in the dst array with the pfn
 * value of the destination page and with the MIGRATE_PFN_VALID and
 * MIGRATE_PFN_LOCKED flags set (destination pages must have their struct pages
 * locked, via lock_page()).
 *
 * At this point the alloc_and_copy() callback is done and returns.
 *
 * Note that the callback does not have to migrate all the pages that are
 * marked with MIGRATE_PFN_MIGRATE flag in src array unless this is a migration
 * from device memory to system memory (ie the MIGRATE_PFN_DEVICE flag is also
 * set in the src array entry). If the device driver cannot migrate a device
 * page back to system memory, then it must set the corresponding dst array
 * entry to MIGRATE_PFN_ERROR. This will trigger a SIGBUS if CPU tries to
 * access any of the virtual addresses originally backed by this page. Because
 * a SIGBUS is such a severe result for the userspace process, the device
 * driver should avoid setting MIGRATE_PFN_ERROR unless it is really in an
 * unrecoverable state.
 *
 * For empty entry inside CPU page table (pte_none() or pmd_none() is true) we
 * do set MIGRATE_PFN_MIGRATE flag inside the corresponding source array thus
 * allowing device driver to allocate device memory for those unback virtual
 * address. For this the device driver simply have to allocate device memory
 * and properly set the destination entry like for regular migration. Note that
 * this can still fails and thus inside the device driver must check if the
 * migration was successful for those entry inside the finalize_and_map()
 * callback just like for regular migration.
 *
 * THE alloc_and_copy() CALLBACK MUST NOT CHANGE ANY OF THE SRC ARRAY ENTRIES
 * OR BAD THINGS WILL HAPPEN !
 *
 *
 * The finalize_and_map() callback happens after struct page migration from
 * source to destination (destination struct pages are the struct pages for the
 * memory allocated by the alloc_and_copy() callback).  Migration can fail, and
 * thus the finalize_and_map() allows the driver to inspect which pages were
 * successfully migrated, and which were not. Successfully migrated pages will
 * have the MIGRATE_PFN_MIGRATE flag set for their src array entry.
 *
 * It is safe to update device page table from within the finalize_and_map()
 * callback because both destination and source page are still locked, and the
 * mmap_sem is held in read mode (hence no one can unmap the range being
 * migrated).
 *
 * Once callback is done cleaning up things and updating its page table (if it
 * chose to do so, this is not an obligation) then it returns. At this point,
 * the HMM core will finish up the final steps, and the migration is complete.
 *
 * THE finalize_and_map() CALLBACK MUST NOT CHANGE ANY OF THE SRC OR DST ARRAY
 * ENTRIES OR BAD THINGS WILL HAPPEN !
 */
struct migrate_vma_ops {
	void (*alloc_and_copy)(struct vm_area_struct *vma,
			       const unsigned long *src,
			       unsigned long *dst,
			       unsigned long start,
			       unsigned long end,
			       void *private);
	void (*finalize_and_map)(struct vm_area_struct *vma,
				 const unsigned long *src,
				 const unsigned long *dst,
				 unsigned long start,
				 unsigned long end,
				 void *private);
};

```

## kernel 5.14

### test: anon_read

testing purpose:  
```
某个进程虚拟地址当前对应哪个系统物理页，映射是否有效以及是否可写？


典型路径是模拟设备访问仍驻留在系统内存中的数据：

设备访问用户虚拟地址
    ↓
dmirror->pt 中没有映射
    ↓
dmirror_fault()
    ↓
hmm_range_fault()
    ↓
遍历进程 CPU 页表
    ↓
输出 PFN 和权限到 hmm_range.hmm_pfns[]
    ↓
驱动通过 xa_store() 更新 dmirror->pt
    ↓
设备重新读取系统页面
```

```
hmm_dmirror_cmd(..., HMM_DMIRROR_READ, ...)
    ->dmirror_read(dmirror, &cmd)
        ->dmirror_do_read(dmirror, start, end, &bounce);[copy data in dmirros to bounce->ptr]
          dmirror_fault(dmirror, start, end, false);[marked range need to fault in dmirror with hmm_range, then fault them]
            ->dmirror_range_fault(dmirror, &range);
                ->hmm_range_fault(range);
```

在`hmm_range_fault`中将相关进程地址映射保存到`range.hmm_pfns[]`中，并且由`dmirror_fault`建立设备页表的正确映射(`struct page`).随后在`dmirror_do_read`中使用`memcpy_from_page`函数，模拟设备从系统页读取数据的过程(to bounce->ptr)

```c
#ifdef CONFIG_TRANSPARENT_HUGEPAGE
static int hmm_vma_handle_pmd(struct mm_walk *walk, unsigned long addr,
			      unsigned long end, unsigned long hmm_pfns[],
			      pmd_t pmd)
{
	struct hmm_vma_walk *hmm_vma_walk = walk->private;
	struct hmm_range *range = hmm_vma_walk->range;
	unsigned long pfn, npages, i;
	unsigned int required_fault;
	unsigned long cpu_flags;

	npages = (end - addr) >> PAGE_SHIFT;
	cpu_flags = pmd_to_hmm_pfn_flags(range, pmd);
	required_fault =
		hmm_range_need_fault(hmm_vma_walk, hmm_pfns, npages, cpu_flags);
	if (required_fault)
		return hmm_vma_fault(addr, end, required_fault, walk);

	pfn = pmd_pfn(pmd) + ((addr & ~PMD_MASK) >> PAGE_SHIFT);
	for (i = 0; addr < end; addr += PAGE_SIZE, i++, pfn++)
		hmm_pfns[i] = pfn | cpu_flags; /* set pfns here */
	return 0;
}
```

### test: migrate_fault

testing purpose:  

```
第一阶段：系统页迁移到 DEVICE_PRIVATE

buffer->ptr 对应普通系统页
    ↓
HMM_DMIRROR_MIGRATE_TO_DEV
    ↓
migrate_vma_setup()
    ↓
分配 DEVICE_PRIVATE 目标页
    ↓
复制系统页数据到模拟设备内存
    ↓
migrate_vma_pages()
    ↓
驱动更新 dmirror->pt
    ↓
migrate_vma_finalize()
    ↓
CPU PTE 变为 device-private entry


第二阶段：CPU 访问 DEVICE_PRIVATE 页

迁移完成后，CPU 再访问同一个 buffer->ptr：

CPU load/store buffer->ptr
    ↓
CPU 页表中不是普通 present PTE
    ↓
发现 device-private 特殊页表项
    ↓
CPU page fault
    ↓
根据 device-private entry 找到 dpage
    ↓
根据 dpage->pgmap 找到 dev_pagemap_ops
    ↓
调用 .migrate_to_ram
    ↓
dmirror_devmem_fault()
    ↓
使用 migrate_vma_* 迁回系统 RAM
```
```c
/*
 * Migrate anonymous memory to device private memory and fault some of it back
 * to system memory, then try migrating the resulting mix of system and device
 * private memory to the device.
 */
TEST_F(hmm, migrate_fault)
```

```c

/* migrate memory to device */
    	ret = hmm_migrate_sys_to_dev(self->fd, buffer, npages);
            ->	return hmm_dmirror_cmd(fd, HMM_DMIRROR_MIGRATE_TO_DEV, buffer, npages);
                -> static long dmirror_fops_unlocked_ioctl(struct file *filp,
					unsigned int command,
					unsigned long arg)
                    ->ret = dmirror_migrate_to_device(dmirror, &cmd);
                        ->ret = migrate_vma_setup(&args);
                            ->migrate_vma_collect(args);
                                    ...->__walk_page_range(...)
                            ->dmirror_migrate_alloc_and_copy(&args, dmirror);
                            ->migrate_vma_pages(&args);
                            ->dmirror_migrate_finalize_and_map(&args, dmirror);
                            ->migrate_vma_finalize(&args);


```

```c
	args.vma = vma;
		args.src = src_pfns;
		args.dst = dst_pfns;
		args.start = addr;
		args.end = next;
		args.pgmap_owner = dmirror->mdevice;
		args.flags = MIGRATE_VMA_SELECT_SYSTEM;
		ret = migrate_vma_setup(&args);
```

### (migrate_vma_finalize ->)migrate_device_finalize

```
1. 从 src_pfns[] 和 dst_pfns[] 解码源、目标 folio；
2. 判断该页是否迁移成功；
3. 失败时释放目标页并将 dst 设回 src；
4. 普通 RAM 目标页加入 LRU；
5. 使用 remove_migration_ptes()：
       成功时切换到目标页；
       失败时恢复原源页；
6. 解锁并释放源 folio 的迁移引用；
7. 成功时再解锁并释放目标 folio 的迁移引用。
```


### migrate_device_pages

`migrate_device_pages` is not for copying data,but:  
```
1. 验证目标页是否存在；
2
2. 对空 PTE 场景直接插入目标页；
3
3. 检查设备目标页类型是否受支持；
4
4. 限制迁往设备内存的源页类型；
5
5. 调用 migrate_folio() 迁移页面的 MM 元数据；
6
6. 通过 MIGRATE_PFN_MIGRATE 标志记录逐页成功或失败；
7
7. 在直接插页场景中协调 MMU notifier。
```

### dmirror_migrate_finalize_and_map

```
遍历迁移结果，对仍保留 MIGRATE_PFN_MIGRATE 的成功页面，从 dst[] 恢复 DEVICE_PRIVATE 目标页，取得其模拟数据后备页，并将“用户虚拟页号 → 后备页及写权限”的映射写入 dmirror->pt。
```

### dmirror_migrate_alloc_and_copy

```
dmirror_migrate_alloc_and_copy() 主要执行四项工作：

1. 根据 src[] 筛选 migrate_vma_setup() 认定可迁移的页面；
2. 为每个页面分配 DEVICE_PRIVATE 目标页 dpage；
3. 将普通系统页 spage 的数据复制到目标设备页的模拟后备页 rpage；
4. 在 dst[] 中填写目标 PFN 和写权限，交给 migrate_vma_pages() 继续处理。
```

### migrate_vma_setup

`migrate_vma_setup`:  
```c
/*
将指定虚拟地址范围中的源页面收集到 src[]，锁定并临时解除 CPU 映射，排除被 pin 或不适合迁移的页面，
并为真正可迁移的页面设置 MIGRATE_PFN_MIGRATE，从而为驱动分配目标页和复制数据创造稳定窗口。
*/

int migrate_vma_setup(struct migrate_vma *args)
{
	long nr_pages = (args->end - args->start) >> PAGE_SHIFT;

	args->start &= PAGE_MASK;
	args->end &= PAGE_MASK;
	if (!args->vma || is_vm_hugetlb_page(args->vma) ||
	    (args->vma->vm_flags & VM_SPECIAL) || vma_is_dax(args->vma))
		return -EINVAL;
	if (nr_pages <= 0)
		return -EINVAL;
	if (args->start < args->vma->vm_start ||
	    args->start >= args->vma->vm_end)
		return -EINVAL;
	if (args->end <= args->vma->vm_start || args->end > args->vma->vm_end)
		return -EINVAL;
	if (!args->src || !args->dst)
		return -EINVAL;
	if (args->fault_page && !is_device_private_page(args->fault_page))
		return -EINVAL;

	memset(args->src, 0, sizeof(*args->src) * nr_pages);
	args->cpages = 0;
	args->npages = 0;

	migrate_vma_collect(args);

	if (args->cpages)
		migrate_vma_unmap(args);

	/*
	 * At this point pages are locked and unmapped, and thus they have
	 * stable content and can safely be copied to destination memory that
	 * is allocated by the drivers.
	 */
	return 0;

}
EXPORT_SYMBOL(migrate_vma_setup);

```

return 0 doesb't prove all the pages can be migrated:  

```
范围内所有页面均可迁移
范围内只有部分页面可迁移
范围内没有任何页面可迁移
范围内页表项为空，但允许驱动分配目标页
```

so driver should check all the page in src[] later.  


#### migrate_vma_collect


```c

/*
 * migrate_vma_collect() - collect pages over a range of virtual addresses
 * @migrate: migrate struct containing all migration information
 *
 * This will walk the CPU page table. For each virtual address backed by a
 * valid page, it updates the src array and takes a reference on the page, in
 * order to pin the page until we lock it and unmap it.
 */
static void migrate_vma_collect(struct migrate_vma *migrate)
{
	struct mmu_notifier_range range;

	/*
	 * Note that the pgmap_owner is passed to the mmu notifier callback so
	 * that the registered device driver can skip invalidating device
	 * private page mappings that won't be migrated.
	 */
	mmu_notifier_range_init_owner(&range, MMU_NOTIFY_MIGRATE, 0,
		migrate->vma->vm_mm, migrate->start, migrate->end,
		migrate->pgmap_owner);
	mmu_notifier_invalidate_range_start(&range);

	walk_page_range(migrate->vma->vm_mm, migrate->start, migrate->end,
			&migrate_vma_walk_ops, migrate);

	mmu_notifier_invalidate_range_end(&range);
	migrate->end = migrate->start + (migrate->npages << PAGE_SHIFT);
}
```


#### struct mm_walk_ops migrate_vma_walk_ops

这是传给 `walk_page_range()` 的页表遍历回调集合。
```c

static const struct mm_walk_ops migrate_vma_walk_ops = {
	.pmd_entry		= migrate_vma_collect_pmd,
	.pte_hole		= migrate_vma_collect_hole,
	.walk_lock		= PGWALK_RDLOCK,
};
```
### struct migrate_vma

```c

struct migrate_vma {
	struct vm_area_struct	*vma;
	/*
	 * Both src and dst array must be big enough for
	 * (end - start) >> PAGE_SHIFT entries.
	 *
	 * The src array must not be modified by the caller after
	 * migrate_vma_setup(), and must not change the dst array after
	 * migrate_vma_pages() returns.
	 */
	unsigned long		*dst;
	unsigned long		*src;
	unsigned long		cpages;
	unsigned long		npages;
	unsigned long		start;
	unsigned long		end;

	/*
	 * Set to the owner value also stored in page->pgmap->owner for
	 * migrating out of device private memory. The flags also need to
	 * be set to MIGRATE_VMA_SELECT_DEVICE_PRIVATE.
	 * The caller should always set this field when using mmu notifier
	 * callbacks to avoid device MMU invalidations for device private
	 * pages that are not being migrated.
	 */
	void			*pgmap_owner;
	unsigned long		flags;

	/*
	 * Set to vmf->page if this is being called to migrate a page as part of
	 * a migrate_to_ram() callback.
	 */
	struct page		*fault_page;
};
```

### hmm_range_fault

```c
/**
 * hmm_range_fault - try to fault some address in a virtual address range
 * @range:	argument structure
 *
 * Returns 0 on success or one of the following error codes:
 *
 * -EINVAL:	Invalid arguments or mm or virtual address is in an invalid vma
 *		(e.g., device file vma).
 * -ENOMEM:	Out of memory.
 * -EPERM:	Invalid permission (e.g., asking for write and range is read
 *		only).
 * -EBUSY:	The range has been invalidated and the caller needs to wait for
 *		the invalidation to finish.
 * -EFAULT:     A page was requested to be valid and could not be made valid
 *              ie it has no backing VMA or it is illegal to access
 *
 * This is similar to get_user_pages(), except that it can read the page tables
 * without mutating them (ie causing faults).
 */
int hmm_range_fault(struct hmm_range *range)
```

`hmm_range_fault()` 本身主要负责遍历 CPU 页表，并把每个虚拟页面的结果写入 `hmm_range.hmm_pfns[]`。真正更新 `dmirror->pt` 的动作发生在 `hmm_range_fault()` 返回之后，由 `dmirror_fault()` 对 `hmm_pfns[]` 逐项解析并调用 `xa_store()` 完成。 HMM 核心只提供页表查询结果，不会直接操作驱动私有的模拟设备页表。


### dmirror

`dmirror`: Data attached to the open device file, like:

```c
/*
 * Data attached to the open device file.
 * Note that it might be shared after a fork().
 */
struct dmirror {
	struct dmirror_device		*mdevice;
	struct xarray			pt;
	struct mmu_interval_notifier	notifier;
	struct mutex			mutex;
};
```
在这个测试流程中，`dmirror`实际上是设备对应的私有内存。而`dmirror->pt`是模拟设备页表  
而`bounce->ptr`模拟设备内部的接收缓冲区.  
`buffer->ptr`为将被设备读取的system memory  
`buffer->mirror`为用户态从设备获取的读取结果  

```c

/* hmm_dmirror_cmd */
...
/* Simulate a device reading system memory. */
	cmd.addr = (__u64)buffer->ptr;
	cmd.ptr = (__u64)buffer->mirror;
	cmd.npages = npages;

/* dmirror_fops_unlocked_ioctl */
dmirror = filp->private_data
/*dmirror_bounce_init */
bounce->addr = buffer->ptr

```


## TODO

- 阅读 v4.14 hmm.c 源码

## important code

| 测试                 | 主要问题                   | 重点函数                                |
| ------------------ | ---------------------- | ----------------------------------- |
| `anon_read`        | 设备如何读取普通匿名页            | `hmm_range_fault`、`dmirror_do_read` |
| `anon_write`       | 写权限如何请求和验证             | `HMM_PFN_REQ_WRITE`、写保护处理           |
| `snapshot`         | 不主动 fault 时如何读取页表状态    | snapshot ioctl、`hmm_range_fault`    |
| `migrate`          | 页面如何进入设备私有内存           | `migrate_vma_setup/pages/finalize`  |
| `migrate_fault`    | CPU 如何访问设备私有页          | fault handler、`migrate_to_ram`      |
| `migrate_multiple` | 多页迁移与批处理               | `migrate_vma_*`、循环范围                |
| `anon_teardown`    | `mm` 销毁与 notifier 生命周期 | `mmu_interval_notifier_remove`      |
| `exclusive`        | 设备独占页和 CPU 映射处理        | exclusive entry、`-EBUSY` 分支         |

## References

- [LWN: HMM v25](https://lwn.net/Articles/731259/)
