# compaction


## struct compact_control

`compact_control` 是 **Linux Memory Compaction ** 机制中的核心控制结构。memory compaction的目标是解决**external fragmentation**问题：通过把migratable pages迁移到一起，在物理内存中“挤出”大块的连续free pages，从而满足高阶内存分配（如大页 THP、巨型帧缓冲等）的需求。  

```c
/*
 * compact_control is used to track pages being migrated and the free pages
 * they are being migrated to during memory compaction. The free_pfn starts
 * at the end of a zone and migrate_pfn begins at the start. Movable pages
 * are moved to the end of a zone during a compaction run and the run
 * completes when free_pfn <= migrate_pfn
 */
struct compact_control {
	struct list_head freepages;	/* List of free pages to migrate to */
	struct list_head migratepages;	/* List of pages being migrated */
	unsigned long nr_freepages;	/* Number of isolated free pages */
	unsigned long nr_migratepages;	/* Number of pages to migrate */
	unsigned long free_pfn;		/* isolate_freepages search base */
	unsigned long migrate_pfn;	/* isolate_migratepages search base */

	/* Account for isolated anon and file pages */
	unsigned long nr_anon;
	unsigned long nr_file;

	struct zone *zone;
};
```

### 工作原理

该结构采用经典的**双指针扫描**策略：

1. **`free_pfn`** 从 zone 的**末尾**开始，向前扫描，寻找并隔离空闲页（放入 `freepages` 链表）；
2. **`migrate_pfn`** 从 zone 的**开头**开始，向后扫描，寻找并隔离可移动页（放入 `migratepages` 链表）；
3. 将可移动页迁移到空闲页的位置，相当于把可移动数据“推向” zone 尾部；
4. 当两个指针相遇（`free_pfn <= migrate_pfn`）时，本次规整结束。

这样，zone 前部逐渐形成大片连续的空闲内存。

### 字段说明

| 字段 | 类型 | 作用 |
|------|------|------|
| `freepages` | `struct list_head` | 已隔离的**空闲页**链表，作为迁移的目标位置 |
| `migratepages` | `struct list_head` | 已隔离的**待迁移页**链表，即被迁移的源页面 |
| `nr_freepages` | `unsigned long` | 当前已隔离的空闲页数量 |
| `nr_migratepages` | `unsigned long` | 当前已隔离的待迁移页数量 |
| `free_pfn` | `unsigned long` | 空闲页扫描的基准 PFN（从 zone 末尾向前推进） |
| `migrate_pfn` | `unsigned long` | 迁移页扫描的基准 PFN（从 zone 开头向后推进） |
| `nr_anon` | `unsigned long` | 已隔离的**匿名页**计数（用于统计/记账） |
| `nr_file` | `unsigned long` | 已隔离的**文件页**计数（用于统计/记账） |
| `zone` | `struct zone *` | 指向本次compaction操作所针对的内存 zone |

## compact_zone

### 一、作用概述与参数解释


**作用**：内存规整（memory compaction）的**主循环函数**，对单个 zone 执行“双指针夹逼”式页面迁移——把可移动页从 zone 前部搬到后部的空闲页处，最终在 zone 前部“挤出”连续空闲内存，以满足高阶分配（如 THP 大页）的需求。

**参数**：

| 参数 | 类型 | 说明 |
|------|------|------|
| `zone` | `struct zone *` | 本次规整的目标内存 zone |
| `cc` | `struct compact_control *` | 规整控制结构，携带双指针、隔离页链表及计数信息 |

```c
static int compact_zone(struct zone *zone, struct compact_control *cc)
{
	int ret;

	/* Setup to move all movable pages to the end of the zone */
	cc->migrate_pfn = zone->zone_start_pfn;
	cc->free_pfn = cc->migrate_pfn + zone->spanned_pages;
	cc->free_pfn &= ~(pageblock_nr_pages-1);

	migrate_prep_local();

	while ((ret = compact_finished(zone, cc)) == COMPACT_CONTINUE) {
		unsigned long nr_migrate, nr_remaining;

		if (!isolate_migratepages(zone, cc))
			continue;

		nr_migrate = cc->nr_migratepages;
		migrate_pages(&cc->migratepages, compaction_alloc,
						(unsigned long)cc, 0);
		update_nr_listpages(cc);
		nr_remaining = cc->nr_migratepages;

		count_vm_event(COMPACTBLOCKS);
		count_vm_events(COMPACTPAGES, nr_migrate - nr_remaining);
		if (nr_remaining)
			count_vm_events(COMPACTPAGEFAILED, nr_remaining);

		/* Release LRU pages not migrated */
		if (!list_empty(&cc->migratepages)) {
			putback_lru_pages(&cc->migratepages);
			cc->nr_migratepages = 0;
		}

	}

	/* Release free pages and check accounting */
	cc->nr_freepages -= release_freepages(&cc->freepages);
	VM_BUG_ON(cc->nr_freepages != 0);

	return ret;
}
```

