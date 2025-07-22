#include <stdint.h>
#include "uart.h"
#include "xprintf.h"

// 全局UART0变量
UART_TypeDef *uart0 = (UART_TypeDef *)UART0_BASE;

int main()
{

    xprintf("Hello, World!\n");

    while (1);
}
