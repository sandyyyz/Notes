#include <stdio.h>

__attribute__((constructor))
static void library_ctor(void)
{
    puts("library constructor");
}
