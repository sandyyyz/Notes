# Linux kernel GDB initialization for QEMU
# Kernel image: /home/huangzs/data/workspace/buildroot/output/build/linux-6.18.7/vmlinux
# QEMU gdbstub: 127.0.0.1:1234

set $VMLINUX = "/home/huangzs/data/workspace/buildroot/output/build/linux-6.18.7/vmlinux"
set $KERNEL_SRC = "/home/huangzs/data/workspace/buildroot/output/build/linux-6.18.7"

# Basic interaction settings
set confirm off
set pagination on
set height 25
set width 0
set breakpoint pending on
set history save on
set history filename ~/.gdb_history
set history size 10000
set verbose off

# Output and source display
set print pretty on
set print object on
set print array on
set print array-indexes on
set print elements 0
set print repeats 0
set print frame-arguments all
set listsize 20
set disassemble-next-line auto

# Do not let a bad pointer read abort a command too early
set unwindonsignal on

# Load the uncompressed kernel image and symbols
file /home/huangzs/data/workspace/buildroot/output/build/linux-6.18.7/vmlinux

# Permit and load Linux kernel GDB helper commands, such as lx-symbols,
# lx-dmesg, lx-ps, lx-lsmod and lx-version.
add-auto-load-safe-path /home/huangzs/data/workspace/buildroot/output/build/linux-6.18.7/scripts/gdb/vmlinux-gdb.py
source /home/huangzs/data/workspace/buildroot/output/build/linux-6.18.7/scripts/gdb/vmlinux-gdb.py

# Connect to the QEMU gdbstub. Start QEMU with -S -gdb tcp::1234
# (or the equivalent -s option for port 1234).
target remote 127.0.0.1:1234

# Convenient aliases
command alias -a c = continue
command alias -a si = stepi
command alias -a ni = nexti
command alias -a bt = backtrace
command alias -a i = info

# Reconnect after QEMU has been restarted.
define reconnect
    dont-repeat
    disconnect
    target remote 127.0.0.1:1234
end
document reconnect
Disconnect from and reconnect to the QEMU gdbstub at 127.0.0.1:1234.
end

# Show the current instruction and a compact register set.
define kcontext
    dont-repeat
    printf "\\n--- Backtrace ---\\n"
    backtrace
    printf "\\n--- Current instruction ---\\n"
    x/10i $pc
    printf "\\n--- Registers ---\\n"
    info registers
end
document kcontext
Show the current kernel backtrace, nearby instructions, and registers.
end

# Load symbols for currently loaded kernel modules after the guest has booted.
define kmodules
    dont-repeat
    lx-symbols
end
document kmodules
Load symbols for the running kernel and currently loaded modules using lx-symbols.
end

# Enable GDB TUI mode
tui enable

# Top: source + assembly
# Bottom: command + general-purpose registers
# BUG!! cannot split registers and commandline
# tui new-layout kall {-horizontal src 1 asm 1} 2 status 0 {-horizontal cmd 1 regs 1} 1

# layout kall
# Set a new layout with src and asm and regs split horizonatally
tui new-layout allsplit \
{-horizontal src 3 asm 3 regs 2} 2 \
status 0 \
cmd 1

# Set a layout with src and asm split horizontailly
tui new-layout hsplit \
{-horizontal src 1 asm 1} 2 \
status 0 \
cmd 1

# show general regs
tui reg general
# Display source and assembly simultaneously
# layout split

layout hsplit
# Keep command input focus in the command window
focus cmd

# Use Intel syntax on x86/x86_64.
# For ARM, AArch64 or RISC-V, remove this line.
set disassembly-flavor intel

# Automatically display the next instruction while stepping
set disassemble-next-line on

# Display source line information mixed with assembly
set print asm-demangle on
# Stop at useful early kernel entry points. Run manually when needed:
break start_kernel
#   break rest_init
#   break panic
#   break __warn

printf "Loaded Linux kernel symbols from %s\\n", $VMLINUX
# printf "Connected to QEMU gdbstub at %s\\n", $POR
# printf "Useful commands: kcontext, kmodules, lx-dmesg, lx-ps, lx-lsmod, reconnect\\n"

