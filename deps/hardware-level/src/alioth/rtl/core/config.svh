// 内存和地址配置
`define ITCM_ADDR_WIDTH 16  // ITCM地址宽度，16位对应64KB
`define DTCM_ADDR_WIDTH 16  // DTCM地址宽度，16位对应64KB

`define PC_RESET_ADDR 32'h8000_0000

// 内存映射地址
`define ITCM_BASE_ADDR 32'h8000_0000         // ITCM基地址
`define ITCM_SIZE (1 << `ITCM_ADDR_WIDTH)     // ITCM大小：64KB
`define DTCM_BASE_ADDR 32'h8010_0000 // DTCM基地址
`define DTCM_SIZE (1 << `DTCM_ADDR_WIDTH)     // DTCM大小：64KB

// APB地址配置
`define APB_ADDR_WIDTH 20  // APB地址宽度，20位
`define APB_BASE_ADDR 32'h8400_0000          // APB基地址
`define APB_SIZE (1 << `APB_ADDR_WIDTH)      // APB大小
`define APB_SLAVE_ADDR_WIDTH 20 // APB从设备地址宽度

// CLINT地址配置
`define CLINT_ADDR_WIDTH 16  // CLINT地址宽度，16位
`define CLINT_BASE_ADDR 32'h0200_0000        // CLINT基地址
`define CLINT_SIZE (1 << `CLINT_ADDR_WIDTH)  // CLINT大小：64KB

// PLIC地址配置
`define PLIC_ADDR_WIDTH 16   // PLIC地址宽度，16位
`define PLIC_BASE_ADDR 32'h0C00_0000         // PLIC基地址
`define PLIC_SIZE (1 << `PLIC_ADDR_WIDTH)    // PLIC大小：64KB

// 内存初始化控制
`define INIT_ITCM 0       // 控制ITCM是否初始化，1表示初始化，0表示不初始化
`define ITCM_INIT_FILE "main_itcm.mem" // ITCM初始化文件路径

`define INIT_DTCM 0       // 控制DTCM是否初始化，1表示初始化，0表示不初始化
`define DTCM_INIT_FILE "main_dtcm.mem" // ITCM初始化文件路径

// 总线宽度定义
`define BUS_DATA_WIDTH 32
`define BUS_ADDR_WIDTH 32
`define BUS_ID_WIDTH 2

`define INST_DATA_WIDTH 32
`define INST_ADDR_WIDTH 32

// 寄存器配置
`define REG_ADDR_WIDTH 6
`define GREG_ADDR_WIDTH 5
`define FREG_ADDR_WIDTH 5
`define GREG_DATA_WIDTH 32
`define FREG_DATA_WIDTH 64
`define REG_DATA_WIDTH 32
`define DOUBLE_REG_WIDTH 64
`define REG_NUM 32
`define COMMIT_ID_WIDTH 3

// APB外设地址空间定义（顺序：Timer, SPI, I2C0, I2C1, UART0, UART1, GPIO0, GPIO1）
`define APB_DEV7_ADDR_LOW  20'h00000 // Timer
`define APB_DEV7_ADDR_HIGH 20'h00FFF // Timer，4KB地址空间

`define APB_DEV2_ADDR_LOW  20'h01000 // SPI
`define APB_DEV2_ADDR_HIGH 20'h01FFF // SPI，4KB地址空间

`define APB_DEV3_ADDR_LOW  20'h02000 // I2C0
`define APB_DEV3_ADDR_HIGH 20'h02FFF // I2C0，4KB地址空间

`define APB_DEV4_ADDR_LOW  20'h03000 // I2C1
`define APB_DEV4_ADDR_HIGH 20'h03FFF // I2C1，4KB地址空间

`define APB_DEV0_ADDR_LOW  20'h04000 // UART0
`define APB_DEV0_ADDR_HIGH 20'h04FFF // UART0，4KB地址空间

`define APB_DEV1_ADDR_LOW  20'h05000 // UART1
`define APB_DEV1_ADDR_HIGH 20'h05FFF // UART1，4KB地址空间

`define APB_DEV5_ADDR_LOW  20'h06000 // GPIO0
`define APB_DEV5_ADDR_HIGH 20'h06FFF // GPIO0，4KB地址空间

`define APB_DEV6_ADDR_LOW  20'h07000 // GPIO1
`define APB_DEV6_ADDR_HIGH 20'h07FFF // GPIO1，4KB地址空间

`define APB_DEV_COUNT 8    // 外设数量

`define FPGA_SOURCE 1 // FPGA源代码标志