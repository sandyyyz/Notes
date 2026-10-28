CC := gcc
AR := ar
SRC := ../src
OUT := ../output/program-execution-walkthrough
CFLAGS := -std=c11 -Wall -Wextra -Wpedantic -O0 -g
PIE := -fPIE
LINK := -Wl,-z,relro
RPATH := -Wl,--enable-new-dtags,-rpath,'$$ORIGIN'

.PHONY: all stages optional-static

all: stages $(OUT)/elf_archive $(OUT)/elf_shared $(OUT)/bind_lazy \
	$(OUT)/bind_now $(OUT)/startup

$(OUT):
	mkdir -p $@

stages: $(OUT)/main.i $(OUT)/main.s $(OUT)/main.o $(OUT)/calc.o

$(OUT)/main.i: $(SRC)/main.c $(SRC)/calc.h | $(OUT)
	$(CC) $(CFLAGS) $(PIE) -E $< -o $@

$(OUT)/main.s: $(SRC)/main.c $(SRC)/calc.h | $(OUT)
	$(CC) $(CFLAGS) $(PIE) -S $< -o $@

$(OUT)/main.o: $(SRC)/main.c $(SRC)/calc.h | $(OUT)
	$(CC) $(CFLAGS) $(PIE) -c $< -o $@

$(OUT)/calc.o: $(SRC)/calc.c $(SRC)/calc.h | $(OUT)
	$(CC) $(CFLAGS) $(PIE) -c $< -o $@

$(OUT)/calc.pic.o: $(SRC)/calc.c $(SRC)/calc.h | $(OUT)
	$(CC) $(CFLAGS) -fPIC -c $< -o $@

$(OUT)/libcalc.a: $(OUT)/calc.o
	$(AR) rcs $@ $^

$(OUT)/libcalc.so: $(OUT)/calc.pic.o
	$(CC) -shared $(LINK) -Wl,-z,now,-soname,libcalc.so $^ -o $@

$(OUT)/elf_archive: $(OUT)/main.o $(OUT)/libcalc.a
	$(CC) -pie $(LINK) -Wl,-z,now,-Map,$@.map $^ -o $@

$(OUT)/elf_shared: $(OUT)/main.o $(OUT)/libcalc.so
	$(CC) -pie $(LINK) -Wl,-z,now,-Map,$@.map $(RPATH) $^ -o $@

$(OUT)/binding.o: binding.c $(SRC)/calc.h | $(OUT)
	$(CC) $(CFLAGS) -fno-pie -fplt -I$(SRC) -c $< -o $@

$(OUT)/bind_lazy: $(OUT)/binding.o $(OUT)/libcalc.so
	$(CC) -no-pie $(LINK) -Wl,-z,lazy $(RPATH) $^ -o $@

$(OUT)/bind_now: $(OUT)/binding.o $(OUT)/libcalc.so
	$(CC) -no-pie $(LINK) -Wl,-z,now $(RPATH) $^ -o $@

$(OUT)/library_init.o: library_init.c | $(OUT)
	$(CC) $(CFLAGS) -fPIC -c $< -o $@

$(OUT)/libcalc_init.so: $(OUT)/calc.pic.o $(OUT)/library_init.o
	$(CC) -shared $(LINK) -Wl,-z,now,-soname,libcalc_init.so $^ -o $@

$(OUT)/startup.o: startup.c $(SRC)/calc.h | $(OUT)
	$(CC) $(CFLAGS) $(PIE) -I$(SRC) -c $< -o $@

$(OUT)/startup: $(OUT)/startup.o $(OUT)/libcalc_init.so
	$(CC) -pie $(LINK) -Wl,-z,now $(RPATH) $^ -o $@

optional-static: $(OUT)/elf_fully_static

$(OUT)/elf_fully_static: $(OUT)/main.o $(OUT)/libcalc.a
	$(CC) -static -no-pie $^ -o $@
