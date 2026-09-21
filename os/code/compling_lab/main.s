	.file	"main.c"
	.text
.Ltext0:
	.file 0 "/home/zoe/workspace/complie_lab" "main.c"
	.data
	.align 4
	.type	local_data, @object
	.size	local_data, 4
local_data:
	.long	100
	.section	.rodata
	.align 32
	.type	message, @object
	.size	message, 39
message:
	.string	"ELF compilation and linking laboratory"
.LC0:
	.string	"add(%d, %d) = %d\n"
.LC1:
	.string	"multiply(%d, %d) = %d\n"
.LC2:
	.string	"global_counter = %d\n"
.LC3:
	.string	"uninitialized_value = %d\n"
	.text
	.globl	main
	.type	main, @function
main:
.LFB0:
	.file 1 "main.c"
	.loc 1 11 1
	.cfi_startproc
	endbr64
	pushq	%rbp
	.cfi_def_cfa_offset 16
	.cfi_offset 6, -16
	movq	%rsp, %rbp
	.cfi_def_cfa_register 6
	subq	$16, %rsp
	.loc 1 12 9
	movl	$6, -8(%rbp)
	.loc 1 13 9
	movl	$7, -4(%rbp)
	.loc 1 15 5
	leaq	message(%rip), %rax
	movq	%rax, %rdi
	call	puts@PLT
	.loc 1 16 5
	movl	-4(%rbp), %edx
	movl	-8(%rbp), %eax
	movl	%edx, %esi
	movl	%eax, %edi
	call	add@PLT
	movl	%eax, %ecx
	.loc 1 16 5 is_stmt 0 discriminator 1
	movl	-4(%rbp), %edx
	movl	-8(%rbp), %eax
	movl	%eax, %esi
	leaq	.LC0(%rip), %rax
	movq	%rax, %rdi
	movl	$0, %eax
	call	printf@PLT
	.loc 1 17 5 is_stmt 1
	movl	-4(%rbp), %edx
	movl	-8(%rbp), %eax
	movl	%edx, %esi
	movl	%eax, %edi
	call	multiply@PLT
	movl	%eax, %ecx
	.loc 1 17 5 is_stmt 0 discriminator 1
	movl	-4(%rbp), %edx
	movl	-8(%rbp), %eax
	movl	%eax, %esi
	leaq	.LC1(%rip), %rax
	movq	%rax, %rdi
	movl	$0, %eax
	call	printf@PLT
	.loc 1 19 5 is_stmt 1
	movl	local_data(%rip), %eax
	movl	%eax, %edi
	call	update_counter@PLT
	.loc 1 21 5
	movl	global_counter(%rip), %eax
	movl	%eax, %esi
	leaq	.LC2(%rip), %rax
	movq	%rax, %rdi
	movl	$0, %eax
	call	printf@PLT
	.loc 1 22 5
	movl	uninitialized_value(%rip), %eax
	movl	%eax, %esi
	leaq	.LC3(%rip), %rax
	movq	%rax, %rdi
	movl	$0, %eax
	call	printf@PLT
	.loc 1 24 12
	movl	$0, %eax
	.loc 1 25 1
	leave
	.cfi_def_cfa 7, 8
	ret
	.cfi_endproc
.LFE0:
	.size	main, .-main
.Letext0:
	.file 2 "calc.h"
	.file 3 "/usr/include/stdio.h"
	.section	.debug_info,"",@progbits
.Ldebug_info0:
	.long	0x15d
	.value	0x5
	.byte	0x1
	.byte	0x8
	.long	.Ldebug_abbrev0
	.uleb128 0x7
	.long	.LASF16
	.byte	0x1d
	.long	.LASF0
	.long	.LASF1
	.quad	.Ltext0
	.quad	.Letext0-.Ltext0
	.long	.Ldebug_line0
	.uleb128 0x1
	.byte	0x8
	.byte	0x7
	.long	.LASF2
	.uleb128 0x1
	.byte	0x4
	.byte	0x7
	.long	.LASF3
	.uleb128 0x1
	.byte	0x1
	.byte	0x8
	.long	.LASF4
	.uleb128 0x1
	.byte	0x2
	.byte	0x7
	.long	.LASF5
	.uleb128 0x1
	.byte	0x1
	.byte	0x6
	.long	.LASF6
	.uleb128 0x1
	.byte	0x2
	.byte	0x5
	.long	.LASF7
	.uleb128 0x8
	.byte	0x4
	.byte	0x5
	.string	"int"
	.uleb128 0x1
	.byte	0x8
	.byte	0x5
	.long	.LASF8
	.uleb128 0x1
	.byte	0x1
	.byte	0x6
	.long	.LASF9
	.uleb128 0x3
	.long	0x66
	.uleb128 0x4
	.long	.LASF10
	.byte	0x4
	.long	0x58
	.uleb128 0x4
	.long	.LASF11
	.byte	0x5
	.long	0x58
	.uleb128 0x5
	.long	.LASF12
	.byte	0x5
	.byte	0xc
	.long	0x58
	.uleb128 0x9
	.byte	0x3
	.quad	local_data
	.uleb128 0x9
	.long	0x6d
	.long	0xab
	.uleb128 0xa
	.long	0x2e
	.byte	0x26
	.byte	0
	.uleb128 0x3
	.long	0x9b
	.uleb128 0x5
	.long	.LASF13
	.byte	0x8
	.byte	0x13
	.long	0xab
	.uleb128 0x9
	.byte	0x3
	.quad	message
	.uleb128 0xb
	.long	.LASF17
	.byte	0x2
	.byte	0x9
	.byte	0x6
	.long	0xd7
	.uleb128 0x2
	.long	0x58
	.byte	0
	.uleb128 0xc
	.long	.LASF14
	.byte	0x2
	.byte	0x8
	.byte	0x5
	.long	0x58
	.long	0xf2
	.uleb128 0x2
	.long	0x58
	.uleb128 0x2
	.long	0x58
	.byte	0
	.uleb128 0xd
	.long	.LASF15
	.byte	0x3
	.value	0x16b
	.byte	0xc
	.long	0x58
	.long	0x10a
	.uleb128 0x2
	.long	0x10a
	.uleb128 0xe
	.byte	0
	.uleb128 0xf
	.byte	0x8
	.long	0x6d
	.uleb128 0x10
	.string	"add"
	.byte	0x2
	.byte	0x7
	.byte	0x5
	.long	0x58
	.long	0x12b
	.uleb128 0x2
	.long	0x58
	.uleb128 0x2
	.long	0x58
	.byte	0
	.uleb128 0x11
	.long	.LASF18
	.byte	0x1
	.byte	0xa
	.byte	0x5
	.long	0x58
	.quad	.LFB0
	.quad	.LFE0-.LFB0
	.uleb128 0x1
	.byte	0x9c
	.uleb128 0x6
	.string	"x"
	.byte	0xc
	.long	0x58
	.uleb128 0x2
	.byte	0x91
	.sleb128 -24
	.uleb128 0x6
	.string	"y"
	.byte	0xd
	.long	0x58
	.uleb128 0x2
	.byte	0x91
	.sleb128 -20
	.byte	0
	.byte	0
	.section	.debug_abbrev,"",@progbits
