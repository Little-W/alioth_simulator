// 内存和地址配置
`define ITCM_ADDR_WIDTH 16  // ITCM地址宽度，16位对应64KB
`define DTCM_ADDR_WIDTH 16  // DTCM地址宽度，16位对应64KB

// 内存映射地址
`define ITCM_BASE_ADDR 32'h0         // ITCM基地址
`define ITCM_SIZE      (1 << `ITCM_ADDR_WIDTH)     // ITCM大小：64KB
`define DTCM_BASE_ADDR (1 << `ITCM_ADDR_WIDTH)     // DTCM基地址
`define DTCM_SIZE      (1 << `DTCM_ADDR_WIDTH)     // DTCM大小：64KB

// 总线宽度定义 - 规范化命名
`define BUS_DATA_WIDTH 32
`define BUS_ADDR_WIDTH 32

`define INST_DATA_WIDTH 32
`define INST_ADDR_WIDTH 32

// common regs
`define REG_ADDR_WIDTH 5
`define REG_DATA_WIDTH 32
`define DOUBLE_REG_WIDTH 64
`define REG_NUM 32