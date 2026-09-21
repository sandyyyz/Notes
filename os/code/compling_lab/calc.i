# 0 "calc.c"
# 1 "/home/zoe/workspace/complie_lab//"
# 0 "<built-in>"
# 0 "<command-line>"
# 1 "/usr/include/stdc-predef.h" 1 3 4
# 0 "<command-line>" 2
# 1 "calc.c"
# 1 "calc.h" 1



extern int global_counter;
extern int uninitialized_value;

int add(int a, int b);
int multiply(int a, int b);
void update_counter(int value);
# 2 "calc.c" 2


int global_counter = 10;


int uninitialized_value;


static int internal_state = 3;


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





    if (module_name[0] == '\0')
        global_counter = 0;
}
