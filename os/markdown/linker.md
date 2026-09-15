# GNU linker

binutils-gdb:  

```
binutils-gdb/
├── ld/ 链接器主体
│ ├── ldmain.c ld 主入口和总体初始化
│ ├── ldlang.c linker script、输入输出节布局
│ ├── ldfile.c 输入文件和库搜索
│ ├── ldemul.c 目标平台 emulation
│ └── emultempl/ ELF 平台链接模板
├── bfd/ 统一处理不同目标文件格式
│ ├── elf.c 通用 ELF 处理
│ ├── elflink.c ELF 符号解析与链接逻辑
│ ├── elf64-x86-64.c x86-64 重定位、PLT/GOT
│ └── section.c BFD section 抽象
├── gas/ GNU汇编器
│ ├── write.c 汇编结果写入目标文件
│ ├── symbols.c 汇编器符号处理
│ ├── config/
│ │ └── tc-i386.c x86 汇编与 fixup 生成
│ └── config/
│ └── obj-elf.c ELF 目标格式处理
└── include/
 └── elf/ elf和体系结构相关定义
 └── x86-64.h x86-64 重定位类型定义
```

main.o的relocation section:  

```
zoe@HUANGZS7-2V8W0R:~/workspace/compling_lab$ readelf -r main.o

Relocation section '.rela.text' at offset 0x958 contains 16 entries:
  Offset          Info           Type           Sym. Value    Sym. Name + Addend
00000000001d  000500000002 R_X86_64_PC32     0000000000000000 .rodata - 4
000000000025  000d00000004 R_X86_64_PLT32    0000000000000000 puts - 4
000000000034  000e00000004 R_X86_64_PLT32    0000000000000000 add - 4
000000000045  000500000002 R_X86_64_PC32     0000000000000000 .rodata + 23
000000000052  000f00000004 R_X86_64_PLT32    0000000000000000 printf - 4
000000000061  001000000004 R_X86_64_PLT32    0000000000000000 multiply - 4
000000000072  000500000002 R_X86_64_PC32     0000000000000000 .rodata + 35
00000000007f  000f00000004 R_X86_64_PLT32    0000000000000000 printf - 4
000000000085  000300000002 R_X86_64_PC32     0000000000000000 .data - 4
00000000008c  001100000004 R_X86_64_PLT32    0000000000000000 update_counter - 4
000000000092  001200000002 R_X86_64_PC32     0000000000000000 global_counter - 4
00000000009b  000500000002 R_X86_64_PC32     0000000000000000 .rodata + 4c
0000000000a8  000f00000004 R_X86_64_PLT32    0000000000000000 printf - 4
0000000000ae  001300000002 R_X86_64_PC32     0000000000000000 uninitialized_value - 4
0000000000b7  000500000002 R_X86_64_PC32     0000000000000000 .rodata + 61
0000000000c4  000f00000004 R_X86_64_PLT32    0000000000000000 printf - 4

Relocation section '.rela.debug_info' at offset 0xad8 contains 25 entries:
  Offset          Info           Type           Sym. Value    Sym. Name + Addend
000000000008  00080000000a R_X86_64_32       0000000000000000 .debug_abbrev + 0
00000000000d  000a0000000a R_X86_64_32       0000000000000000 .debug_str + 76
000000000012  000b0000000a R_X86_64_32       0000000000000000 .debug_line_str + 0
000000000016  000b0000000a R_X86_64_32       0000000000000000 .debug_line_str + 7
00000000001a  000200000001 R_X86_64_64       0000000000000000 .text + 0
00000000002a  00090000000a R_X86_64_32       0000000000000000 .debug_line + 0
000000000031  000a0000000a R_X86_64_32       0000000000000000 .debug_str + 29
000000000038  000a0000000a R_X86_64_32       0000000000000000 .debug_str + 8
00000000003f  000a0000000a R_X86_64_32       0000000000000000 .debug_str + 63
000000000046  000a0000000a R_X86_64_32       0000000000000000 .debug_str + 129
00000000004d  000a0000000a R_X86_64_32       0000000000000000 .debug_str + 14d
000000000054  000a0000000a R_X86_64_32       0000000000000000 .debug_str + 143
000000000062  000a0000000a R_X86_64_32       0000000000000000 .debug_str + 111
000000000069  000a0000000a R_X86_64_32       0000000000000000 .debug_str + 4f
000000000073  000a0000000a R_X86_64_32       0000000000000000 .debug_str + 11a
00000000007d  000a0000000a R_X86_64_32       0000000000000000 .debug_str + 15
000000000087  000a0000000a R_X86_64_32       0000000000000000 .debug_str + 44
000000000093  000300000001 R_X86_64_64       0000000000000000 .data + 0
0000000000b1  000a0000000a R_X86_64_32       0000000000000000 .debug_str + 0
0000000000bd  000500000001 R_X86_64_64       0000000000000000 .rodata + 0
0000000000c6  000a0000000a R_X86_64_32       0000000000000000 .debug_str + 54
0000000000d8  000a0000000a R_X86_64_32       0000000000000000 .debug_str + 3b
0000000000f3  000a0000000a R_X86_64_32       0000000000000000 .debug_str + 13c
00000000012c  000a0000000a R_X86_64_32       0000000000000000 .debug_str + 71
000000000137  000200000001 R_X86_64_64       0000000000000000 .text + 0

Relocation section '.rela.debug_aranges' at offset 0xd30 contains 2 entries:
  Offset          Info           Type           Sym. Value    Sym. Name + Addend
000000000006  00070000000a R_X86_64_32       0000000000000000 .debug_info + 0
000000000010  000200000001 R_X86_64_64       0000000000000000 .text + 0

Relocation section '.rela.debug_line' at offset 0xd60 contains 7 entries:
  Offset          Info           Type           Sym. Value    Sym. Name + Addend
000000000022  000b0000000a R_X86_64_32       0000000000000000 .debug_line_str + 27
000000000026  000b0000000a R_X86_64_32       0000000000000000 .debug_line_str + 47
000000000030  000b0000000a R_X86_64_32       0000000000000000 .debug_line_str + 54
000000000035  000b0000000a R_X86_64_32       0000000000000000 .debug_line_str + 5b
00000000003a  000b0000000a R_X86_64_32       0000000000000000 .debug_line_str + 62
00000000003f  000b0000000a R_X86_64_32       0000000000000000 .debug_line_str + 69
000000000049  000200000001 R_X86_64_64       0000000000000000 .text + 0

Relocation section '.rela.eh_frame' at offset 0xe08 contains 1 entry:
  Offset          Info           Type           Sym. Value    Sym. Name + Addend
000000000020  000200000002 R_X86_64_PC32     0000000000000000 .text + 0
```

