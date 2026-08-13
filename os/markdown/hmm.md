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

APIS:


#### int hmm_mirror_register(struct hmm_mirror *mirror, struct mm_struct *mm);

A device driver that want to mirror a process address space must start with registaration of an hmm_mirror struct.

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
这是hmm中per device的一个数据结构，而hmm是mm-unique的。

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

a set of callback that are used to propagate cpu page table.  
当host端更新页表时(turan page read only, fully unmap...)，device driver必须调用对应的callback更新设备端页表，并且保证完成后再返回。  

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
注释的表述有点令人感到误解，他的意思是跟踪指定虚拟地址范围上的页表失效事件。  
pfns数组追踪[start, end)内所有pfns?


#### int hmm_vma_get_pfns(struct vm_area_struct *vma,
		     struct hmm_range *range,
		     unsigned long start,
		     unsigned long end,
		     hmm_pfn_t *pfns);

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

```

在`hmm_pfn_special`中， 对前`UPPAGE(end - addr)/PGSIZE)`个pfns赋值` HMM_PFN_SPECIAL`

```c
for (; addr < end; addr += PAGE_SIZE, pfns++)
		*pfns = HMM_PFN_SPECIAL;
}
```

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

#### hmm_demem

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

#### migrate to and from device memory.

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

## refs

[lwn_hmm_v25](https://lwn.net/Articles/731259/)
