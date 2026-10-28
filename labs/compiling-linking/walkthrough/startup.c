#include <stdio.h>
#include "calc.h"

__attribute__((constructor))
static void program_ctor(void)
{
    puts("program constructor");
}

int main(void)
{
    int result = add(6, 7);
    printf("main: add=%d\n", result);
    return result == 13 ? 0 : 1;
}