## bfd

under file `elf64-x86-64.c`, function ` elf_x86_64_relocate_section`  

This function is used to `/* Relocate an x86_64 ELF section.  */`  

### `struct bfd_link_info`

holds all the information needed to communicate between CFD and the linker when doing a link.  

```c
/* This structure holds all the information needed to communicate
   between BFD and the linker when doing a link.  */

struct bfd_link_info
{
  /* Output type.  */
  ENUM_BITFIELD (output_type) type : 2;

  /* TRUE if BFD should pre-bind symbols in a shared object.  */
  unsigned int symbolic: 1;

  /* TRUE if BFD should export all symbols in the dynamic symbol table
     of an executable, rather than only those used.  */
  unsigned int export_dynamic: 1;

  /* TRUE if a default symbol version should be created and used for
     exported symbols.  */
  unsigned int create_default_symver: 1;

  /* TRUE if unreferenced sections should be removed.  */
  unsigned int gc_sections: 1;

  /* TRUE if exported symbols should be kept during section gc.  */
  unsigned int gc_keep_exported: 1;

  /* TRUE if every symbol should be reported back via the notice
     callback.  */
  unsigned int notice_all: 1;

  /* TRUE if the LTO plugin is active.  */
  unsigned int lto_plugin_active: 1;

  /* TRUE if all LTO IR symbols have been read.  */
  unsigned int lto_all_symbols_read : 1;

  /* TRUE if global symbols in discarded sections should be stripped.  */
  unsigned int strip_discarded: 1;

  /* TRUE if all data symbols should be dynamic.  */
  unsigned int dynamic_data: 1;

  /* TRUE if section groups should be resolved.  */
  unsigned int resolve_section_groups: 1;

  /* Set if output file is big-endian, or if that is unknown, from
     the command line or first input file endianness.  */
  unsigned int big_endian : 1;

  /* Which symbols to strip.  */
  ENUM_BITFIELD (bfd_link_strip) strip : 2;

  /* Which local symbols to discard.  */
  ENUM_BITFIELD (bfd_link_discard) discard : 2;

  /* Whether to generate ELF common symbols with the STT_COMMON type.  */
  ENUM_BITFIELD (bfd_link_elf_stt_common) elf_stt_common : 2;

  /* Criteria for skipping symbols when determining
     whether to include an object from an archive.  */
  ENUM_BITFIELD (bfd_link_common_skip_ar_symbols) common_skip_ar_symbols : 2;

  /* What to do with unresolved symbols in an object file.
     When producing executables the default is GENERATE_ERROR.
     When producing shared libraries the default is IGNORE.  The
     assumption with shared libraries is that the reference will be
     resolved at load/execution time.  */
  ENUM_BITFIELD (report_method) unresolved_syms_in_objects : 2;

  /* What to do with unresolved symbols in a shared library.
     The same defaults apply.  */
  ENUM_BITFIELD (report_method) unresolved_syms_in_shared_libs : 2;

  /* TRUE if unresolved symbols are to be warned, rather than errored.  */
  unsigned int warn_unresolved_syms: 1;

  /* TRUE if shared objects should be linked directly, not shared.  */
  unsigned int static_link: 1;

  /* TRUE if symbols should be retained in memory, FALSE if they
     should be freed and reread.  */
  unsigned int keep_memory: 1;

  /* TRUE if BFD should generate relocation information in the final
     executable.  */
  unsigned int emitrelocations: 1;

  /* TRUE if PT_GNU_RELRO segment should be created.  */
  unsigned int relro: 1;

  /* TRUE if DT_RELR should be enabled for compact relative
     relocations.  */
  unsigned int enable_dt_relr: 1;

  /* TRUE if separate code segment should be created.  */
  unsigned int separate_code: 1;

  /* TRUE if only one read-only, non-code segment should be created.  */
  unsigned int one_rosegment: 1;

  /* TRUE if GNU_PROPERTY_MEMORY_SEAL should be generated.  */
  unsigned int memory_seal: 1;

  /* Nonzero if .eh_frame_hdr section and PT_GNU_EH_FRAME ELF segment
     should be created.  1 for DWARF2 tables, 2 for compact tables.  */
  unsigned int eh_frame_hdr_type: 2;

  /* What to do with DT_TEXTREL in output.  */
  ENUM_BITFIELD (textrel_check_method) textrel_check: 2;

  /* TRUE if .hash section should be created.  */
  unsigned int emit_hash: 1;

  /* TRUE if .gnu.hash section should be created.  */
  unsigned int emit_gnu_hash: 1;

  /* If TRUE reduce memory overheads, at the expense of speed. This will
     cause map file generation to use an O(N^2) algorithm and disable
     caching ELF symbol buffer.  */
  unsigned int reduce_memory_overheads: 1;

  /* TRUE if the output file should be in a traditional format.  This
     is equivalent to the setting of the BFD_TRADITIONAL_FORMAT flag
     on the output file, but may be checked when reading the input
     files.  */
  unsigned int traditional_format: 1;

  /* TRUE if non-PLT relocs should be merged into one reloc section
     and sorted so that relocs against the same symbol come together.  */
  unsigned int combreloc: 1;

  /* TRUE if a default symbol version should be created and used for
     imported symbols.  */
  unsigned int default_imported_symver: 1;

  /* TRUE if the new ELF dynamic tags are enabled. */
  unsigned int new_dtags: 1;

  /* FALSE if .eh_frame unwind info should be generated for PLT and other
     linker created sections, TRUE if it should be omitted.  */
  unsigned int no_ld_generated_unwind_info: 1;

  /* TRUE if no .sframe stack trace info should be generated for the output.
     This includes linker generated SFrame info as well.  */
  unsigned int discard_sframe: 1;

  /* TRUE if BFD should generate a "task linked" object file,
     similar to relocatable but also with globals converted to
     statics.  */
  unsigned int task_link: 1;

  /* TRUE if ok to have multiple definitions, without warning.  */
  unsigned int allow_multiple_definition: 1;

  /* TRUE if multiple definition of absolute symbols (eg. from -R) should
     be reported.  */
  unsigned int prohibit_multiple_definition_absolute: 1;

  /* TRUE if multiple definitions should only warn.  */
  unsigned int warn_multiple_definition: 1;

  /* TRUE if ok to have version with no definition.  */
  unsigned int allow_undefined_version: 1;

  /* TRUE if some symbols have to be dynamic, controlled by
     --dynamic-list command line options.  */
  unsigned int dynamic: 1;

  /* Set if the "-z execstack" option has been used to request that a
     PT_GNU_STACK segment should be created with PF_R, PF_W and PF_X
     flags set.

     Note - if performing a relocatable link then a .note.GNU-stack
     section will be created instead, if one does not exist already.
     The section will have the SHF_EXECINSTR flag bit set.  */
  unsigned int execstack: 1;

  /* Set if the "-z noexecstack" option has been used to request that a
     PT_GNU_STACK segment should be created with PF_R and PF_W flags.  Or
     a non-executable .note.GNU-stack section for relocateable links.

     Note - this flag is not quite orthogonal to execstack, since both
     of these flags can be 0.  In this case a stack segment can still
     be created, but it will only have the PF_X flag bit set if one or
     more of the input files contains a .note.GNU-stack section with the
     SHF_EXECINSTR flag bit set, or if the default behaviour for the
     architecture is to create executable stacks.

     The execstack and noexecstack flags should never both be 1.  */
  unsigned int noexecstack: 1;

  /* Tri-state variable:
     0 => do not warn when creating an executable stack.
     1 => always warn when creating an executable stack (for any reason).
     2 => only warn when an executable stack has been requested an object
          file and execstack is 0 or noexecstack is 1.
     3 => not used.  */
  unsigned int warn_execstack: 2;
  /* TRUE if a warning generated because of warn_execstack should be instead
     be treated as an error.  */
  unsigned int error_execstack: 1;

  /* TRUE if warnings should NOT be generated for TLS segments with eXecute
     permission or LOAD segments with RWX permissions.  */
  unsigned int no_warn_rwx_segments: 1;
  /* TRUE if the user gave either --warn-rwx-segments or
     --no-warn-rwx-segments on the linker command line.  */
  unsigned int user_warn_rwx_segments: 1;
  /* TRUE if warnings generated when no_warn_rwx_segements is 0 should
     instead be treated as errors.  */
  unsigned int warn_is_error_for_rwx_segments: 1;

  /* TRUE if the stack can be made executable because of the absence of a
     .note.GNU-stack section in an input file.  Note - even if this field
     is set, some targets may choose to ignore the setting and not create
     an executable stack.  */
  unsigned int default_execstack : 1;
  
  /* TRUE if we want to produce optimized output files.  This might
     need much more time and therefore must be explicitly selected.  */
  unsigned int optimize: 1;

  /* TRUE if we want to skip optional steps during linking.  This can
     include section merging for example.  This is effectively the opposite
     of the 'optimize' field, and both should not be TRUE at the same time.  */
  unsigned int skip_optional: 1;

  /* TRUE if user should be informed of removed unreferenced sections.  */
  unsigned int print_gc_sections: 1;

  /* TRUE if we should warn alternate ELF machine code.  */
  unsigned int warn_alternate_em: 1;

  /* TRUE if the linker script contained an explicit PHDRS command.  */
  unsigned int user_phdrs: 1;

  /* TRUE if program headers ought to be loaded.  */
  unsigned int load_phdrs: 1;

  /* TRUE if generation of .interp/PT_INTERP should be suppressed.  */
  unsigned int nointerp: 1;

  /* TRUE if common symbols should be treated as undefined.  */
  unsigned int inhibit_common_definition : 1;

  /* TRUE if "-Map map" is passed to linker.  */
  unsigned int has_map_file : 1;

  /* TRUE if "--enable-non-contiguous-regions" is passed to the
     linker.  */
  unsigned int non_contiguous_regions : 1;

  /* TRUE if "--enable-non-contiguous-regions-warnings" is passed to
     the linker.  */
  unsigned int non_contiguous_regions_warnings : 1;

  /* TRUE if all symbol names should be unique.  */
  unsigned int unique_symbol : 1;

  /* TRUE if maxpagesize is set on command-line.  */
  unsigned int maxpagesize_is_set : 1;

  /* TRUE if commonpagesize is set on command-line.  */
  unsigned int commonpagesize_is_set : 1;

  /* Char that may appear as the first char of a symbol, but should be
     skipped (like symbol_leading_char) when looking up symbols in
     wrap_hash.  Used by PowerPC Linux for 'dot' symbols.  */
  char wrap_char;

  /* Separator between archive and filename in linker script filespecs.  */
  char path_separator;

  /* Default stack size.  Zero means default (often zero itself), -1
     means explicitly zero-sized.  */
  bfd_signed_vma stacksize;

  /* Enable or disable target specific optimizations.

     Not all targets have optimizations to enable.

     Normally these optimizations are disabled by default but some targets
     prefer to enable them by default.  So this field is a tri-state variable.
     The values are:

     zero: Enable the optimizations (either from --relax being specified on
       the command line or the backend's before_allocation emulation function.

     positive: The user has requested that these optimizations be disabled.
       (Via the --no-relax command line option).

     negative: The optimizations are disabled.  (Set when initializing the
       args_type structure in ldmain.c:main.  */
  signed int disable_target_specific_optimizations;

  /* Function callbacks.  */
  const struct bfd_link_callbacks *callbacks;

  /* Hash table handled by BFD.  */
  struct bfd_link_hash_table *hash;

  /* Hash table of symbols to keep.  This is NULL unless strip is
     strip_some.  */
  struct bfd_hash_table *keep_hash;

  /* Hash table of symbols to report back via the notice callback.  If
     this is NULL, and notice_all is FALSE, then no symbols are
     reported back.  */
  struct bfd_hash_table *notice_hash;

  /* Hash table of symbols which are being wrapped (the --wrap linker
     option).  If this is NULL, no symbols are being wrapped.  */
  struct bfd_hash_table *wrap_hash;

  /* Hash table of symbols which may be left unresolved during
     a link.  If this is NULL, no symbols can be left unresolved.  */
  struct bfd_hash_table *ignore_hash;

  /* The output BFD.  */
  bfd *output_bfd;

  /* The import library generated.  */
  bfd *out_implib_bfd;

  /* The list of input BFD's involved in the link.  These are chained
     together via the link.next field.  */
  bfd *input_bfds;
  bfd **input_bfds_tail;

  /* If a symbol should be created for each input BFD, this is section
     where those symbols should be placed.  It must be a section in
     the output BFD.  It may be NULL, in which case no such symbols
     will be created.  This is to support CREATE_OBJECT_SYMBOLS in the
     linker command language.  */
  asection *create_object_symbols_section;

  /* List of global symbol names that are starting points for marking
     sections against garbage collection.  */
  struct bfd_sym_chain *gc_sym_list;

  /* If a base output file is wanted, then this points to it */
  void *base_file;

  /* The function to call when the executable or shared object is
     loaded.  */
  const char *init_function;

  /* The function to call when the executable or shared object is
     unloaded.  */
  const char *fini_function;

  /* Number of relaxation passes.  Usually only one relaxation pass
     is needed.  But a backend can have as many relaxation passes as
     necessary.  During bfd_relax_section call, it is set to the
     current pass, starting from 0.  */
  int relax_pass;

  /* Number of relaxation trips.  This number is incremented every
     time the relaxation pass is restarted due to a previous
     relaxation returning true in *AGAIN.  */
  int relax_trip;

  /* > 0 to treat protected data defined in the shared library as
     reference external.  0 to treat it as internal.  -1 to let
     backend to decide.  */
  int extern_protected_data;

  /* 1 to make undefined weak symbols dynamic when building a dynamic
     object.  0 to resolve undefined weak symbols to zero.  -1 to let
     the backend decide.  */
  int dynamic_undefined_weak;

  /* Non-zero if auto-import thunks for DATA items in pei386 DLLs
     should be generated/linked against.  Set to 1 if this feature
     is explicitly requested by the user, -1 if enabled by default.  */
  int pei386_auto_import;

  /* Non-zero if runtime relocs for DATA items with non-zero addends
     in pei386 DLLs should be generated.  Set to 1 if this feature
     is explicitly requested by the user, -1 if enabled by default.  */
  int pei386_runtime_pseudo_reloc;

  /* How many spare .dynamic DT_NULL entries should be added?  */
  unsigned int spare_dynamic_tags;

  /* GNU_PROPERTY_1_NEEDED_INDIRECT_EXTERN_ACCESS control:
       > 1: Turn on by -z indirect-extern-access or by backend.
      == 1: Turn on by an input.
         0: Turn off.
       < 0: Turn on if it is set on any inputs or let backend to
	    decide.  */
  int indirect_extern_access;

  /* Non-zero if executable should not contain copy relocs.
       > 1: Implied by indirect_extern_access.
      == 1: Turn on by -z nocopyreloc.
         0: Turn off.
    Setting this to non-zero may result in a non-sharable text
    segment.  */
  int nocopyreloc;

  /* Pointer to the GNU_PROPERTY_1_NEEDED property in memory.  */
  bfd_byte *needed_1_p;

  /* May be used to set DT_FLAGS for ELF. */
  bfd_vma flags;

  /* May be used to set DT_FLAGS_1 for ELF. */
  bfd_vma flags_1;

  /* May be used to set DT_GNU_FLAGS_1 for ELF. */
  bfd_vma gnu_flags_1;

  /* TRUE if references to __start_/__stop_ synthesized symbols do not
     specially retain C identifier named sections.  */
  int start_stop_gc;

  /* May be used to set ELF visibility for __start_* / __stop_.  */
  unsigned int start_stop_visibility;

  /* The maximum page size for ELF.  */
  bfd_vma maxpagesize;

  /* The common page size for ELF.  */
  bfd_vma commonpagesize;

  /* Start and end of RELRO region.  */
  bfd_vma relro_start, relro_end;

  /* List of symbols should be dynamic.  */
  struct bfd_elf_dynamic_list *dynamic_list;

  /* The version information.  */
  struct bfd_elf_version_tree *version_info;

  /* Size of cache.  Backend can use it to keep strace cache size.   */
  bfd_size_type cache_size;

  /* The maximum cache size.  Backend can use cache_size and and
     max_cache_size to decide if keep_memory should be honored.  */
  bfd_size_type max_cache_size;
};

/* Some forward-definitions used by some callbacks.  */
```

