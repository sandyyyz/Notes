# Compiling & linking lab

A small C lab for studying the compilation and linking pipeline.

## Layout

```
.
├── src/          # main.c, calc.c, calc.h + makefile
└── output/       # build artifacts (.i, .s, .o, *.a, *.so, ELF binaries,
                  # linker maps, loader logs) — gitignored
```

## Pipeline

`make` in `src/` runs `main.c` / `calc.c` / `calc.h` through the full
toolchain: preprocessing (`.i`), compilation (`.s`, `.o`), archiving
(`libcalc.a`), shared-library building (`libcalc.so`), static linking
(`elf_static`), and dynamic linking (`elf_shared`), producing linker map
files and a loader log along the way.
