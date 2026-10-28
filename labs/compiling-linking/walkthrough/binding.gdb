set pagination off
set confirm off
set debuginfod enabled off
set disable-randomization off
unset environment LD_BIND_NOW
unset environment LD_BIND_NOT
unset environment LD_LIBRARY_PATH
unset environment LD_PRELOAD
unset environment LD_AUDIT
break binding_checkpoint
run
printf "before first call: "
x/gx $slot
set $before = *(unsigned long *)$slot
continue
printf "after first call: "
x/gx $slot
set $first = *(unsigned long *)$slot
continue
printf "after second call: "
x/gx $slot
set $second = *(unsigned long *)$slot
if $first != $second
    echo ERROR: binding changed after second call\n
    quit 1
end
if $expect_lazy
    if $before == $first
        echo ERROR: lazy slot did not change\n
        quit 1
    end
else
    if $before != $first
        echo ERROR: NOW slot changed at first call\n
        quit 1
    end
end
info symbol $first
continue
