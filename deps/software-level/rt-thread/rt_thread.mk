ifndef RT_THREAD_ROOT
$(error RT_THREAD_ROOT is not defined, using default value)
RT_THREAD_ROOT := $(abspath ../..)
endif

RTTHREAD_BSP_DIR      := $(RT_THREAD_ROOT)/bsp

ifndef SIM_ROOT_DIR
$(error SIM_ROOT_DIR is not set. Please pass SIM_ROOT_DIR from the main Makefile, e.g. 'make SIM_ROOT_DIR=/path/to/sim_root')
endif

include $(SIM_ROOT_DIR)/make.conf

BUILD_DIR ?= .
TARGET ?= ${BUILD_DIR}/rtthread.elf

.PHONY: all
all: $(TARGET)

$(TARGET):
	@echo "==> Building RT-Thread BSP with scons"
	@cd $(RTTHREAD_BSP_DIR) && SOFTWARE_TOOLS_DIR=$(SOFTWARE_TOOLS_DIR) BSP_DIR=$(BSP_DIR) RTT_ROOT=$(RT_THREAD_ROOT) scons
	@mkdir -p $(BUILD_DIR)
	@cp $(RTTHREAD_BSP_DIR)/rtthread.elf $(TARGET)
	$(OBJCOPY) -O binary $(TARGET) ${BUILD_DIR}/main.bin
	$(OBJDUMP) -d $(TARGET) > ${BUILD_DIR}/main.dump
	$(OBJCOPY) -O verilog $(TARGET) ${BUILD_DIR}/main.verilog
	@if [ -n "$${SIM_ROOT_DIR}" ]; then \
		${SIM_ROOT_DIR}/deps/tools/split_memory.sh ${BUILD_DIR}/main.verilog; \
	fi