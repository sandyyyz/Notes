	.file	"calc.c"
	.text
.Ltext0:
	.file 0 "/home/zoe/workspace/complie_lab" "calc.c"
	.globl	global_counter
	.data
	.align 4
	.type	global_counter, @object
	.size	global_counter, 4
global_counter:
	.long	10
	.globl	uninitialized_value
	.bss
	.align 4
	.type	uninitialized_value, @object
	.size	uninitialized_value, 4
uninitialized_value:
	.zero	4
	.data
	.align 4
	.type	internal_state, @object
	.size	internal_state, 4
internal_state:
	.long	3
	.section	.rodata
	.type	module_name, @object
	.size	module_name, 5
module_name:
	.string	"calc"
	.text
	.globl	add
	.type	add, @function
add:
.LFB0:
	.file 1 "calc.c"
	.loc 1 16 1
	.cfi_startproc
	endbr64
	pushq	%rbp
	.cfi_def_cfa_offset 16
	.cfi_offset 6, -16
	movq	%rsp, %rbp
	.cfi_def_cfa_register 6
	movl	%edi, -4(%rbp)
	movl	%esi, -8(%rbp)
	.loc 1 17 14
	movl	-4(%rbp), %edx
	movl	-8(%rbp), %eax
	addl	%edx, %eax
	.loc 1 18 1
	popq	%rbp
	.cfi_def_cfa 7, 8
	ret
	.cfi_endproc
.LFE0:
	.size	add, .-add
	.globl	multiply
	.type	multiply, @function
multiply:
.LFB1:
	.loc 1 21 1
	.cfi_startproc
	endbr64
	pushq	%rbp
	.cfi_def_cfa_offset 16
	.cfi_offset 6, -16
	movq	%rsp, %rbp
	.cfi_def_cfa_register 6
	movl	%edi, -4(%rbp)
	movl	%esi, -8(%rbp)
	.loc 1 22 14
	movl	-4(%rbp), %eax
	imull	-8(%rbp), %eax
	.loc 1 23 1
	popq	%rbp
	.cfi_def_cfa 7, 8
	ret
	.cfi_endproc
.LFE1:
	.size	multiply, .-multiply
	.globl	update_counter
	.type	update_counter, @function
update_counter:
.LFB2:
	.loc 1 26 1
	.cfi_startproc
	endbr64
	pushq	%rbp
	.cfi_def_cfa_offset 16
	.cfi_offset 6, -16
	movq	%rsp, %rbp
	.cfi_def_cfa_register 6
	movl	%edi, -4(%rbp)
	.loc 1 27 20
	movl	global_counter(%rip), %edx
	movl	-4(%rbp), %eax
	addl	%edx, %eax
	movl	%eax, global_counter(%rip)
	.loc 1 28 25
	movl	internal_state(%rip), %eax
	movl	%eax, uninitialized_value(%rip)
	.loc 1 34 20
	movl	$99, %eax
	.loc 1 34 8
	testb	%al, %al
	jne	.L7
	.loc 1 35 24
	movl	$0, global_counter(%rip)
.L7:
	.loc 1 36 1
	nop
	popq	%rbp
	.cfi_def_cfa 7, 8
	ret
	.cfi_endproc
.LFE2:
	.size	update_counter, .-update_counter
.Letext0:
	.file 2 "calc.h"
	.section	.debug_info,"",@progbits
