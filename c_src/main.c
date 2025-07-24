#include <stdint.h>
#include "platform.h"

int main()
{

    printf("Hello, World!\n");
    __enable_irq(); // Enable global interrupts
    printf("Global interrupts enabled.\n");
    __enable_sw_irq(); // Enable software interrupts
    printf("Software interrupts enabled.\n");
    // delay_1ms(20);
    printf("Ready to trigger a software interrupt...\n");
    // Trigger a software interrupt
    CLINT_SetSWIRQ();
    printf("Software interrupt triggered.\n");
    printf("Triggering a software interrupt again...\n");
    CLINT_SetSWIRQ();
    printf("Software interrupt triggered again.\n");

    while (1);
}
