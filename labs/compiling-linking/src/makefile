CC      := gcc
AR      := ar

CPPFLAGS := -I.
CFLAGS   := -std=c11 -Wall -Wextra -Wpedantic -O0 -g
PICFLAGS := -fPIC

TARGET_STATIC := elf_static
TARGET_SHARED := elf_shared
STATIC_LIB    := libcalc.a
SHARED_LIB    := libcalc.so

.PHONY: all stages static shared inspect run clean

all: stages static shared

# ==================== 编译中间阶段 ====================

stages: main.i main.s main.o calc.i calc.s calc.o

# 预处理：.c -> .i
main.i: main.c calc.h
	$(CC) $(CPPFLAGS) $(CFLAGS) -E main.c -o $@

calc.i: calc.c calc.h
	$(CC) $(CPPFLAGS) $(CFLAGS) -E calc.c -o $@

# 编译：.c -> .s
main.s: main.c calc.h
	$(CC) $(CPPFLAGS) $(CFLAGS) -S main.c -o $@

calc.s: calc.c calc.h
	$(CC) $(CPPFLAGS) $(CFLAGS) -S calc.c -o $@

# 汇编：.c -> .o
main.o: main.c calc.h
	$(CC) $(CPPFLAGS) $(CFLAGS) -c main.c -o $@

calc.o: calc.c calc.h
	$(CC) $(CPPFLAGS) $(CFLAGS) -c calc.c -o $@

# ==================== 静态库及静态链接 ====================

$(STATIC_LIB): calc.o
	$(AR) rcs $@ $^

static: $(TARGET_STATIC)

$(TARGET_STATIC): main.o $(STATIC_LIB)
	$(CC) main.o -L. -lcalc \
		-Wl,-Map=$(TARGET_STATIC).map \
		-o $@

# ==================== 共享库及动态链接 ====================

calc.pic.o: calc.c calc.h
	$(CC) $(CPPFLAGS) $(CFLAGS) $(PICFLAGS) -c calc.c -o $@

$(SHARED_LIB): calc.pic.o
	$(CC) -shared -Wl,-soname,$(SHARED_LIB) \
		-o $@ $^

shared: $(TARGET_SHARED)

$(TARGET_SHARED): main.o $(SHARED_LIB)
	$(CC) main.o -L. -lcalc \
		-Wl,-rpath,'$$ORIGIN' \
		-Wl,-Map=$(TARGET_SHARED).map \
		-o $@

# ==================== 辅助目标 ====================

run: all
	@echo "===== static-library version ====="
	./$(TARGET_STATIC)
	@echo
	@echo "===== shared-library version ====="
	./$(TARGET_SHARED)

inspect: all
	file main.o $(STATIC_LIB) $(SHARED_LIB) \
		$(TARGET_STATIC) $(TARGET_SHARED)
	readelf -h main.o
	readelf -S main.o
	readelf -s main.o
	readelf -r main.o

clean:
	rm -f *.i *.s *.o *.a *.so
	rm -f $(TARGET_STATIC) $(TARGET_SHARED)
	rm -f *.map
