# Linux 内存管理（mm）

> 基于内核版本 v4.14.0

## 结构关系速览

Linux 进程地址空间以 `mm_struct` 为根，VMA 描述连续虚拟地址区间，页表建立虚拟地址到物理页的映射，`struct page` 则承载物理页的内核元数据。

```text
task_struct
  ↓
mm_struct
  ├─ VMA list / rb tree → vm_area_struct
  ├─ pgd → p4d → pud → pmd → pte
  └─ mmu_notifier → HMM/KVM/设备页表同步

pte → pfn → struct page
```

| 结构 | 作用 |
| --- | --- |
| `mm_struct` | 一个进程地址空间的核心描述 |
| `vm_area_struct` | 一段连续虚拟地址区间及其权限、映射来源 |
| page table | 虚拟地址到物理页/特殊映射的翻译结构 |
| `struct page` | 物理页帧的状态、引用计数、LRU/Slab 等元数据 |
| `mmu_notifier` | CPU 页表变化时通知 KVM、HMM 等外部页表使用者 |

## `mm_struct`

结构体定义（仅保留关键字段，完整定义见 `include/linux/mm_types.h`）：

```c
struct mm_struct {
	struct vm_area_struct *mmap;	/* list of VMAs */
	struct rb_root mm_rb;
	unsigned long (*get_unmapped_area)(...);
	unsigned long mmap_base;	/* base of mmap area */
	unsigned long task_size;	/* size of task vm space */
	unsigned long highest_vm_end;	/* highest vma end address */
	pgd_t *pgd;

	atomic_t mm_users;	/* 用户计数（含用户空间） */
	atomic_t mm_count;	/* mm_struct 本身的引用计数 */

	atomic_long_t nr_ptes;	/* PTE page table pages */
	int map_count;		/* number of VMAs */

	spinlock_t page_table_lock;	/* Protects page tables and some counters */
	struct rw_semaphore mmap_sem;

	unsigned long total_vm, locked_vm, pinned_vm;
	unsigned long data_vm, exec_vm, stack_vm;
	unsigned long start_code, end_code, start_data, end_data;
	unsigned long start_brk, brk, start_stack;
	unsigned long arg_start, arg_end, env_start, env_end;

	struct linux_binfmt *binfmt;
	mm_context_t context;
	/* ... */
} __randomize_layout;
```

关键字段解释：

| 字段 | 含义 |
| --- | --- |
| `mmap` | VMA 链表头 |
| `mm_rb` | VMA 红黑树根节点 |
| `pgd` | 指向页全局目录（页表） |
| `mm_users` | 使用该地址空间的用户数（含用户空间），用 `mmget()`/`mmput()` 修改 |
| `mm_count` | `mm_struct` 本身的引用计数（`mm_users` 计为 1），用 `mmgrab()`/`mmdrop()` 修改 |
| `mmap_sem` | 保护地址空间的读写信号量 |
| `start_code/end_code`、`start_data/end_data` | 代码段、数据段的起止地址 |
| `start_brk/brk`、`start_stack` | 堆的起止和栈底 |

`mm_users` 与 `mm_count` 的关系：`mm_users` 归零（任务退出且无临时引用）时会释放一个 `mm_count` 引用；`mm_count` 也归零时 `mm_struct` 才被释放。

## `vm_area_struct`

```c
struct vm_area_struct {
	unsigned long vm_start;	/* Our start address within vm_mm. */
	unsigned long vm_end;	/* The first byte after our end address. */

	/* linked list of VM areas per task, sorted by address */
	struct vm_area_struct *vm_next, *vm_prev;
	struct rb_node vm_rb;

	unsigned long rb_subtree_gap;

	struct mm_struct *vm_mm;	/* The address space we belong to. */
	pgprot_t vm_page_prot;		/* Access permissions of this VMA. */
	unsigned long vm_flags;		/* Flags, see mm.h. */

	struct list_head anon_vma_chain;
	struct anon_vma *anon_vma;

	const struct vm_operations_struct *vm_ops;

	unsigned long vm_pgoff;	/* Offset (within vm_file) in PAGE_SIZE units */
	struct file *vm_file;	/* File we map to (can be NULL). */
	/* ... */
} __randomize_layout;
```

关键字段解释：

| 字段 | 含义 |
| --- | --- |
| `vm_start` / `vm_end` | VMA 覆盖的虚拟地址范围 `[vm_start, vm_end)` |
| `vm_next` / `vm_prev` | 按地址排序的 VMA 链表 |
| `vm_rb` | 红黑树节点 |
| `vm_mm` | 所属的 `mm_struct` |
| `vm_page_prot` | 访问权限 |
| `vm_flags` | 标志位（见 `mm.h`） |
| `vm_file` | 映射的文件（匿名映射为 NULL） |
| `vm_pgoff` | 文件内偏移（以页为单位） |
| `anon_vma` / `anon_vma_chain` | 匿名页反向映射的树/链表 |