该结构体的绝大部分内容是对**链接策略/规则**的抽象：

- 输出类型与格式（`type`、`big_endian`、`traditional_format`）
- 符号处理规则（`strip`、`discard`、`symbolic`、`allow_multiple_definition`、未解析符号策略）
- 段/程序头生成规则（`relro`、`execstack`、`separate_code`、`eh_frame_hdr_type`）
- 优化与裁剪策略（`gc_sections`、`optimize`、relax 相关字段）

`bfd_link_info` 是**链接过程的状态机**：它以引用方式关联输入/输出文件，以配置字段表达链接策略，以哈希表记录符号解析的中间状态，并通过回调与前端通信。

即：

| 维度 | 抽象程度 |
|------|---------|
| 链接策略（怎么链） | **完整抽象**（结构体主体） |
| 符号解析状态 | **完整抽象**（`hash` 等哈希表） |
| 输入文件内容（链什么） | **仅引用**（`input_bfds` 指针链） |

对于目标文件的内容，输入目标文件本身并不被该结构体“抽象”或管理，它只持有**引用**：

```c
bfd *output_bfd;        /* 输出目标 */
bfd *input_bfds;        /* 输入文件链表头（仅指针） */
bfd **input_bfds_tail;
```

目标文件的内容（节、符号表、重定位）由各 `bfd` 对象自身描述。`bfd_link_info` 对“链接什么”的抽象仅体现在**符号层面**——`hash` 哈希表记录了所有输入文件符号的解析状态。

