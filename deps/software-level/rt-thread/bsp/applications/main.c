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

int main(void)
{
    // rt_kprintf("All tests completed.\n");
    // rt_kprintf("Hello RT-Thread!\n");
    while (1)
    {
        rt_thread_mdelay(1000);
    }
    return 0;
}