.Ldebug_info0:
	.long	0x15b
	.value	0x5
	.byte	0x1
	.byte	0x8
	.long	.Ldebug_abbrev0
	.uleb128 0x6
	.long	.LASF10
	.byte	0x1d
	.long	.LASF0
	.long	.LASF1
	.quad	.Ltext0
	.quad	.Letext0-.Ltext0
	.long	.Ldebug_line0
	.uleb128 0x2
	.long	.LASF2
	.byte	0x4
	.long	0x38
	.uleb128 0x7
	.byte	0x4
	.byte	0x5
	.string	"int"
	.uleb128 0x2
	.long	.LASF3
	.byte	0x5
	.long	0x38
	.uleb128 0x8
	.long	0x2e
	.byte	0x1
	.byte	0x5
	.uleb128 0x9
	.byte	0x3
	.quad	global_counter
	.uleb128 0x9
	.long	0x3f
	.byte	0x1
	.byte	0x7
	.byte	0x5
	.uleb128 0x9
	.byte	0x3
	.quad	uninitialized_value
	.uleb128 0x3
	.long	.LASF6
	.byte	0xa
	.byte	0xc
	.long	0x38
	.uleb128 0x9
	.byte	0x3
	.quad	internal_state
	.uleb128 0xa
	.long	0xa4
	.long	0x91
	.uleb128 0xb
	.long	0x96
	.byte	0x4
	.byte	0
	.uleb128 0x4
	.long	0x81
	.uleb128 0x5
	.byte	0x8
	.byte	0x7
	.long	.LASF4
	.uleb128 0x5
	.byte	0x1
	.byte	0x6
	.long	.LASF5
	.uleb128 0x4
	.long	0x9d
	.uleb128 0x3
	.long	.LASF7
	.byte	0xd
	.byte	0x13
	.long	0x91
	.uleb128 0x9
	.byte	0x3
	.quad	module_name
	.uleb128 0xc
	.long	.LASF9
	.byte	0x1
	.byte	0x19
	.byte	0x6
	.quad	.LFB2
	.quad	.LFE2-.LFB2
	.uleb128 0x1
	.byte	0x9c
	.long	0xec
	.uleb128 0xd
	.long	.LASF8
	.byte	0x1
	.byte	0x19
	.byte	0x19
	.long	0x38
	.uleb128 0x2
	.byte	0x91
	.sleb128 -20
	.byte	0
	.uleb128 0xe
	.long	.LASF11
	.byte	0x1
	.byte	0x14
	.byte	0x5
	.long	0x38
	.quad	.LFB1
	.quad	.LFE1-.LFB1
	.uleb128 0x1
	.byte	0x9c
	.long	0x127
	.uleb128 0x1
	.string	"a"
	.byte	0x14
	.byte	0x12
	.long	0x38
	.uleb128 0x2
	.byte	0x91
	.sleb128 -20
	.uleb128 0x1
	.string	"b"
	.byte	0x14
	.byte	0x19
	.long	0x38
	.uleb128 0x2
	.byte	0x91
	.sleb128 -24
	.byte	0
	.uleb128 0xf
	.string	"add"
	.byte	0x1
	.byte	0xf
	.byte	0x5
	.long	0x38
	.quad	.LFB0
	.quad	.LFE0-.LFB0
	.uleb128 0x1
	.byte	0x9c
	.uleb128 0x1
	.string	"a"
	.byte	0xf
	.byte	0xd
	.long	0x38
	.uleb128 0x2
	.byte	0x91
	.sleb128 -20
	.uleb128 0x1
	.string	"b"
	.byte	0xf
	.byte	0x14
	.long	0x38
	.uleb128 0x2
	.byte	0x91
	.sleb128 -24
	.byte	0
	.byte	0
	.section	.debug_abbrev,"",@progbits
