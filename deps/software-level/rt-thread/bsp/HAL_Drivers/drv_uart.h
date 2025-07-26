/*
 * Copyright (c) 2006-2020, RT-Thread Development Team
 *
 * SPDX-License-Identifier: Apache-2.0
 *
 * Change Logs:
 * Date           Author       Notes
 * 2020-04-15     hqfang       first version
 */
#ifndef __DRV_UART_H__
#define __DRV_UART_H__

#include <rtthread.h>
#include <rtdevice.h>
#include <drv_config.h>
#include "platform.h" // 新增：包含裸机平台相关定义

// 新增：定义UART0和UART1为指向UART_TypeDef的指针
#define UART0 ((UART_TypeDef *)UART0_BASE)
#define UART1 ((UART_TypeDef *)UART1_BASE)

/* config class */
struct hbird_uart_config
{
    const char *name;
    UART_TypeDef *uart;
    IRQn_Type irqn;
};

/* hbird uart dirver class */
struct hbird_uart
{
    struct hbird_uart_config *config;
    struct rt_serial_device serial;
};

extern int rt_hw_uart_init(void);

#endif /* __DRV_USART_H__ */

/******************* end of file *******************/
