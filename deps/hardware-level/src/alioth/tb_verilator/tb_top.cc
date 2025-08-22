#include "Vtb_top.h"
#include "verilated.h"
#include "verilated_vcd_c.h"
#include <iostream>
#include <string>
#include <queue>
#include <thread>
#include <atomic>
#include <mutex>
#include <condition_variable>

#ifdef JTAGVPI
#include "jtagServer.h"
#endif

vluint64_t tick = 0;

#ifdef ENABLE_UART_SIM
// UART RX仿真相关变量
std::queue<uint8_t> uart_rx_queue;
std::mutex uart_rx_mutex;
std::atomic<bool> uart_rx_ready{false};
std::condition_variable uart_rx_cv;

// UART协议相关参数
constexpr double UART_BAUD = 115200.0;
constexpr double CLK_FREQ = 242000000.0; // 100MHz
constexpr long UART_BIT_TICKS = static_cast<long>(CLK_FREQ / UART_BAUD + 0.5); // 四舍五入为整数

// UART RX状态机
struct UartRxState {
    bool active = false;
    uint16_t frame = 0;
    int bit_idx = 0;
    long tick_cnt = 0;
};

UartRxState uart_rx_state;

// 串口输入监听线程
void uart_input_thread() {
    while (true) {
        int ch = getchar();
        if (ch == EOF) break;
        {
            std::lock_guard<std::mutex> lock(uart_rx_mutex);
            uart_rx_queue.push(static_cast<uint8_t>(ch));
            uart_rx_ready = true;
            // std::cout << "UART RX: Received char '" << static_cast<char>(ch) << "'\n";
        }
        uart_rx_cv.notify_one();
    }
}
#endif // ENABLE_UART_SIM

int main(int argc, char **argv) {
    Verilated::commandArgs(argc, argv);
    Vtb_top *soc = new Vtb_top;

    // check if trace is enabled
    int trace_en = 0;
    for (int i = 0; i < argc; i++)
    {
        if (strcmp(argv[i], "-t") == 0)
            trace_en = 1;
        if (strcmp(argv[i], "--trace") == 0)
            trace_en = 1;
    }

    if (trace_en)
    {
        std::cout << "Trace is enabled.\n";
    }
    else
    {
        std::cout << "Trace is disabled.\n";
    }
#ifdef JTAGVPI
        VerilatorJtagServer* jtag = new VerilatorJtagServer(10);
        jtag->init_jtag_server(5555, false);
    #endif
    //enable waveform
    VerilatedVcdC* tfp = new VerilatedVcdC;
    if (trace_en)
    {
        Verilated::traceEverOn(true);
        soc->trace(tfp, 99); // Trace 99 levels of hierarchy
        tfp->open("tb_top.vcd");
    }

    soc->clk = 0;
    soc->rst_n = 0;
    soc->eval();
    // 修改为：仅当dump_en为1时才dump
    if (trace_en && soc->dump_en) tfp->dump(tick); tick++;

    // enough time to reset
    for (int i = 0; i < 100; i++)
    {
        soc->clk = !soc->clk;
        soc->eval();
        if (trace_en && soc->dump_en)
        {
            tfp->dump(tick);
            tick++;
            tfp->dump(tick); // 第二次时间尺度更新
            tick++;
        }
    }

    soc->rst_n = 1;
    soc->eval();

    for (int i = 0; i < 50000; i++)
    {
        soc->clk = !soc->clk;
        soc->eval();
        if (trace_en && soc->dump_en)
        {
            tfp->dump(tick);
            tick++;
            tfp->dump(tick); // 第二次时间尺度更新
            tick++;
        }
    }

#ifdef ENABLE_UART_SIM
    // 启动串口输入监听线程
    std::thread uart_thread(uart_input_thread);

    soc->uart_rx = 1; // 空闲为高电平
    bool prev_clk = soc->clk;
#endif

    while (!Verilated::gotFinish())
    {
        soc->clk = !soc->clk;
        soc->eval();

#ifdef ENABLE_UART_SIM
        // 仅在时钟上升沿处理UART RX
        if (prev_clk == 0 && soc->clk == 1) {
            // UART RX驱动逻辑
            if (!uart_rx_state.active) {
                std::unique_lock<std::mutex> lock(uart_rx_mutex);
                if (!uart_rx_queue.empty()) {
                    uint8_t data = uart_rx_queue.front();
                    uart_rx_queue.pop();
                    lock.unlock();

                    // 构造UART帧：1起始位(0)+8数据位+1停止位(1)
                    uart_rx_state.frame = (1 << 9) | (data << 1) | 0;
                    uart_rx_state.bit_idx = 0;
                    uart_rx_state.tick_cnt = 0;
                    uart_rx_state.active = true;
                } else {
                    lock.unlock();
                }
            }

            if (uart_rx_state.active) {
                if (uart_rx_state.tick_cnt == 0) {
                    // 发送当前bit
                    soc->uart_rx = (uart_rx_state.frame >> uart_rx_state.bit_idx) & 0x1;
                }
                uart_rx_state.tick_cnt++;
                if (uart_rx_state.tick_cnt >= UART_BIT_TICKS) {
                    uart_rx_state.tick_cnt = 0;
                    uart_rx_state.bit_idx++;
                    if (uart_rx_state.bit_idx >= 10) {
                        uart_rx_state.active = false;
                        soc->uart_rx = 1; // 停止位后回到高电平
                    }
                }
            }
        }
        prev_clk = soc->clk;
#endif // ENABLE_UART_SIM

#ifdef JTAGVPI
        jtag->doJTAG(tick, &soc->tms_i, &soc->tdi_i, &soc->tck_i, soc->tdo_o);
#endif
        if (trace_en && soc->dump_en)
        {
            tfp->dump(tick);
            tick++;
            tfp->dump(tick); // 第二次时间尺度更新
            tick++;
        }
    }

#ifdef ENABLE_UART_SIM
    uart_thread.detach(); // 或 join，视情况而定
#endif

    if (trace_en)
    {
        tfp->close();
    }
    delete soc;

    return 0;
}
