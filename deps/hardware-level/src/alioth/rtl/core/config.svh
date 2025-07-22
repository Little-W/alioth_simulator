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
`define APB_ADDR_WIDTH 30  // APB地址宽度，30位
`define APB_BASE_ADDR 32'h4000_0000          // APB基地址
`define APB_SIZE (1 << `APB_ADDR_WIDTH)      // APB大小
`define APB_SLAVE_ADDR_WIDTH 12 // APB从设备地址宽度，12位对应4KB

// 内存初始化控制
`define INIT_ITCM 0       // 控制ITCM是否初始化，1表示初始化，0表示不初始化
`define ITCM_INIT_FILE "/media/5/Projects/RISC-V/alioth_simulator/deps/tools/prog.mem" // ITCM初始化文件路径

// 总线宽度定义
`define BUS_DATA_WIDTH 32
`define BUS_ADDR_WIDTH 32
`define BUS_ID_WIDTH 2

`define INST_DATA_WIDTH 32
`define INST_ADDR_WIDTH 32

// 寄存器配置
`define REG_ADDR_WIDTH 5
`define REG_DATA_WIDTH 32
`define DOUBLE_REG_WIDTH 64
`define REG_NUM 32
`define COMMIT_ID_WIDTH 2

// APB外设地址空间定义
`define APB_DEV0_ADDR_LOW  30'h0000_0000 // UART
`define APB_DEV0_ADDR_HIGH 30'h0000_0FFF // UART，4KB地址空间

`define APB_DEV1_ADDR_LOW  30'h0000_1000 // SPI
`define APB_DEV1_ADDR_HIGH 30'h0000_1FFF // SPI，4KB地址空间

`define APB_DEV2_ADDR_LOW  30'h0000_2000 // I2C
`define APB_DEV2_ADDR_HIGH 30'h0000_2FFF // I2C，4KB地址空间

`define APB_DEV3_ADDR_LOW  30'h0000_3000 // GPIO
`define APB_DEV3_ADDR_HIGH 30'h0000_3FFF // GPIO，4KB地址空间

`define APB_DEV4_ADDR_LOW  30'h0000_4000 // Timer
`define APB_DEV4_ADDR_HIGH 30'h0000_4FFF // Timer，4KB地址空间

`define APB_DEV_COUNT 5    // 外设数量

`define FPGA_SOURCE 1 // FPGA源代码标志