#ifndef SYS_DEFS_H
#define SYS_DEFS_H

#ifdef __cplusplus
extern "C"
{
#endif

#ifdef __cplusplus
#include <cstdint>
#else
#include <stdint.h>
#include <stddef.h>
#endif

#ifndef SYSTEM_CLOCK
#define SYSTEM_CLOCK (100000000UL)
#endif

#define ALIOTH_PERIPH_BASE (0x84000000UL) /*!< Alioth APB Peripherals Base Address */

/* Peripheral memory map */
#define PWM_BASE (ALIOTH_PERIPH_BASE + 0x00000)   /*!< (Timer) Base Address */
#define SPI0_BASE (ALIOTH_PERIPH_BASE + 0x01000)  /*!< (SPI0) Base Address */
#define I2C0_BASE (ALIOTH_PERIPH_BASE + 0x02000)  /*!< (I2C0) Base Address */
#define I2C1_BASE (ALIOTH_PERIPH_BASE + 0x03000)  /*!< (I2C1) Base Address */
#define UART0_BASE (ALIOTH_PERIPH_BASE + 0x04000) /*!< (UART0) Base Address */
#define UART1_BASE (ALIOTH_PERIPH_BASE + 0x05000) /*!< (UART1) Base Address */
#define GPIO0_BASE (ALIOTH_PERIPH_BASE + 0x06000) /*!< (GPIO0) Base Address */
#define GPIO1_BASE (ALIOTH_PERIPH_BASE + 0x07000) /*!< (GPIO1) Base Address */

    /**
     * @brief GPIO
     */
    typedef struct
    { /*!< GPIO Structure */
        volatile uint32_t PADDIR;
        volatile uint32_t PADIN;
        volatile uint32_t PADOUT;
        volatile uint32_t INTEN;
        volatile uint32_t INTTYPE0;
        volatile uint32_t INTTYPE1;
        volatile uint32_t INTSTATUS;
        volatile uint32_t IOFCFG;
    } GPIO_TypeDef;

    /**
     * @brief UART
     */
    typedef struct
    {
        union
        {
            volatile uint32_t RBR;
            volatile uint32_t DLL;
            volatile uint32_t THR;
        };
        union
        {
            volatile uint32_t DLM;
            volatile uint32_t IER;
        };
        union
        {
            volatile uint32_t IIR;
            volatile uint32_t FCR;
        };
        volatile uint32_t LCR;
        volatile uint32_t MCR;
        volatile uint32_t LSR;
        volatile uint32_t MSR;
        volatile uint32_t SCR;
    } UART_TypeDef;

    /**
     * @brief QSPI
     */
    typedef struct
    {
        volatile uint32_t SCKDIV;
        volatile uint32_t SCKMODE;
        volatile uint32_t RESERVED0[2];
        volatile uint32_t CSID;
        volatile uint32_t CSDEF;
        volatile uint32_t CSMODE;
        volatile uint32_t RESERVED1[3];
        volatile uint32_t DELAY0;
        volatile uint32_t DELAY1;
        volatile uint32_t RESERVED2[4];
        volatile uint32_t FMT;
        volatile uint32_t RESERVED3;
        volatile uint32_t TXDATA;
        volatile uint32_t RXDATA;
        volatile uint32_t TXMARK;
        volatile uint32_t RXMARK;
        volatile uint32_t RESERVED4[2];
        volatile uint32_t FCTRL;
        volatile uint32_t FFMT;
        volatile uint32_t RESERVED5[2];
        volatile uint32_t IE;
        volatile uint32_t IP;
    } QSPI_TypeDef;

    /**
     * @brief SPI
     */
    typedef struct
    {
        volatile uint32_t STATUS;
        volatile uint32_t CLKDIV;
        volatile uint32_t SPICMD;
        volatile uint32_t SPIADR;
        volatile uint32_t SPILEN;
        volatile uint32_t SPIDUM;
        volatile uint32_t TXFIFO;
        volatile uint32_t Pad;
        volatile uint32_t RXFIFO;
        volatile uint32_t INTCFG;
        volatile uint32_t INTSTA;
    } SPI_TypeDef;

    /**
     * @brief I2C
     */
    typedef struct
    {
        volatile uint32_t PRE;
        volatile uint32_t CTR;
        volatile uint32_t RX;
        volatile uint32_t STATUS;
        volatile uint32_t TX;
        volatile uint32_t CMD;
    } I2C_TypeDef;

    /**
     * @brief PWM
     */
    typedef enum
    {
        PWM_TIMER0 = 0,
        PWM_TIMER1 = 1,
        PWM_TIMER2 = 2,
        PWM_TIMER3 = 3,
    } PwmTimerNum;

    typedef enum
    {
        PWM_TIMER_TH_CHANNEL0 = 0,
        PWM_TIMER_TH_CHANNEL1 = 1,
        PWM_TIMER_TH_CHANNEL2 = 2,
        PWM_TIMER_TH_CHANNEL3 = 3,
    } PwmTimerThChannel;

    enum
    {
        pwm_timer_event0 = 0,
        pwm_timer_event1,
        pwm_timer_event2,
        pwm_timer_event3,
    };

    typedef enum
    {
        PWM_TIMER_CMD_START = 0x01, /* Start counting */
        PWM_TIMER_CMD_STOP = 0x02,  /* Stop counting */
        PWM_TIMER_CMD_UPD = 0x04,   /* Update timer params */
        PWM_TIMER_CMD_RST = 0x08,   /* Reset counter value */
    } PwmCounterCmd;

    typedef struct
    {
        unsigned int SelectInputSource : 8; /* Select counting condition */
        unsigned int InputEnableIn : 3;     /* Define enable rules:
                                              000, always count (use clock)
                                              001 count when external input is 0
                                              010 count when external input is 1
                                              011 count on rising edge of external
                                              100 count on falling edge of external
                                              101 count on falling and on rising edge of external
                                              */
        unsigned int FllOrRTC : 1;          /* Clock input of counter is Fll or RTC */
        unsigned int IncThenDec : 1;        /* When counter reaches threshold count down if IncThenDec else return to 0 and ocunt up again */
        unsigned int Pad : 3;
        unsigned int PreScaler : 8; /* */
        unsigned int Pad2 : 8;
    } PwmCounterConfig;

    typedef struct
    {
        unsigned int chThreshold : 16; /* Threshold value for the channel of a counter */
        unsigned int chAction : 3;
        /* When counter reaches threshold:
            000: Set
            001: Toggle then next is Clear
            010: Set then Clear
            011: Toggle
            100: Clear
            101: Toggle then next is Set
            110: Clear then Set
        */
        unsigned int Pad : 13;
    } PwmChannelThConfig;

    typedef struct
    {
        unsigned int evt0_sel : 4;
        unsigned int evt1_sel : 4;
        unsigned int evt2_sel : 4;
        unsigned int evt3_sel : 4;
        unsigned int evt_en : 4;
        unsigned int pad : 12;
    } PwmTimerEvt;

    typedef union
    {
        PwmCounterConfig timerConf;
        unsigned int timerTh; /* Threshold value for the counter */
        PwmChannelThConfig ch_ThConfig;
        PwmTimerEvt timerEvt;
        unsigned int Raw;
    } pwm_timer;

/** \brief provide the compiler with branch prediction information, the branch is rarely true */
#ifndef __RARELY
#define __RARELY(exp) __builtin_expect((exp), 0)
#endif

#ifdef __cplusplus
}
#endif
#endif // SYS_DEFS_H

// 全局重定向printf到xprintf
#include "xprintf.h"
#define printf xprintf