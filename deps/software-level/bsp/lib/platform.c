#include "sys_defs.h"
#include "xprintf.h"

void SystemInit(void)
{
    // 初始化UART0，波特率115200
    uart_init((UART_TypeDef *)UART0_BASE, 115200);

    // 初始化xprintf重定向到UART
    xprintf_uart_init();

    // 打印基本信息
    SystemBannerPrint();
}

void SystemBannerPrint(void)
{
#if defined(SDK_BANNER) && (SDK_BANNER == 1)
    printf("Alioth SDK Build Time: %s, %s\r\n", __DATE__, __TIME__);
    printf("CPU Frequency %lu Hz\r\n", SYSTEM_CLOCK);
#endif
}

