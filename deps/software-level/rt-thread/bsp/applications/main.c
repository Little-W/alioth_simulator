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

#ifdef RT_USING_SERIAL
/* Currently UART IRQ is not connected,
 * So I use task to interact with uart input
 */
#define SERIAL_THREAD_STACK_SIZE    396
static rt_uint8_t serial_stack[SERIAL_THREAD_STACK_SIZE];
static struct rt_thread serial_tid;
extern void rt_hw_serial_rcvtsk(void *parameter);

void board_serial_init(void)
{
    rt_thread_init(&serial_tid, "serrxsim", rt_hw_serial_rcvtsk,
            (void *)NULL, serial_stack, SERIAL_THREAD_STACK_SIZE, 5, 5);
    rt_thread_startup(&serial_tid);
}
#endif  /* RT_USING_SERIAL */

#define HELLO_THREAD_STACK_SIZE  1024

static rt_thread_t hello_thread1 = RT_NULL;
static rt_thread_t hello_thread2 = RT_NULL;

static void hello_entry(void *parameter)
{
    const char *name = (const char *)parameter;
    while (1)
    {
        rt_kprintf("Hello from %s\n", name);
        rt_thread_mdelay(10);
    }
}

int main(void)
{
#ifdef RT_USING_SERIAL
    board_serial_init();
#endif  /* RT_USING_SERIAL */

    hello_thread1 = rt_thread_create("hello1", hello_entry, "thread1",
                                     HELLO_THREAD_STACK_SIZE, 10, 10);
    if (hello_thread1 != RT_NULL)
        rt_thread_startup(hello_thread1);

    hello_thread2 = rt_thread_create("hello2", hello_entry, "thread2",
                                     HELLO_THREAD_STACK_SIZE, 10, 10);
    if (hello_thread2 != RT_NULL)
        rt_thread_startup(hello_thread2);

    // 主线程可以空转或做其他事
    while (1)
    {
        rt_thread_mdelay(1000);
    }
}

/******************** end of file *******************/