.Ldebug_abbrev0:
	.uleb128 0x1
	.uleb128 0x5
	.byte	0
	.uleb128 0x3
	.uleb128 0x8
	.uleb128 0x3a
	.uleb128 0x21
	.sleb128 1
	.uleb128 0x3b
	.uleb128 0xb
	.uleb128 0x39
	.uleb128 0xb
	.uleb128 0x49
	.uleb128 0x13
	.uleb128 0x2
	.uleb128 0x18
	.byte	0
	.byte	0
	.uleb128 0x2
	.uleb128 0x34
	.byte	0
	.uleb128 0x3
	.uleb128 0xe
	.uleb128 0x3a
	.uleb128 0x21
	.sleb128 2
	.uleb128 0x3b
	.uleb128 0xb
	.uleb128 0x39
	.uleb128 0x21
	.sleb128 12
	.uleb128 0x49
	.uleb128 0x13
	.uleb128 0x3f
	.uleb128 0x19
	.uleb128 0x3c
	.uleb128 0x19
	.byte	0
	.byte	0
	.uleb128 0x3
	.uleb128 0x34
	.byte	0
	.uleb128 0x3
	.uleb128 0xe
	.uleb128 0x3a
	.uleb128 0x21
	.sleb128 1
	.uleb128 0x3b
	.uleb128 0xb
	.uleb128 0x39
	.uleb128 0xb
	.uleb128 0x49
	.uleb128 0x13
	.uleb128 0x2
	.uleb128 0x18
	.byte	0
	.byte	0
	.uleb128 0x4
	.uleb128 0x26
	.byte	0
	.uleb128 0x49
	.uleb128 0x13
	.byte	0
	.byte	0
	.uleb128 0x5
	.uleb128 0x24
	.byte	0
	.uleb128 0xb
	.uleb128 0xb
	.uleb128 0x3e
	.uleb128 0xb
	.uleb128 0x3
	.uleb128 0xe
	.byte	0
	.byte	0
	.uleb128 0x6
	.uleb128 0x11
	.byte	0x1
	.uleb128 0x25
	.uleb128 0xe
	.uleb128 0x13
	.uleb128 0xb
	.uleb128 0x3
	.uleb128 0x1f
	.uleb128 0x1b
	.uleb128 0x1f
	.uleb128 0x11
	.uleb128 0x1
	.uleb128 0x12
	.uleb128 0x7
	.uleb128 0x10
	.uleb128 0x17
	.byte	0
	.byte	0
	.uleb128 0x7
	.uleb128 0x24
	.byte	0
	.uleb128 0xb
	.uleb128 0xb
	.uleb128 0x3e
	.uleb128 0xb
	.uleb128 0x3
	.uleb128 0x8
	.byte	0
	.byte	0
	.uleb128 0x8
	.uleb128 0x34
	.byte	0
	.uleb128 0x47
	.uleb128 0x13
	.uleb128 0x3a
	.uleb128 0xb
	.uleb128 0x39
	.uleb128 0xb
	.uleb128 0x2
	.uleb128 0x18
	.byte	0
	.byte	0
	.uleb128 0x9
	.uleb128 0x34
	.byte	0
	.uleb128 0x47
	.uleb128 0x13
	.uleb128 0x3a
	.uleb128 0xb
	.uleb128 0x3b
	.uleb128 0xb
	.uleb128 0x39
	.uleb128 0xb
	.uleb128 0x2
	.uleb128 0x18
	.byte	0
	.byte	0
	.uleb128 0xa
	.uleb128 0x1
	.byte	0x1
	.uleb128 0x49
	.uleb128 0x13
	.uleb128 0x1
	.uleb128 0x13
	.byte	0
	.byte	0
	.uleb128 0xb
	.uleb128 0x21
	.byte	0
	.uleb128 0x49
	.uleb128 0x13
	.uleb128 0x2f
	.uleb128 0xb
	.byte	0
	.byte	0
	.uleb128 0xc
	.uleb128 0x2e
	.byte	0x1
	.uleb128 0x3f
	.uleb128 0x19
	.uleb128 0x3
	.uleb128 0xe
	.uleb128 0x3a
	.uleb128 0xb
	.uleb128 0x3b
	.uleb128 0xb
	.uleb128 0x39
	.uleb128 0xb
	.uleb128 0x27
	.uleb128 0x19
	.uleb128 0x11
	.uleb128 0x1
	.uleb128 0x12
	.uleb128 0x7
	.uleb128 0x40
	.uleb128 0x18
	.uleb128 0x7a
	.uleb128 0x19
	.uleb128 0x1
	.uleb128 0x13
	.byte	0
	.byte	0
	.uleb128 0xd
	.uleb128 0x5
	.byte	0
	.uleb128 0x3
	.uleb128 0xe
	.uleb128 0x3a
	.uleb128 0xb
	.uleb128 0x3b
	.uleb128 0xb
	.uleb128 0x39
	.uleb128 0xb
	.uleb128 0x49
	.uleb128 0x13
	.uleb128 0x2
	.uleb128 0x18
	.byte	0
	.byte	0
	.uleb128 0xe
	.uleb128 0x2e
	.byte	0x1
	.uleb128 0x3f
	.uleb128 0x19
	.uleb128 0x3
	.uleb128 0xe
	.uleb128 0x3a
	.uleb128 0xb
	.uleb128 0x3b
	.uleb128 0xb
	.uleb128 0x39
	.uleb128 0xb
	.uleb128 0x27
	.uleb128 0x19
	.uleb128 0x49
	.uleb128 0x13
	.uleb128 0x11
	.uleb128 0x1
	.uleb128 0x12
	.uleb128 0x7
	.uleb128 0x40
	.uleb128 0x18
	.uleb128 0x7a
	.uleb128 0x19
	.uleb128 0x1
	.uleb128 0x13
	.byte	0
	.byte	0
	.uleb128 0xf
	.uleb128 0x2e
	.byte	0x1
	.uleb128 0x3f
	.uleb128 0x19
	.uleb128 0x3
	.uleb128 0x8
	.uleb128 0x3a
	.uleb128 0xb
	.uleb128 0x3b
	.uleb128 0xb
	.uleb128 0x39
	.uleb128 0xb
	.uleb128 0x27
	.uleb128 0x19
	.uleb128 0x49
	.uleb128 0x13
	.uleb128 0x11
	.uleb128 0x1
	.uleb128 0x12
	.uleb128 0x7
	.uleb128 0x40
	.uleb128 0x18
	.uleb128 0x7a
	.uleb128 0x19
	.byte	0
	.byte	0
	.byte	0
	.section	.debug_aranges,"",@progbits
	.long	0x2c
	.value	0x2
	.long	.Ldebug_info0
	.byte	0x8
	.byte	0
	.value	0
	.value	0
	.quad	.Ltext0
	.quad	.Letext0-.Ltext0
	.quad	0
	.quad	0
	.section	.debug_line,"",@progbits