### struct elf_internal_rela

```c
/* Relocation Entries */

typedef struct elf_internal_rela {
  bfd_vma	r_offset;	/* Location at which to apply the action */
  bfd_vma	r_info;		/* Index and Type of relocation */
  bfd_vma	r_addend;	/* Constant addend used to compute value */
} Elf_Internal_Rela;
```
该结构体对应elf-spec中的relocation entry

### `elf_x86_hash_table`

`info` 是 `struct bfd_link_info *`，即整个链接过程的全局上下文，里面有一个字段 `hash` 指向链接器的**符号哈希表**（link hash table）。  

链接器在符号解析阶段，会把所有输入目标文件（`.o`）、共享库中出现的**全局符号**都登记到一张哈希表里，每个表项是 `struct elf_link_hash_entry`，记录：

- 符号名、版本信息
- 符号类型：`UNDEFINED` / `DEFINED` / `COMMON` / `INDIRECT` 等
- 定义在哪个 BFD、哪个 section、什么值
- 是否被动态链接使用、是否需要 PLT/GOT 条目等

链接器后续的**符号解析、重定位、动态段（.dynsym/.rela 等）生成**都依赖这张表。  
它是**链接器的全局符号哈希表**（负责符号解析与重定位的核心数据结构），同时携带 x86-64 特有的 PLT/GOT/重定位 section 信息

