/*
 * Copyright (c) 2006-2018, RT-Thread Development Team
 *
 * SPDX-License-Identifier: Apache-2.0
 *
 * Change Logs:
 * Date           Author       Notes
 * 2020-09-02     hqfang       first version
 */

#include <rtthread.h>
#include <rtdevice.h>
#include "platform.h"
#include <utest.h>

#define MCYCLE_THREAD_STACK_SIZE 512
static rt_uint8_t mcycle_stack[MCYCLE_THREAD_STACK_SIZE];
static struct rt_thread mcycle_tid;

static void mcycle_thread_entry(void *parameter)
{
    while (1)
    {
        unsigned int mcycle = __get_rv_cycle();
        rt_kprintf("mcycle: %u\n", mcycle);
        rt_thread_mdelay(1000);
    }
}

static void my_command_entry(int argc, char *argv[])
{
    // 函数实现
    rt_kprintf("Hello from my_command!\n");
}
MSH_CMD_EXPORT(my_command_entry, this is a test command);

#ifdef RT_USING_FINSH
    #include <finsh.h> // 或者 #include <msh.h>
    extern int msh_exec(char *cmd, rt_size_t length);
#endif

int main(void)
{
    /* 创建并启动mcycle线程 */
    // rt_thread_init(&mcycle_tid, "mcycle", mcycle_thread_entry,
    //                RT_NULL, mcycle_stack, MCYCLE_THREAD_STACK_SIZE, 10, 10);
    // rt_thread_startup(&mcycle_tid);

    /* 先列出所有测试用例 */

    // char *argv[] = {"utest_list"};
    // utest_testcase_run(1, argv);

    // char *argv3[] = {"utest_run", (char *)"testcases.kernel.mem_tc"};
    // utest_testcase_run(2, argv3);
    // char *argv_mutex[] = {"utest_run", (char *)"testcases.kernel.mutex_tc"};
    // utest_testcase_run(2, argv_mutex);
    // char *argv_msgqueue[] = {"utest_run", (char *)"testcases.kernel.messagequeue_tc"};
    // utest_testcase_run(2, argv_msgqueue);
    // char *argv_mailbox[] = {"utest_run", (char *)"src.ipc.mailbox_tc"};
    // utest_testcase_run(2, argv_mailbox);
    // char *argv3[] = {"utest_run", (char *)"testcases.kernel.signal_tc"};
    // utest_testcase_run(2, argv3);
    // char *argv3[] = {"utest_run", (char *)"testcases.kernel.thread_tc"};
    // utest_testcase_run(2, argv3);
    // char *argv2[] = {"utest_run", (char *)"*"};
    // utest_testcase_run(2, argv2);

    /* 依次运行所有测试用例（直接用你给的list） */
    // const char *testcases[] = {
    //     "src.ipc.event_tc",
    //     "testcases.kernel.irq_tc",
    //     "src.ipc.mailbox_tc",
    //     "testcases.kernel.mutex_pi_tc",
    //     "testcases.kernel.mutex_tc",
    //     "testcases.kernel.object_test",
    //     "testcases.kernel.signal_tc",
    //     "testcases.kernel.thread_tc",
    //     "testcases.kernel.timer_tc",
    //     "testcases.utest.pass_tc"};
    // int testcase_count = sizeof(testcases) / sizeof(testcases[0]);
    // for (int i = 0; i < testcase_count; i++)
    // {
    //     char *argv[] = {"utest_run", (char *)testcases[i]};
    //     utest_testcase_run(2, argv);
    // }

    // rt_kprintf("All tests completed.\n");
    // rt_kprintf("Hello RT-Thread!\n");
    while (1)
    {
        rt_thread_mdelay(1000);
        // ...你的其他应用程序逻辑...
    }
    return 0;
}