.Ldebug_line0:
	.section	.debug_str,"MS",@progbits,1
.LASF11:
	.string	"multiply"
.LASF4:
	.string	"long unsigned int"
.LASF7:
	.string	"module_name"
.LASF3:
	.string	"uninitialized_value"
.LASF8:
	.string	"value"
.LASF2:
	.string	"global_counter"
.LASF10:
	.string	"GNU C11 13.3.0 -mtune=generic -march=x86-64 -g -O0 -std=c11 -fasynchronous-unwind-tables -fstack-protector-strong -fstack-clash-protection -fcf-protection"
.LASF9:
	.string	"update_counter"
.LASF6:
	.string	"internal_state"
.LASF5:
	.string	"char"
	.section	.debug_line_str,"MS",@progbits,1
.LASF0:
	.string	"calc.c"
.LASF1:
	.string	"/home/zoe/workspace/complie_lab"
	.ident	"GCC: (Ubuntu 13.3.0-6ubuntu2~24.04.1) 13.3.0"
	.section	.note.GNU-stack,"",@progbits
	.section	.note.gnu.property,"a"
	.align 8
	.long	1f - 0f
	.long	4f - 1f
	.long	5
0:
	.string	"GNU"
1:
	.align 8
	.long	0xc0000002
	.long	3f - 2f
2:
	.long	0x3
3:
	.align 8
4:
