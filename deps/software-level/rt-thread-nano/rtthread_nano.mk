ifndef SIM_ROOT_DIR
$(error SIM_ROOT_DIR is not set. Please pass SIM_ROOT_DIR from the main Makefile, e.g. 'make SIM_ROOT_DIR=/path/to/sim_root')
endif

include $(SIM_ROOT_DIR)/make.conf

RT_THREAD_ROOT := $(SIM_ROOT_DIR)/deps/software-level/rt-thread-nano

BSP_DIR := $(SIM_ROOT_DIR)/deps/software-level/bsp
BUILD_DIR ?= .
BIN_TO_MEM := $(BSP_DIR)/../../tools/BinToMem.py

# 自动搜索汇编和C源文件
ASM_SRCS := $(wildcard $(BSP_DIR)/*.S)
C_SRCS := $(wildcard $(BSP_DIR)/lib/*.c)

# 自动递归查找所有C和S文件（包含小写.s）
C_SRCS += $(shell find $(RT_THREAD_ROOT) -type f -name "*.c")
ASM_SRCS += $(shell find $(RT_THREAD_ROOT) -type f \( -name "*.S" -o -name "*.s" \))

INCLUDES += -I$(BSP_DIR)/include

# 自动递归查找所有包含头文件的目录
INCLUDE_DIRS := $(shell find $(RT_THREAD_ROOT) -type d -exec bash -c 'ls "$$0"/*.h &>/dev/null && echo "$$0"' {} \;)
INCLUDES += $(addprefix -I, $(INCLUDE_DIRS))

LINKER_SCRIPT := $(BSP_DIR)/link.lds


# 目标文件和产物输出到BUILD_DIR（保持目录结构）
C_OBJS := $(patsubst $(RT_THREAD_ROOT)/%.c,${BUILD_DIR}/%.o,$(C_SRCS))
ASM_OBJS := $(patsubst $(RT_THREAD_ROOT)/%.S,${BUILD_DIR}/%.o,$(filter %.S,$(ASM_SRCS)))
ASM_OBJS += $(patsubst $(RT_THREAD_ROOT)/%.s,${BUILD_DIR}/%.o,$(filter %.s,$(ASM_SRCS)))

LINK_OBJS := $(ASM_OBJS) $(C_OBJS)
LINK_DEPS := $(LINKER_SCRIPT)

TARGET ?= ${BUILD_DIR}/main.elf

CLEAN_OBJS += $(TARGET) $(LINK_OBJS) ${BUILD_DIR}/main.dump ${BUILD_DIR}/main.bin ${BUILD_DIR}/main.hex ${BUILD_DIR}/main.mem

# CFLAGS 和 LDFLAGS
CFLAGS += --sysroot=$(RISCV_GCC_ROOT)/riscv64-unknown-elf
CFLAGS += -march=$(DEFAULT_RISCV_ARCH)
CFLAGS += -mabi=$(DEFAULT_RISCV_ABI)
CFLAGS += -mcmodel=$(DEFAULT_RISCV_MCMODEL)
CFLAGS += -ffunction-sections -fdata-sections -fno-builtin-printf -fno-builtin-malloc
CFLAGS += -fno-common -funroll-loops -finline-functions --param max-inline-insns-auto=20 -falign-functions=4 -falign-jumps=4 -falign-loops=4
CFLAGS += -fno-strict-aliasing -frename-registers
CFLAGS += -O3 -mtune=alioth

COREMARK_CFLAGS := "\"-O3 -mtune=alioth -ffunction-sections -fdata-sections -fno-common -funroll-loops -finline-functions --param max-inline-insns-auto=20 -falign-functions=4 -falign-jumps=4 -falign-loops=4 -fno-strict-aliasing -frename-registers\""

CFLAGS += -DRTOS_RTTHREAD=1
CFLAGS += -DFLAGS_STR=$(COREMARK_CFLAGS)


# CFLAGS += -DSIMULATION_XLSPIKE

LDFLAGS += -nostartfiles -nostdlib -T $(LINKER_SCRIPT)
LDFLAGS += -Wl,--gc-sections
LDFLAGS += -march=$(DEFAULT_RISCV_ARCH)
LDFLAGS += -mabi=$(DEFAULT_RISCV_ABI)

.PHONY: all
all: $(TARGET)

$(TARGET): $(LINK_OBJS) $(LINK_DEPS) Makefile
	$(CC) $(CFLAGS) $(INCLUDES) $(LINK_OBJS) -o $@ $(LDFLAGS) -lc -lgcc
	$(OBJCOPY) -O binary $@ ${BUILD_DIR}/main.bin
	$(OBJDUMP) -d $@ > ${BUILD_DIR}/main.dump
	$(OBJCOPY) -O verilog $@ ${BUILD_DIR}/main.verilog
	@if [ -n "$${SIM_ROOT_DIR}" ]; then \
		${SIM_ROOT_DIR}/deps/tools/split_memory.sh ${BUILD_DIR}/main.verilog; \
	fi

# 编译规则，自动创建目录
${BUILD_DIR}/%.o: $(RT_THREAD_ROOT)/%.c
	@mkdir -p $(dir $@)
	$(CC) $(CFLAGS) $(INCLUDES) -c -o $@ $<

${BUILD_DIR}/%.o: $(RT_THREAD_ROOT)/%.S
	@mkdir -p $(dir $@)
	$(CC) $(CFLAGS) $(INCLUDES) -c -o $@ $<

${BUILD_DIR}/%.o: $(RT_THREAD_ROOT)/%.s
	@mkdir -p $(dir $@)
	$(CC) $(CFLAGS) $(INCLUDES) -c -o $@ $<
	$(CC) $(CFLAGS) $(INCLUDES) -c -o $@ $<
