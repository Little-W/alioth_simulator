/*
 * Copyright (c) 2006-2020, RT-Thread Development Team
 *
 * SPDX-License-Identifier: Apache-2.0
 *
 * Change Logs:
 * Date           Author       Notes
 * 2020-04-22     hqfang       First version
 */

#include <drv_uart.h>
#include "uart.h" // 新增，包含裸机UART函数声明

#ifdef RT_USING_SERIAL

#if !defined(BSP_USING_UART0) && !defined(BSP_USING_UART1)
#error "Please define at least one BSP_USING_UARTx"
/* this driver can be enabled at menuconfig ->
Hardware Drivers Config -> On-chip Peripheral Drivers -> Enable UART */
#endif

enum
{
#ifdef BSP_USING_UART0
    UART0_INDEX,
#endif
#ifdef BSP_USING_UART1
    UART1_INDEX,
#endif
};

static struct alioth_uart_config uart_config[] =
    {
#ifdef BSP_USING_UART0
        {
            "uart0",
            UART0,
            UART0_IRQn,
        },
#endif
#ifdef BSP_USING_UART1
        {
            "uart1",
            UART1,
            UART1_IRQn,
        },
#endif
};

static struct alioth_uart uart_obj[sizeof(uart_config) / sizeof(uart_config[0])] = {0};

void uart_irq_handler(void *arg);
static void alioth_uart_isr(struct rt_serial_device *serial); // 前置声明

static rt_err_t alioth_control(struct rt_serial_device *serial, int cmd,
                               void *arg)
{
    struct alioth_uart *uart_obj;
    struct alioth_uart_config *uart_cfg;

    RT_ASSERT(serial != RT_NULL);
    uart_obj = (struct alioth_uart *)serial->parent.user_data;
    uart_cfg = uart_obj->config;
    RT_ASSERT(uart_cfg != RT_NULL);

    switch (cmd)
    {
    case RT_DEVICE_CTRL_CLR_INT:
        // 通过uninstall handler实现中断关闭
        plic_disable_irq(uart_cfg->irqn);
        uart_disable_rx_th_int(uart_cfg->uart);
        break;
    case RT_DEVICE_CTRL_SET_INT:
        // 通过install handler实现中断使能
        plic_enable_irq(uart_cfg->irqn);
        plic_set_priority(uart_cfg->irqn, 2); // 设置优先级为2
        plic_set_handler(uart_cfg->irqn, uart_irq_handler, serial);
        uart_set_rx_th(uart_cfg->uart, UART_RX_FIFO_TH_1BYTE); // 设置接收FIFO中断触发等级为1字节
        uart_enable_rx_th_int(uart_cfg->uart);
        break;
    }

    return RT_EOK;
}

static rt_err_t alioth_configure(struct rt_serial_device *serial,
                                 struct serial_configure *cfg)
{
    struct alioth_uart *uart_obj;
    struct alioth_uart_config *uart_cfg;
    RT_ASSERT(serial != RT_NULL);
    RT_ASSERT(cfg != RT_NULL);

    uart_obj = (struct alioth_uart *)serial->parent.user_data;
    uart_cfg = uart_obj->config;
    RT_ASSERT(uart_cfg != RT_NULL);

    // 移植裸机初始化函数
    uart_init(uart_cfg->uart, cfg->baud_rate);

    switch (cfg->stop_bits)
    {
    case STOP_BITS_1:
        uart_config_stopbit(uart_cfg->uart, UART_STOP_BIT_1);
        break;
    case STOP_BITS_2:
        uart_config_stopbit(uart_cfg->uart, UART_STOP_BIT_2);
        break;
    default:
        uart_config_stopbit(uart_cfg->uart, UART_STOP_BIT_1);
        break;
    }

    // 配置奇偶校验
    switch (cfg->parity)
    {
    case PARITY_ODD:
        uart_enable_paritybit(uart_cfg->uart);
        uart_set_parity(uart_cfg->uart, UART_ODD);
        break;
    case PARITY_EVEN:
        uart_enable_paritybit(uart_cfg->uart);
        uart_set_parity(uart_cfg->uart, UART_EVEN);
        break;
    case PARITY_NONE:
    default:
        uart_disable_paritybit(uart_cfg->uart);
        break;
    }

