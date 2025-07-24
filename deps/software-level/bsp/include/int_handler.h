#ifndef __INT_HANDLER_H__
#define __INT_HANDLER_H__

#ifdef __cplusplus
extern "C"
{
#endif

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
