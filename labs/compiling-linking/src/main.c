#include <stdio.h>
#include "calc.h"

/* main.o 自己的已初始化数据 */
static int local_data = 100;

/* main.o 自己的只读数据 */
static const char message[] = "ELF compilation and linking laboratory";

int main(void)
{
    int x = 6;
    int y = 7;

    printf("%s\n", message);
    printf("add(%d, %d) = %d\n", x, y, add(x, y));
    printf("multiply(%d, %d) = %d\n", x, y, multiply(x, y));

    update_counter(local_data);

    printf("global_counter = %d\n", global_counter);
    printf("uninitialized_value = %d\n", uninitialized_value);

    return 0;
}