    /* 启用中断 */
    alioth_control(serial, RT_DEVICE_CTRL_SET_INT, RT_NULL);

    return RT_EOK;
}

static int alioth_putc(struct rt_serial_device *serial, char ch)
{
    struct alioth_uart *uart_obj;
    struct alioth_uart_config *uart_cfg;

    RT_ASSERT(serial != RT_NULL);
    uart_obj = (struct alioth_uart *)serial->parent.user_data;
    uart_cfg = uart_obj->config;
    RT_ASSERT(uart_cfg != RT_NULL);

    // 移植裸机发送函数
    uart_write(uart_cfg->uart, (uint8_t)ch);

    return 1;
}

static int alioth_getc(struct rt_serial_device *serial)
{
    struct alioth_uart *uart_obj;
    struct alioth_uart_config *uart_cfg;

    RT_ASSERT(serial != RT_NULL);
    uart_obj = (struct alioth_uart *)serial->parent.user_data;
    uart_cfg = uart_obj->config;
    RT_ASSERT(uart_cfg != RT_NULL);

    // 移植裸机接收函数
    if ((uart_cfg->uart->LSR & 0x1) == 0)
        return -1;
    return uart_read(uart_cfg->uart);
}

static const struct rt_uart_ops alioth_uart_ops = {alioth_configure, alioth_control,
                                                   alioth_putc, alioth_getc,
                                                   RT_NULL};

static void alioth_uart_isr(struct rt_serial_device *serial)
{
    struct alioth_uart *uart_obj;
    struct alioth_uart_config *uart_cfg;

    RT_ASSERT(serial != RT_NULL);
    uart_obj = (struct alioth_uart *)serial->parent.user_data;
    uart_cfg = uart_obj->config;
    RT_ASSERT(uart_cfg != RT_NULL);

    // 用 LSR 判断是否有数据可读
    if (uart_cfg->uart->LSR & 0x1)
    {
        rt_hw_serial_isr(serial, RT_SERIAL_EVENT_RX_IND);
    }
}

void uart_irq_handler(void *arg)
{
    struct rt_serial_device *serial = (struct rt_serial_device *)arg;
    struct alioth_uart *uart_obj;
    struct alioth_uart_config *uart_cfg;
    rt_interrupt_enter();
    alioth_uart_isr(serial);
    rt_interrupt_leave();
}

#define DRV_UART_BAUDRATE BAUD_RATE_115200

int rt_hw_uart_init(void)
{
    rt_size_t obj_num;
    int index;

    obj_num = sizeof(uart_obj) / sizeof(struct alioth_uart);
    struct serial_configure config = RT_SERIAL_CONFIG_DEFAULT;
    config.baud_rate = DRV_UART_BAUDRATE;
    rt_err_t result = 0;

    for (index = 0; index < obj_num; index++)
    {
        /* init UART object */
        uart_obj[index].config = &uart_config[index];
        uart_obj[index].serial.ops = &alioth_uart_ops;
        uart_obj[index].serial.config = config;

        /* register UART device */
        result = rt_hw_serial_register(&uart_obj[index].serial,
                                       uart_obj[index].config->name,
                                       RT_DEVICE_FLAG_RDWR | RT_DEVICE_FLAG_INT_RX,
                                       &uart_obj[index]);
        RT_ASSERT(result == RT_EOK);
    }

    return result;
}

void rt_hw_serial_rcvtsk(void *parameter)
{
    struct alioth_uart_config *uart_cfg;

    while (1)
    {
#ifdef BSP_USING_UART0
        uart_cfg = uart_obj[UART0_INDEX].config;
        if (uart_cfg->uart->LSR & 0x1)
        {
            alioth_uart_isr(&uart_obj[UART0_INDEX].serial);
        }
#endif
#ifdef BSP_USING_UART1
        uart_cfg = uart_obj[UART1_INDEX].config;
        if (uart_cfg->uart->LSR & 0x1)
        {
            alioth_uart_isr(&uart_obj[UART1_INDEX].serial);
        }
#endif
        rt_thread_mdelay(50);
    }
}

#endif /* RT_USING_SERIAL */