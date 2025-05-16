#=======================================================================
# Makefile for assembly tests in c_src
#-----------------------------------------------------------------------

include $(SIM_ROOT_DIR)/make.conf

ASM_SRC_DIR := $(SIM_ROOT_DIR)/c_src
OUT_DIR := $(BUILD_DIR)/asm_compiled

RISCV_GCC_FLAGS ?= -static -mcmodel=medany -fvisibility=hidden -nostdlib -nostartfiles

# 根据编译器版本设置不同的架构标志
ifeq ($(USE_OPEN_GNU_GCC),1)
  MARCH_FLAGS := -march=rv$(XLEN)imf_zifencei -mabi=ilp32
else
  MARCH_FLAGS := -march=rv$(XLEN)imf -mabi=ilp32
endif

asm_sources := $(wildcard $(ASM_SRC_DIR)/*.s)
asm_tests := $(basename $(notdir $(asm_sources)))
asm_outs := $(addprefix $(OUT_DIR)/, $(asm_tests))
asm_dumps := $(addsuffix .dump, $(asm_outs))
asm_verilogs := $(addsuffix .verilog, $(asm_outs))

vpath %.s $(ASM_SRC_DIR)

default: compile_asm

%.dump: % 
	$(OBJDUMP) --disassemble-all $< > $@
	$(OBJCOPY) -O verilog $< $<.verilog

$(OUT_DIR)/%: %.s
	$(CC) $(RISCV_GCC_FLAGS) $(MARCH_FLAGS) -I $(ISA_TEST_DIR)/test_libs -I $(SOTFWARE_TEST_DIR)/common_libs -T $(ISA_TEST_DIR)/test_libs/link.ld $< -o $@

$(OUT_DIR):
	mkdir -p $(OUT_DIR)

compile_asm: $(OUT_DIR) $(asm_dumps)

clean:
	rm -rf $(OUT_DIR)

.PHONY: compile_asm clean default
