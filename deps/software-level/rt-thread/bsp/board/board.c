/*
 * Copyright (c) 2006-2023, RT-Thread Development Team
 *
 * SPDX-License-Identifier: Apache-2.0
 *
 * Change Logs:
 * Date           Author       Notes
 * 2020-04-22     hqfang       first version
 *
 */

#include <rtthread.h>
#include <rtdevice.h>
#include "board.h"
#include "cpuport.h"

#define SYSTICK_TICK_CONST (SOC_TIMER_FREQ / RT_TICK_PER_SECOND)
#define RT_KERNEL_INTERRUPT_LEVEL 1

#ifdef RT_USING_SERIAL
#include <drv_uart.h>
#endif

/** _end symbol defined in linker script*/
extern void *_end;

/** _heap_end symbol defined in linker script*/
extern void *_heap_end;
#define HEAP_BEGIN &_end
#define HEAP_END &_heap_end

void timer_irq_handler(void);
void swi_handler(void);

rt_weak void rt_hw_ticksetup(void)
{
    uint64_t ticks = SYSTICK_TICK_CONST;

    /* Make SWI and SysTick the lowest priority interrupts. */
    /* Stop and clear the SysTimer. SysTimer as Non-Vector Interrupt */
    SysTick_Config(ticks);

    rt_hw_interrupt_init();                                                         // 中断入口函数初始化
    rt_hw_interrupt_install(SysTimer_IRQn, timer_irq_handler, RT_NULL, "timerirq"); // 注册系统定时器中断入口函数
    rt_hw_interrupt_install(SysTimerSW_IRQn, swi_handler, RT_NULL, "swi"); // 注册软件中断入口函数
}

void swi_handler(void)
{
   CLINT_ClearSWIRQ();
}

/**
 * @brief This is the timer interrupt service routine.
 *
 */
void timer_irq_handler(void)
{
    /* Reload systimer */
    SysTick_Reload(SYSTICK_TICK_CONST);

    /* enter interrupt */
    rt_interrupt_enter();

    /* tick increase */
    rt_tick_increase();

    /* leave interrupt */
    rt_interrupt_leave();
}

/**
 * @brief Setup hardware board for rt-thread
 *
 */
void rt_hw_board_init(void)
{
    /* OS Tick Configuration */
    rt_hw_ticksetup();

#ifdef RT_USING_HEAP
    rt_system_heap_init((void *)HEAP_BEGIN, (void *)HEAP_END);
#endif

    /* UART driver initialization is open by default */
#ifdef RT_USING_SERIAL
    rt_hw_uart_init();
#endif

    /* Set the shell console output device */
#if defined(RT_USING_CONSOLE) && defined(RT_USING_DEVICE)
    rt_console_set_device(RT_CONSOLE_DEVICE_NAME);
#endif

    /* Board underlying hardware initialization */
#ifdef RT_USING_COMPONENTS_INIT
    rt_components_board_init();
#endif
}