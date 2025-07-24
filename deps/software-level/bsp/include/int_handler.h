#ifndef __INT_HANDLER_H__
#define __INT_HANDLER_H__

#ifdef __cplusplus
extern "C"
{
#endif

    typedef enum IRQn
    {
        Reserved0_IRQn = 0,   /*!<  Internal reserved */
        Reserved1_IRQn = 1,   /*!<  Internal reserved */
        Reserved2_IRQn = 2,   /*!<  Internal reserved */
        SysTimerSW_IRQn = 3,  /*!<  System Timer SW interrupt */
        Reserved4_IRQn = 4,   /*!<  Internal reserved */
        Reserved5_IRQn = 5,   /*!<  Internal reserved */
        Reserved6_IRQn = 6,   /*!<  Internal reserved */
        SysTimer_IRQn = 7,    /*!<  System Timer Interrupt */
        Reserved8_IRQn = 8,   /*!<  Internal reserved */
        Reserved9_IRQn = 9,   /*!<  Internal reserved */
        Reserved10_IRQn = 10, /*!<  Internal reserved */
        Reserved11_IRQn = 11, /*!<  Internal reserved */
        Reserved12_IRQn = 12, /*!<  Internal reserved */
        Reserved13_IRQn = 13, /*!<  Internal reserved */
        Reserved14_IRQn = 14, /*!<  Internal reserved */
        Reserved15_IRQn = 15, /*!<  Internal reserved */

        Timer0_IRQn = 16,     /*!<  Timer0 interrupt */
        Timer1_IRQn = 17,     /*!<  Timer1 interrupt */
        Timer2_IRQn = 18,     /*!<  Timer2 interrupt */
        Timer3_IRQn = 19,     /*!<  Timer3 interrupt */
        SPI_IRQn = 20,        /*!<  SPI interrupt */
        I2C0_IRQn = 21,       /*!<  I2C0 interrupt */
        I2C1_IRQn = 22,       /*!<  I2C1 interrupt */
        UART0_IRQn = 23,      /*!<  UART0 interrupt */
        UART1_IRQn = 24,      /*!<  UART1 interrupt */
        GPIO0_IRQn = 25,      /*!<  GPIO0 interrupt */
        GPIO1_IRQn = 26,      /*!<  GPIO1 interrupt */

    } IRQn_Type;

    void timer0_event_handler(void);
    void timer1_event_handler(void);
    void timer2_event_handler(void);
    void timer3_event_handler(void);
    void spi_event_handler(void);
    void i2c0_interrupt_handler(void);
    void i2c1_interrupt_handler(void);
    void uart0_event_handler(void);
    void uart1_event_handler(void);
    void gpio0_int_handler(void);
    void gpio1_int_handler(void);
    void machine_software_interrupt_handler(void);
    void machine_timer_interrupt_handler(void);
    void machine_external_interrupt_handler(void);

#ifdef __cplusplus
}
#endif

#endif // __INT_HANDLER_H__