### 二、整体流程图

```text
compact_zone(zone, cc)
        │
        ▼
┌─────────────────────────────────────┐
│ 初始化双指针：                        │
│   migrate_pfn = zone 起始 PFN        │
│   free_pfn    = zone 末尾 PFN        │
│                （按 pageblock 对齐）  │
└──────────────────┬──────────────────┘
                   ▼
          migrate_prep_local()   ← 迁移前准备
                   │
                   ▼
        ┌──────────────────────┐
   ┌───►│  compact_finished()? │
   │    └──────┬───────────────┘
   │           │ 返回 COMPACT_CONTINUE
   │           ▼
   │    isolate_migratepages(zone, cc)
   │           │
   │           ├── 隔离失败(返回0) ──► continue（回到循环头）
   │           ▼
   │    migrate_pages(&cc->migratepages,
   │                  compaction_alloc, cc, 0)
   │           │      ← 核心迁移：目标页由
   │           │        compaction_alloc 从空闲链表分配
   │           ▼
   │    update_nr_listpages(cc)   ← 更新剩余页计数
   │           │
   │           ▼
   │    统计 VM 事件：
   │      COMPACTBLOCKS        （规整轮数 +1）
   │      COMPACTPAGES         （成功迁移页数）
   │      COMPACTPAGEFAILED    （失败页数）
   │           │
   │           ▼
   │    migratepages 链表非空？
   │      └─ 是 ─► putback_lru_pages() 归还失败页
   │                nr_migratepages 清零
   │           │
   └───────────┘  （回到循环头）
                    │ 循环退出
                    ▼
        release_freepages(&cc->freepages)
                    │
                    ▼
        VM_BUG_ON(cc->nr_freepages != 0)   ← 记账校验
                    │
                    ▼
                return ret
```

---

### 三、关键调用表

| 函数调用 | 阶段 | 作用 | 备注 |
|----------|------|------|------|
| `migrate_prep_local()` | 初始化 | 迁移前的本地准备（隔离 per-CPU 页列表） | 防止迁移过程被本地分配干扰 |
| `compact_finished()` | 循环控制 | 判断规整是否结束（如 `free_pfn <= migrate_pfn`、已满足分配需求等） | 每轮循环头部检查，及时退出 |
| `isolate_migratepages()` | 隔离 | 从 zone 前部扫描 LRU，隔离可移动页到 `cc->migratepages` | 返回 0 表示未隔离到页，直接进入下一轮 |
| `migrate_pages()` | 迁移 | 执行实际页面迁移 | 回调 `compaction_alloc` 从 `cc->freepages` 中取空闲页作为目标 |
| `compaction_alloc()` | 迁移回调 | 为待迁移页分配目标页 | 由 `migrate_pages` 调用，是空闲页的“供给方” |
| `update_nr_listpages()` | 统计 | 迁移后更新 `cc` 中剩余页计数 | 保证后续统计准确 |
| `putback_lru_pages()` | 清理 | 将迁移失败的页放回 LRU | **必须执行**，否则页面脱离 LRU 泄漏 |
| `release_freepages()` | 收尾 | 释放未用完的空闲页 | 返回释放数，用于对账 |
| `count_vm_event(s)()` | 统计 | 记录 `COMPACTBLOCKS` / `COMPACTPAGES` / `COMPACTPAGEFAILED` | 可通过 `/proc/vmstat` 观测 |

---
## refs

[kernel_internal_compaction](https://kernel-internals.org/mm/compaction/)  
[lwn_memory_compaction](https://lwn.net/Articles/368869/)  
[lwn_proactive_compaction](https://lwn.net/Articles/817905/)