.Ldebug_abbrev0:
	.uleb128 0x1
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
	.uleb128 0x2
	.uleb128 0x5
	.byte	0
	.uleb128 0x49
	.uleb128 0x13
	.byte	0
	.byte	0
	.uleb128 0x3
	.uleb128 0x26
	.byte	0
	.uleb128 0x49
	.uleb128 0x13
	.byte	0
	.byte	0
	.uleb128 0x4
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
	.uleb128 0x5
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
	.uleb128 0x6
	.uleb128 0x34
	.byte	0
	.uleb128 0x3
	.uleb128 0x8
	.uleb128 0x3a
	.uleb128 0x21
	.sleb128 1
	.uleb128 0x3b
	.uleb128 0xb
	.uleb128 0x39
	.uleb128 0x21
	.sleb128 9
	.uleb128 0x49
	.uleb128 0x13
	.uleb128 0x2
	.uleb128 0x18
	.byte	0
	.byte	0
	.uleb128 0x7
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
	.uleb128 0x8
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
	.uleb128 0x9
	.uleb128 0x1
	.byte	0x1
	.uleb128 0x49
	.uleb128 0x13
	.uleb128 0x1
	.uleb128 0x13
	.byte	0
	.byte	0
	.uleb128 0xa
	.uleb128 0x21
	.byte	0
	.uleb128 0x49
	.uleb128 0x13
	.uleb128 0x2f
	.uleb128 0xb
	.byte	0
	.byte	0
	.uleb128 0xb
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
	.uleb128 0x3c
	.uleb128 0x19
	.uleb128 0x1
	.uleb128 0x13
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
	.uleb128 0x49
	.uleb128 0x13
	.uleb128 0x3c
	.uleb128 0x19
	.uleb128 0x1
	.uleb128 0x13
	.byte	0
	.byte	0
	.uleb128 0xd
	.uleb128 0x2e
	.byte	0x1
	.uleb128 0x3f
	.uleb128 0x19
	.uleb128 0x3
	.uleb128 0xe
	.uleb128 0x3a
	.uleb128 0xb
	.uleb128 0x3b
	.uleb128 0x5
	.uleb128 0x39
	.uleb128 0xb
	.uleb128 0x27
	.uleb128 0x19
	.uleb128 0x49
	.uleb128 0x13
	.uleb128 0x3c
	.uleb128 0x19
	.uleb128 0x1
	.uleb128 0x13
	.byte	0
	.byte	0
	.uleb128 0xe
	.uleb128 0x18
	.byte	0
	.byte	0
	.byte	0
	.uleb128 0xf
	.uleb128 0xf
	.byte	0
	.uleb128 0xb
	.uleb128 0xb
	.uleb128 0x49
	.uleb128 0x13
	.byte	0
	.byte	0
	.uleb128 0x10
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
	.uleb128 0x3c
	.uleb128 0x19
	.uleb128 0x1
	.uleb128 0x13
	.byte	0
	.byte	0
	.uleb128 0x11
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
	.uleb128 0x7c
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
.LASF13:
	.string	"message"
.LASF3:
	.string	"unsigned int"
.LASF11:
	.string	"uninitialized_value"
.LASF2:
	.string	"long unsigned int"
.LASF14:
	.string	"multiply"
.LASF12:
	.string	"local_data"
.LASF9:
	.string	"char"
.LASF17:
	.string	"update_counter"
.LASF4:
	.string	"unsigned char"
.LASF18:
	.string	"main"
.LASF16:
	.string	"GNU C11 13.3.0 -mtune=generic -march=x86-64 -g -O0 -std=c11 -fasynchronous-unwind-tables -fstack-protector-strong -fstack-clash-protection -fcf-protection"
.LASF8:
	.string	"long int"
.LASF10:
	.string	"global_counter"
.LASF5:
	.string	"short unsigned int"
.LASF15:
	.string	"printf"
.LASF7:
	.string	"short int"
.LASF6:
	.string	"signed char"
	.section	.debug_line_str,"MS",@progbits,1
.LASF0:
	.string	"main.c"
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
