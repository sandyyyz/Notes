#include <stdio.h>
#include "calc.h"

void binding_checkpoint(int phase)
{
    (void)phase;
}

int main(void)
{
    binding_checkpoint(0);
    int first = add(6, 7);
    binding_checkpoint(1);
    int second = add(6, 7);
    binding_checkpoint(2);
    printf("first=%d second=%d\n", first, second);
    return first == 13 && second == 13 ? 0 : 1;
}
