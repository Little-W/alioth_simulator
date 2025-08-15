/*
 * Copyright (c) 2006-2020, RT-Thread Development Team
 *
 * SPDX-License-Identifier: Apache-2.0
 *
 * Change Logs:
 * Date           Author          Notes
 * 2020-04-02     Huaqi Fang      first version
 *
 */

#ifndef __BOARD__
#define __BOARD__

#include "platform.h"

void rt_hw_board_init(void);

#define UART0 ((UART_TypeDef *)UART0_BASE)
#define UART1 ((UART_TypeDef *)UART1_BASE)
#define GPIO0 ((GPIO_TypeDef *)GPIO0_BASE)

#endif /* __BOARD__ */

/******************** end of file *******************/