Q: 为什么同时维护链表和红黑树两种组织方式？

A: 链表适合按地址顺序遍历整个地址空间，红黑树适合按地址快速查找 VMA。旧版本内核同时维护两者，以兼顾遍历和查找效率；新版本中该方向逐步演进为 maple tree 等更适合大规模 VMA 管理的数据结构。

## `struct page`

```c
struct page {
	/* First double word block */
	unsigned long flags;	/* Atomic flags, some possibly updated asynchronously */
	union {
		struct address_space *mapping;	/* inode address_space or anon_vma */
		void *s_mem;			/* slab first object */
		atomic_t compound_mapcount;	/* first tail page */
	};

	/* Second double word */
	union {
		pgoff_t index;		/* Our offset within mapping. */
		void *freelist;		/* sl[aou]b first free object */
	};

	union {
		unsigned long counters;
		struct {
			union {
				atomic_t _mapcount;	/* ptes mapped in mms */
				unsigned int active;	/* SLAB */
				struct {		/* SLUB */
					unsigned inuse:16;
					unsigned objects:15;
					unsigned frozen:1;
				};
			};
			atomic_t _refcount;	/* 使用计数，须通过 page_ref.h 的封装函数操作 */
		};
	};

	/* Third double word block */
	union {
		struct list_head lru;	/* Pageout list, eg. active_list */
		struct dev_pagemap *pgmap;
		struct rcu_head rcu_head;
		/* ... */
	};

	/* Remainder is not double word aligned */
	union {
		unsigned long private;
		struct kmem_cache *slab_cache;	/* SL[AU]B: Pointer to slab */
	};
	/* ... */
};
```

关键字段解释：

| 字段 | 含义 |
| --- | --- |
| `flags` | 原子标志位，部分可能被异步更新 |
| `mapping` | 指向地址空间；低位为 1 时表示匿名页，指向 `anon_vma` |
| `index` | 在映射中的偏移 |
| `_mapcount` / `_refcount` | 映射计数与引用计数 |

## VMA 操作

### `find_vma(mm, addr)`

查找第一个满足 `addr < vm_end` 的 VMA，不存在则返回 NULL。

1. 先检查 vmacache；
2. 再从 `mm->mm_rb.rb_node` 开始在红黑树中查找；
3. 更新 vmacache。

### `find_vma_prev(mm, addr, pprev)`

与 `find_vma` 相同，但额外通过 `*pprev` 返回前一个 VMA。

注意：若 `addr` 大于所有 VMA 的 `vm_end`，返回 `vm_end` 最大的 VMA。

### `_vm_normal_page(vma, addr, pte, with_public_device)`

获取与 pte 关联的"普通页"对应的 `struct page`：

1. `check_pfn`；
2. `return pfn_to_page(pfn)`。

对于"特殊页"返回 NULL。

### `do_mmap(...)`

```c
unsigned long do_mmap(struct file *file, unsigned long addr, unsigned long len,
		      unsigned long prot, unsigned long flags,
		      vm_flags_t vm_flags, unsigned long pgoff,
		      unsigned long *populate, struct list_head *uf)
```

### `mmap_region(...)`

```c
unsigned long mmap_region(struct file *file, unsigned long addr,
			   unsigned long len, vm_flags_t vm_flags,
			   unsigned long pgoff, struct list_head *uf)
```

## Page Table

### `follow_page(vma, address, foll_flags)`

1. 大页单独处理；
2. `follow_page_mask`；
3. `follow_p4d/pud/pmd_mask`；
4. `follow_page_pte`。

页表层级：`pgd`（page global directory）、`p4d`（4-level）、`pud`（upper）、`pmd`（middle）、`pte`。

由此可见 Linux 抽象上支持五级页表，其中 `p4d` 可以在不需要五级页表的架构或配置下折叠，退化为四级页表。

## mmu_notifier

```c
/*
 * The notifier chains are protected by mmap_sem and/or the reverse map
 * semaphores. Notifier chains are only changed when all reverse maps and
 * the mmap_sem locks are taken.
 *
 * Therefore notifier chains can only be traversed when either
 *
 * 1. mmap_sem is held.
 * 2. One of the reverse map locks is held (i_mmap_rwsem or anon_vma->rwsem).
 * 3. No other concurrent thread can access the list (release)
 */
struct mmu_notifier {
	struct hlist_node hlist;
	const struct mmu_notifier_ops *ops;
};
```

`mmu_notifier_ops` 注册了一系列回调函数，用于在 CPU 页表发生变化时通知其余子系统（如 HMM，见 [hmm.md](./hmm.md)）。
