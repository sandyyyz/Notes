# Notes

Personal study notes on the Linux kernel, operating systems, and related
tooling. Continuously updated.

## Layout

```
.
├── knowledge/                # reusable technical knowledge
│   ├── linux-kernel/         # boot/, execution/, memory/, concurrency/,
│   │                         # tracing-debugging/, logging-console/
│   ├── toolchain/            # compilation/, linking-loading/, binary-format/,
│   │                         # abi-language/
│   ├── hardware/             # firmware-boot/, serial/, memory-interconnect/,
│   │                         # storage/, accelerator/
│   ├── system-tools/          # development/, observability/, containers/,
│   │                         # remote-access/
│   └── ai-tools/             # vim-ai, LLM usage
├── labs/                     # reproducible experiments and code
│   ├── compiling-linking/    # compile/link lab (src/ + output/)
│   └── kernel-debugging/     # .gdbinit + QEMU / container scripts
├── reports/                  # weekly reports and surveys
│   └── lwn-weekly/           # LWN weekly hot topics (YYYY/MM/DD.md)
├── work/                     # work notes — separate git repo, never pushed
├── scripts/                  # repo-level helper scripts (md2pdf.sh)
├── build/                    # generated PDFs (md2pdf.sh output)
├── archive/                  # outdated or unclassified content
├── LICENSE                   # GPLv3
└── README.md
```

## Topics

Notes under `knowledge/`, roughly:

- **linux-kernel** — boot (`system_boot.md`), execution (`execve.md`), memory
  (`mm.md`, `hmm.md`, `swap_memory_reclaim.md`), concurrency (`linux_sync.md`,
  `rwlock_rcu.md`, `hazard_pointer.md`), tracing & debugging (`strace.md`,
  `ftrace.md`, `build_debug_kernel.md`), console & logging (`console.md`,
  `early_prink.md`, `linuxlog.md`)
- **toolchain** — compilation (`compile.md`), linking & loading (`linker.md`,
  `dynamic_link.md`), binary format (`elf.md`), ABI & language (`systemV_abi.md`,
  `__attribute__.md`, `synopsis.md`)
- **hardware** — firmware & boot (`uefi.md`, `pxe_ipxe.md`), serial (`8250uart.md`,
  `baud.md`), memory interconnect (`cxl.md`, `ridger_mimo.md`), storage (`ftl.md`),
  accelerator (`IAA.md`, `QPL.md`)
- **system-tools** — development (`vimrc.md`, `ctags_cscope_index_guide.md`),
  containers (`docker.md`), remote access (`scp.md`)
- **ai-tools** — `vim-ai.md`, `chat.md`

## Labs

- `labs/compiling-linking/` — a small C lab for studying the compilation and
  linking pipeline: `src/main.c` / `src/calc.c` / `src/calc.h` + `makefile`.
  Build artifacts go to `output/` (gitignored).
- `labs/kernel-debugging/` — kernel debugging setup: `.gdbinit` for GDB over
  the QEMU gdbstub, plus helper scripts (see below).

## Reports

LWN weekly hot-topic reports live under `reports/lwn-weekly/YYYY/MM/DD.md`.

## Scripts

| Script | Purpose |
| --- | --- |
| `scripts/md2pdf.sh` | Convert a Markdown file to PDF via Pandoc + XeLaTeX (CJK aware). Output defaults to `build/`. Run `scripts/md2pdf.sh -h` for options. |
| `labs/kernel-debugging/scripts/start-qemu.sh` | Boot a kernel + rootfs in QEMU (`bzImage` / `rootfs.ext2`), with `--serial-only` and `--use-system-qemu` modes. |
| `labs/kernel-debugging/scripts/ubuntu2404.sh` | Create / reuse a per-user `ubuntu:24.04` Docker container for kernel builds. |

## Configs

- `labs/kernel-debugging/.gdbinit` — GDB setup for debugging a Linux kernel
  over the QEMU gdbstub (`127.0.0.1:1234`), with TUI layouts and helper
  commands (`kcontext`, `kmodules`, `reconnect`).
- `archive/vimrcbk` — my `.vimrc` backup (Vundle plugins, cscope integration,
  key mappings).

## Work notes

`work/` is a separate git repository for notes that stay on this machine
(work-in-progress bug investigations, internal tracker IDs, KPI). It is not
pushed and has its own README — see `work/README`.

## License

GPLv3 — see [LICENSE](LICENSE).