### `static int elf_x86_64_relocate_section`

```c

/* Relocate an x86_64 ELF section.  */

static int
elf_x86_64_relocate_section (struct bfd_link_info *info,
			     bfd *input_bfd,
			     asection *input_section,
			     bfd_byte *contents,
			     Elf_Internal_Rela *relocs,
			     Elf_Internal_Sym *local_syms,
			     asection **local_sections)
{
  struct elf_x86_link_hash_table *htab;
  Elf_Internal_Shdr *symtab_hdr;
  struct elf_link_hash_entry **sym_hashes;
  bfd_vma *local_got_offsets;
  bfd_vma *local_tlsdesc_gotents;
  Elf_Internal_Rela *rel;
  Elf_Internal_Rela *wrel;
  Elf_Internal_Rela *relend;
  unsigned int plt_entry_size;
  bool status;

  /* Skip if check_relocs or scan_relocs failed.  */
  if (input_section->check_relocs_failed)
    return false;

  htab = elf_x86_hash_table (info, X86_64_ELF_DATA);
  if (htab == NULL)
    return false;

  if (!is_x86_elf (input_bfd, htab))
    {
      bfd_set_error (bfd_error_wrong_format);
      return false;
    }

  plt_entry_size = htab->plt.plt_entry_size;
  symtab_hdr = &elf_symtab_hdr (input_bfd);
  sym_hashes = elf_sym_hashes (input_bfd);
  local_got_offsets = elf_local_got_offsets (input_bfd);
  local_tlsdesc_gotents = elf_x86_local_tlsdesc_gotent (input_bfd);

  _bfd_x86_elf_set_tls_module_base (info);

  status = true;
  rel = wrel = relocs;
  relend = relocs + input_section->reloc_count;
```

> 是 x86-64 ELF 链接器后端**重定位处理函数的初始化部分**：它首先检查输入 section 是否在之前的 `check_relocs`/`scan_relocs` 阶段已失败（失败则直接返回），然后通过 `elf_x86_hash_table` 取出 x86-64 专用的链接哈希表并验证输入 BFD 格式匹配；接着从哈希表和输入 BFD 中提取后续重定位所需的关键数据——PLT 表项大小、符号表头、全局符号哈希数组、本地符号的 GOT 偏移和 TLS descriptor GOT 表项；再设置 TLS 模块基址；最后初始化重定位遍历指针（`rel`/`wrel` 指向重定位数组起点，`relend` 指向终点）并置初始状态为成功，为接下来逐条处理 section 中的重定位项做准备。


