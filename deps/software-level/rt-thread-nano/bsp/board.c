/*
 * Copyright (c) 2006-2019, RT-Thread Development Team
 *
 * SPDX-License-Identifier: Apache-2.0
 *
 * Change Logs:
 * Date           Author       Notes
 * 2021-05-24                  the first version
 */

#include <rthw.h>
#include <rtthread.h>
#include "board.h"
#include "cpuport.h"

#define SYSTICK_TICK_CONST (SOC_TIMER_FREQ / RT_TICK_PER_SECOND)
#define RT_KERNEL_INTERRUPT_LEVEL 1

#ifdef RT_USING_CONSOLE
#include "uart.h"
#define UART0 ((UART_TypeDef *)UART0_BASE)
#define UART1 ((UART_TypeDef *)UART1_BASE)

int nano_uart_init(void);
char rt_hw_console_getchar(void);
#endif

/** _end symbol defined in linker script*/
extern void *_end;
/** _heap_end symbol defined in linker script*/
extern void *_heap_end;
#define HEAP_BEGIN &_end
#define HEAP_END &_heap_end

void timer_irq_handler(void);
void swi_handler(void);

void rt_hw_ticksetup(void)
{
    uint64_t ticks = SYSTICK_TICK_CONST;
    SysTick_Config(ticks);
    rt_hw_interrupt_install(MachineTimer_IRQn, timer_irq_handler, RT_NULL, "timerirq");
    __enable_timer_irq();
}

void swi_handler(void)
{
    CLINT_ClearSWIRQ();
}

void timer_irq_handler(void)
{
    SysTick_Reload(SYSTICK_TICK_CONST);
    rt_tick_increase();
}

/**
 * @brief Setup hardware board for rt-thread
 *
 */
void rt_hw_board_init(void)
{
    rt_hw_interrupt_init();
    rt_hw_ticksetup();

    rt_hw_interrupt_install(MachineSoftware_IRQn, swi_handler, RT_NULL, "swi");
    __enable_sw_irq();
    plic_init();
    __enable_ext_irq();
    rt_hw_interrupt_install(MachineExternal_IRQn, plic_dispatch, RT_NULL, "plic");

#ifdef RT_USING_CONSOLE
    nano_uart_init();
#endif

#if defined(RT_USING_CONSOLE) && defined(RT_USING_DEVICE)
    rt_console_set_device(RT_CONSOLE_DEVICE_NAME);
#endif

#ifdef RT_USING_COMPONENTS_INIT
    rt_components_board_init();
#endif

#if defined(RT_USING_USER_MAIN) && defined(RT_USING_HEAP)
    rt_system_heap_init((void *)HEAP_BEGIN, (void *)HEAP_END);
#endif
}

#ifdef RT_USING_CONSOLE
#define CONSOLE_UART UART0
#define CONSOLE_UART_IRQn UART0_IRQn // 补充中断号定义

// 补充uart_irq_handler定义（裸机串口中断处理函数，简单示例）
void uart_irq_handler(void *param)
{
    // rt_hw_console_getchar();
}

int nano_uart_init(void)
{
    uart_init(CONSOLE_UART, 115200);
    uart_config_stopbit(CONSOLE_UART, UART_STOP_BIT_1);
    uart_disable_paritybit(CONSOLE_UART);
    return 0;
}
// INIT_BOARD_EXPORT(nano_uart_init);

void rt_hw_console_output(const char *str)
{
    rt_size_t i = 0, size = 0;
    char a = '\r';
    size = rt_strlen(str);
    for (i = 0; i < size; i++)
    {
        if (*(str + i) == '\n')
        {
            uart_write(CONSOLE_UART, (uint8_t)a);
        }
        uart_write(CONSOLE_UART, (uint8_t)*(str + i));
    }
}
#endif

#ifdef RT_USING_FINSH
#define CONSOLE_UART UART0
char rt_hw_console_getchar(void)
{
    int ch = -1;
    if (CONSOLE_UART->LSR & 0x1)
    {
        ch = uart_read(CONSOLE_UART);
    }
    else
    {
        rt_thread_mdelay(10);
    }
    return ch;
}
#endif