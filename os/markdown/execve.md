# execve

关键执行流：  

```

do_execve() ->
    do_execveat_common() ->
        bprm_execve() ->
            exec_binprm() ->
                search_binary_handler() ->
                    (for each formats) fmt->load_binary ->
                        load_elf_binary ->
                            begin_new_exec ->
                                bprm_creds_from_file ->
                                de_thread() ->
                                io_uring_task_cancel ->
                                unshare_files ->
                                set_mm_exe_file ->
                                would_dump ->
                                acct_arg_size() ->
                                exec_mmap() ->

```

## struct linux_binprm

该结构体用于存放在载入二进制文件时，需要保存的必要信息。  

```c

/*
 * This structure is used to hold the arguments that are used when loading binaries.
 */
struct linux_binprm {
#ifdef CONFIG_MMU
        struct vm_area_struct *vma;
        unsigned long vma_pages;
        unsigned long argmin; /* rlimit marker for copy_strings() */
#else
# define MAX_ARG_PAGES  32
        struct page *page[MAX_ARG_PAGES];
#endif
        struct mm_struct *mm;
        unsigned long p; /* current top of mem */
        unsigned int
                /* Should an execfd be passed to userspace? */
                have_execfd:1,

                /* Use the creds of a script (see binfmt_misc) */
                execfd_creds:1,
                /*
                 * Set by bprm_creds_for_exec hook to indicate a
                 * privilege-gaining exec has happened. Used to set
                 * AT_SECURE auxv for glibc.
                 */
                secureexec:1,
                /*
                 * Set when errors can no longer be returned to the
                 * original userspace.
                 */
                point_of_no_return:1,
                /* Set when "comm" must come from the dentry. */
                comm_from_dentry:1,
                /*
                 * Set by user space to check executability according to the
                 * caller's environment.
                 */
                is_check:1;
        struct file *executable; /* Executable to pass to the interpreter */
        struct file *interpreter;
        struct file *file;
        struct cred *cred;      /* new credentials */
        int unsafe;             /* how unsafe this exec is (mask of LSM_UNSAFE_*) */
        unsigned int per_clear; /* bits to clear in current->personality */
        int argc, envc;
        const char *filename;   /* Name of binary as seen by procps */
        const char *interp;     /* Name of the binary really executed. Most
                                   of the time same as filename, but could be
                                   different for binfmt_{misc,script} */
        const char *fdpath;     /* generated filename for execveat */
        unsigned interp_flags;
        int execfd;             /* File descriptor of the executable */
        unsigned long exec;

        struct rlimit rlim_stack; /* Saved RLIMIT_STACK used during exec. */

        char buf[BINPRM_BUF_SIZE];
} __randomize_layout;
```

## static int do_execveat_common(int fd, struct filename \*filename, struct user_arg_ptr argv, struct user_arg_ptr envp, int flags)


首先，填充bprm结构体  

```c


        bprm = alloc_bprm(fd, filename, flags);
        if (IS_ERR(bprm)) {
                retval = PTR_ERR(bprm);
                goto out_ret;
        }

        retval = count(argv, MAX_ARG_STRINGS);
        if (retval < 0)
                goto out_free;
        bprm->argc = retval;

        retval = count(envp, MAX_ARG_STRINGS);
        if (retval < 0)
                goto out_free;
        bprm->envc = retval;

        retval = bprm_stack_limits(bprm);
        if (retval < 0)
                goto out_free;

        retval = copy_string_kernel(bprm->filename, bprm);
        if (retval < 0)
                goto out_free;
        bprm->exec = bprm->p;

        retval = copy_strings(bprm->envc, envp, bprm);
        if (retval < 0)
                goto out_free;

        retval = copy_strings(bprm->argc, argv, bprm);
        if (retval < 0)
                goto out_free;
        /*
         * When argv is empty, add an empty string ("") as argv[0] to
         * ensure confused userspace programs that start processing
         * from argv[1] won't end up walking envp. See also
         * bprm_stack_limits().
         */
        if (bprm->argc == 0) {
                retval = copy_string_kernel("", bprm);
                if (retval < 0)
                        goto out_free;
                bprm->argc = 1;

                pr_warn_once("process '%s' launched '%s' with NULL argv: empty string added\n",
                             current->comm, bprm->filename);
        }
```

首先分配 `linux_binprm` 结构、统计并检查 argv/envc 数量与栈空间限制，然后按“文件名→环境变量→命令行参数”的顺序将字符串逐个拷贝到新进程栈上（并在 argv 为空时补一个空字符串作 argv[0]），从而完成 `bprm` 的初始化。  

随后进入函数 `bprm_execve`

