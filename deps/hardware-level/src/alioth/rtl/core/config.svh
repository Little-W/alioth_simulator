// 内存和地址配置
`define ITCM_ADDR_WIDTH 16  // ITCM地址宽度，16位对应64KB
`define DTCM_ADDR_WIDTH 16  // DTCM地址宽度，16位对应64KB
`define PERIP_BRIDGE_ADDR_WIDTH 22 // 外设桥地址宽度

`define PC_RESET_ADDR 32'h8000_0000

// 内存映射地址
`define ITCM_BASE_ADDR 32'h8000_0000         // ITCM基地址
`define ITCM_SIZE (1 << `ITCM_ADDR_WIDTH)     // ITCM大小：64KB
`define DTCM_BASE_ADDR 32'h8010_0000 // DTCM基地址
`define DTCM_SIZE (1 << `DTCM_ADDR_WIDTH)     // DTCM大小：64KB

// 内存初始化控制
`define INIT_ITCM 1       // 控制ITCM是否初始化，1表示初始化，0表示不初始化
`define ITCM_INIT_FILE "/media/5/Projects/RISC-V/alioth_simulator/deps/tools/irom.mem" // ITCM初始化文件路径

// DTCM配置
`define INIT_DTCM 1           // 控制DTCM是否初始化，1表示初始化，0表示不初始化
`define DTCM_INIT_FILE "/media/5/Projects/RISC-V/alioth_simulator/deps/tools/dram.mem" // DTCM初始化文件路径

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

`define BPU_COUNT_WIDTH 4  // BPU计数器宽度

// 外设桥地址空间定义 (0x8010_0000~0x8020_0FFF)
`define PERIP_BRIDGE_BASE_ADDR 32'h8010_0000
`define PERIP_BRIDGE_END_ADDR 32'h8020_0FFF

// 外设地址空间定义 (0x8020_0000~0x8020_00FF)
`define PERIP_BASE_ADDR 32'h8020_0000
`define PERIP_END_ADDR 32'h8020_00FF

// SW区域 (0x8020_0000~0x8020_0007)，只读
`define SW0_ADDR 32'h8020_0000  // sw[31:0]
`define SW1_ADDR 32'h8020_0004  // sw[63:32]

// KEY区域 (0x8020_0010~0x8020_0013)，只读
`define KEY_ADDR 32'h8020_0010  // key[7:0]

// SEG区域 (0x8020_0020~0x8020_0023)，读写
`define SEG_ADDR 32'h8020_0020  // 7段数码管

// LED区域 (0x8020_0040~0x8020_0043)，只写
`define LED_ADDR 32'h8020_0040  // led[31:0]

// 计数器区域 (0x8020_0050~0x8020_0053)，读写
`define CNT_ADDR 32'h8020_0050  // counter
`define CNT_START 32'h8000_0000 // 计数开始值
`define CNT_END 32'hFFFF_FFFF // 计数结束值
