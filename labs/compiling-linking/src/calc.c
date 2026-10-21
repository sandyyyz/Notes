#include "calc.h"

/* 已初始化全局变量，通常位于 .data */
int global_counter = 10;

/* 未初始化全局变量，通常位于 .bss */
int uninitialized_value;

/* 文件内可见符号，通常具有 LOCAL 绑定属性 */
static int internal_state = 3;

/* 字符串常量通常位于 .rodata */
static const char module_name[] = "calc";

int add(int a, int b)
{
    return a + b;
}

int multiply(int a, int b)
{
    return a * b;
}

void update_counter(int value)
{
    global_counter += value;
    uninitialized_value = internal_state;

    /*
     * 防止 module_name 在优化时被完全删除。
     * 条件通常不会成立，但编译器仍需保留该对象。
     */
    if (module_name[0] == '\0')
        global_counter = 0;
}