```c

    retval = bprm_execve(bprm)

```


## int bprm_execve(struct linux_binprm *bprm)


1. 为当前任务准备creds  

2. check unsafe exec

3. 标记current->in_execve = 1

4. 停用当前任务的mm_cid并释放其占用的cid资源

5. 调用`shced_exec()`， 为当前任务重新选择CPU，在必要时触发一次迁移

6. `security_bprm_creds_for_exec`, 通过LSM钩子准备并检查新进程的安全凭证

7. 接下来调用 `exec_binprm`

### static int exec_binprm(struct linux_binprm *bprm)



## static int load_elf_binary

1. check elf magic number
2. load elf program headers
3. try to find interpreter in program headers, get it's struct file and elf_header if exists,`PT_INTERP`
4. process special segments of *the elf binary*: `PT_GNU_STACK` and `PT_LOPROC/HIPROC`
5. check interpreter's legality and get its program headers,`load_elf_interpreter`
6. process special segments of *the interpreter* `PT_GNU_STACK` and `PT_LOPROC/HIPROC`.
7. parse_elf_properties(解析 ELF 文件中 PT_GNU_PROPERTY 段里的 GNU 属性笔记
8. `arch_check_elf`,(dummy implementation)
9. `begin_new_exec`
10. set personality??
11. set randonmize va space if needed.
12. `setup_new_exec(bprm)`, `arch_pick_mmap_layout`, pick mmap layout for new mm according to personality and rlimit, then `arch_setup_new_exec`, do arch-related setting.
13. `setup_arg_pages`, determine the final positon and the permission of new stack, and expand stack space.

## int setup_arg_pages

1. confirm stack position according to configuration `STACK_GROWUP` or not.
2. adjust stack execute permissions


## int begin_new_exec

该函数将切换线程、地址空间、creds和signal等 **全部进程状态**，将进程从旧程序切换到新程序。  

1. 标记 `bprm->point_of_no_return = true`
2. kill all other threads in the thread group, and be the thread group leader, `de_thread()`
3. `current->fs->in_exec = 0`
4. cancel any io_uring activity(close all I/O activities in processing), `io_uring_task_cancel`
5. unshare files(avioding effecting other processes), `unshare_files`
6. `set_mm_exe_file`, change mm's reference to the executable file to the new executable file.
7. If the binary is not readable then enforce mm->dumpable = 0.`would_dump()`
8. Revoke the memory pages previously temporarily recorded on current->mm.`acct_arg_size(bprm,0)`
9. maps the mm_struct mm into the current task struct.`exec_mmap()`
10. `exec_task_namespaces`
11. exit timers if `CONFIG_POSIX_TIMERS`
12. make the signal table private, `unshare_sighand`
13. flush thread's hardware status (register, TLS, FPU state, PKRU state),`flush_thread`
14. me->personality &= ~bprm->per_clear.
15. `clear_syscall_work_syscall_user_dispatch(me)`
16. `do_close_on_exec(me->files)`, close file which set to be closed on exec
17. clean pdeath_signal and set stack rlimit to default if bprm->secureexec has been set
18. set alternate signal stack 's sp and size = 0
19. set dumpablity
20. fix task comm name if it's empt if it's empty, making it's more friendly for tools like ps.
21. flush all signal handlers, `flush_signal_handlers`
22. install the new credentials for this executable, `security_bprm_committing_cres(bprm)`.
23. tidy up after install new credentials, `srcurity_bprm_committed_creds(bprm)`
24. pass executable's fd to interpreter, then return 0.

## static int exec_mmap(struct mm_struct *mm)

1. Notify parent that we're no longer interested in the old VM, `exec_mm_release`, 清理tsk和mm关联所产生的副作用，不是释放mm内存！
    1. clean futex resources, `futex_exit_release`
    2. clean mm-related resources? `mm_release`
        1. free uprobe
        2. decativate any cached register state
        3. announce clear_child_tid
        4. wake up vfork parent process
2. acquire write lock of &tsk->signal->exec_update_lock, `down_rrite_killable(&tsk->signal_exec_update_lock)`
3. acquire read lock of &old_mm->mmap_lock,`mmap_read_lock_killable(old_mm)`
4. acquire &tsk->alloc_lock, `task_lock(tsk)`
5. set &bprm->mm->membarrier_state = 0, runqueues.membarrier_state=0, `membarrier_exec_mmap(mm)`
6. change tsk->mm and tsk->active_mm = mm
7. `mm_init_cid`
8. enable/disable irq
9. add new mm to lru list
10. find a new owner of old_mm
11. `mm_put(old_mm)`
12. `mmdrop_lazy_tlb(active_mm)`
