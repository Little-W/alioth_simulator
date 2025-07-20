// 内存和地址配置
`define ITCM_ADDR_WIDTH 16  // ITCM地址宽度，16位对应64KB
`define DTCM_ADDR_WIDTH 16  // DTCM地址宽度，16位对应64KB

`define PC_RESET_ADDR 32'h8000_0000

// 内存映射地址
`define ITCM_BASE_ADDR 32'h8000_0000         // ITCM基地址
`define ITCM_SIZE (1 << `ITCM_ADDR_WIDTH)     // ITCM大小：64KB
`define DTCM_BASE_ADDR 32'h8010_0000 // DTCM基地址
`define DTCM_SIZE (1 << `DTCM_ADDR_WIDTH)     // DTCM大小：64KB

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

`define DCSR_CAUSE_STEP         3'h4
`define DCSR_CAUSE_DBGREQ       3'h3
`define DCSR_CAUSE_EBREAK       3'h1
`define DCSR_CAUSE_HALT         3'h5
`define DCSR_CAUSE_TRIGGER      3'h2

