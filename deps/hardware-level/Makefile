include $(SIM_ROOT_DIR)/make.conf

DUMPWAVE     := 1
TEST_ALL := 0
SMIC130LL    := 0
GATE_SIM     := 0
GATE_SDF     := 0
GATE_NOTIME     := 0
VSRC_DIR     := ${HARDWARE_SRC_DIR}/${CORE}/rtl
VTB_DIR      := ${BUILD_DIR}/${CORE}_tb/tb
JTAG_DIR 	 := ${HARDWARE_SRC_DIR}/${CORE}/jtag_vpi
TEST_NAME     := $(notdir $(patsubst %.dump,%,${TEST_PROGRAM}))

TRUE_SIM_TOOL := $(shell echo ${SIM_TOOL} | grep -o '[^0-9]*')

#To-ADD: to add the simulatoin tool options
ifeq ($(TRUE_SIM_TOOL),verilator)
VERILATOR_BUILD_DIR := ${BUILD_DIR}/verilator_build
SIM_OPTIONS   := --Mdir ${VERILATOR_BUILD_DIR} 
SIM_OPTIONS   += --cc +incdir+${VSRC_DIR}/core  -CFLAGS -I${VSRC_DIR}/core +incdir+${VSRC_DIR}/perips/ -CFLAGS -I${VSRC_DIR}/perips
SIM_OPTIONS   += +incdir+${VSRC_DIR}/perips/apb_i2c/ -CFLAGS -I${VSRC_DIR}/perips/apb_i2c/
SIM_OPTIONS   += --exe --trace --trace-structs --trace-params --trace-max-array 1024
SIM_OPTIONS   += -CFLAGS "-Wall -DTOPLEVEL_NAME=tb_top -g -O0" -LDFLAGS "-pthread -lutil -lelf"
SIM_OPTIONS   += -Wno-WIDTH -Wno-CASEINCOMPLETE -Wno-UNOPTFLAT -Wno-TIMESCALEMOD -Wno-fatal

ifeq ($(SIM_TOOL),verilator5)
SIM_OPTIONS   += --no-timing
endif
SIM_OPTIONS_BACK := --top-module tb_top --exe
SIM_OPTIONS_BACK   += ${SIM_OPTIONS_COMMON}
VTB_DIR      := ${BUILD_DIR}/${CORE}_tb/tb_verilator
VERILATOR_CC_FILE := ${VTB_DIR}/tb_top.cc
endif

ifeq ($(TRUE_SIM_TOOL),vcs)
SIM_OPTIONS   := +v2k -sverilog -q +lint=all,noSVA-NSVU,noVCDE,noUI,noSVA-CE,noSVA-DIU  -debug_access+all -full64 -timescale=1ns/10ps
SIM_OPTIONS   += +incdir+"${VSRC_DIR}/core/"+"${VSRC_DIR}/perips/"+"${VSRC_DIR}/perips/apb_i2c/"
SIM_OPTIONS   += ${SIM_OPTIONS_COMMON}
endif
ifeq ($(TRUE_SIM_TOOL),iverilog)
SIM_OPTIONS   := -o vvp.exec -I "${VSRC_DIR}/core/" -I "${VSRC_DIR}/perips/" -I "${VSRC_DIR}/perips/apb_i2c/" -D DISABLE_SV_ASSERTION=1 -g2005-sv
SIM_OPTIONS   += ${SIM_OPTIONS_COMMON}
endif

RTL_V_FILES		:= $(wildcard ${VSRC_DIR}/*/*.v ${VSRC_DIR}/*/*/*.v ${VSRC_DIR}/*/*.sv ${VSRC_DIR}/*/*/*.sv)
TB_V_FILES		:= $(wildcard ${VTB_DIR}/*.v ${VTB_DIR}/*.sv)

ifeq ($(SMIC130LL),1)
SIM_OPTIONS   += +define+SMIC130_LL
endif
ifeq ($(GATE_SIM),1)
SIM_OPTIONS   += +define+GATE_SIM  +lint=noIWU,noOUDPE,noPCUDPE
endif
ifeq ($(GATE_SDF),1)
SIM_OPTIONS   += +define+GATE_SDF
endif
ifeq ($(GATE_NOTIME),1)
SIM_OPTIONS   += +nospecify +notimingcheck
endif
ifeq ($(GATE_SDF_MAX),1)
SIM_OPTIONS   += +define+SIM_MAX
endif
ifeq ($(GATE_SDF_MIN),1)
SIM_OPTIONS   += +define+SIM_MIN
endif

#To-ADD: to add the simulatoin executable
ifeq ($(TRUE_SIM_TOOL),verilator)



ifeq ($(wildcard $(VERILATOR_BIN_DIR)),)
	ifeq ($(wildcard ${VERILATOR_ROOT_DIR}/bin/verilator),)
	ifeq ($(ARCH),x86_64)
	ifeq ($(SIM_TOOL),verilator4)
		shell := $(shell rm -f x86_64_verilator-4.228.tar.xz)
		shell := $(shell wget https://bitbucket.org/little-w/e203_simulator/downloads/x86_64_verilator-4.228.tar.xz || rm x86_64_verilator-4.228.tar.xz)
		shell := $(shell rm -rf $(VERILATOR_ROOT_DIR))
		shell := $(shell sudo mkdir -p $(VERILATOR_ROOT_DIR) && sudo chmod 777 $(VERILATOR_ROOT_DIR) && mv x86_64_verilator-4.228.tar.xz $(VERILATOR_ROOT_DIR))
		shell := $(shell cd $(VERILATOR_ROOT_DIR) && tar -xvf x86_64_verilator-4.228.tar.xz && rm x86_64_verilator-4.228.tar.xz)
		shell := $(shell cp -f ${SIM_ROOT_DIR}/deps/tools/update_pkgconfig.sh $(VERILATOR_ROOT_DIR) && cd $(VERILATOR_ROOT_DIR) && sh update_pkgconfig.sh)
	else
		shell := $(shell rm -f x86_64_verilator-5.016.tar.xz)
		shell := $(shell wget https://bitbucket.org/little-w/e203_simulator/downloads/x86_64_verilator-5.016.tar.xz || rm x86_64_verilator-5.016.tar.xz)
		shell := $(shell rm -rf $(VERILATOR_ROOT_DIR))
		shell := $(shell sudo mkdir -p $(VERILATOR_ROOT_DIR) && sudo chmod 777 $(VERILATOR_ROOT_DIR) && mv x86_64_verilator-5.016.tar.xz $(VERILATOR_ROOT_DIR))
		shell := $(shell cd $(VERILATOR_ROOT_DIR) && tar -xvf x86_64_verilator-5.016.tar.xz && rm x86_64_verilator-5.016.tar.xz)
		shell := $(shell cp -f ${SIM_ROOT_DIR}/deps/tools/update_pkgconfig.sh $(VERILATOR_ROOT_DIR) && cd $(VERILATOR_ROOT_DIR) && sh update_pkgconfig.sh)
	endif
	else ifeq ($(ARCH),aarch64)
	ifeq ($(SIM_TOOL),verilator4)
		shell := $(shell rm -f arm64_verilator-4.228.tar.xz)
		shell := $(shell wget https://bitbucket.org/little-w/e203_simulator/downloads/arm64_verilator-4.228.tar.xz || rm arm64_verilator-4.228.tar.xz)
		shell := $(shell rm -rf $(VERILATOR_ROOT_DIR))
		shell := $(shell sudo mkdir -p $(VERILATOR_ROOT_DIR) && sudo chmod 777 $(VERILATOR_ROOT_DIR) && mv arm64_verilator-4.228.tar.xz $(VERILATOR_ROOT_DIR))
		shell := $(shell cd $(VERILATOR_ROOT_DIR) && tar -xvf arm64_verilator-4.228.tar.xz && rm arm64_verilator-4.228.tar.xz)
		shell := $(shell cp -f ${SIM_ROOT_DIR}/deps/tools/update_pkgconfig.sh $(VERILATOR_ROOT_DIR) && cd $(VERILATOR_ROOT_DIR) && sh update_pkgconfig.sh)
	else
		shell := $(shell rm -f arm64_verilator-5.016.tar.xz)
		shell := $(shell wget https://bitbucket.org/little-w/e203_simulator/downloads/arm64_verilator-5.016.tar.xz || rm arm64_verilator-5.016.tar.xz)
		shell := $(shell rm -rf $(VERILATOR_ROOT_DIR))
		shell := $(shell sudo mkdir -p $(VERILATOR_ROOT_DIR) && sudo chmod 777 $(VERILATOR_ROOT_DIR) && mv arm64_verilator-5.016.tar.xz $(VERILATOR_ROOT_DIR))
		shell := $(shell cd $(VERILATOR_ROOT_DIR) && tar -xvf arm64_verilator-5.016.tar.xz && rm arm64_verilator-5.016.tar.xz)
		shell := $(shell cp -f ${SIM_ROOT_DIR}/deps/tools/update_pkgconfig.sh $(VERILATOR_ROOT_DIR) && cd $(VERILATOR_ROOT_DIR) && sh update_pkgconfig.sh)
	endif
	else
		$(error Unsupported architecture: $(ARCH))
	endif
	endif
endif

SIM_TOOL_EXEC  := ${VERILATOR_ROOT_DIR}/bin/verilator
CPU_EXEC_DIR := ${BUILD_DIR}/alioth_exec_verilator
ifeq ($(ARCH),x86_64)
VERILATOR_COMPILE_CMD := make -f Vtb_top.mk -C ${VERILATOR_BUILD_DIR} -j$(nproc)
else ifeq ($(ARCH),aarch64)
VERILATOR_COMPILE_CMD := make -f Vtb_top.mk -C ${VERILATOR_BUILD_DIR} -j4
endif
SIM_EXEC := ${CPU_EXEC_DIR}/Vtb_top

ifeq ($(DUMPWAVE),1)
SIM_CMD := ${SIM_EXEC}  -t +itcm_init=${PROGRAM}
else
SIM_CMD := ${SIM_EXEC}  +itcm_init=${PROGRAM}
endif
ifeq ($(DUMPWAVE),1)
DEBUG_CMD := ${SIM_EXEC}  -t +itcm_init=${PROGRAM}
else
DEBUG_CMD := ${SIM_EXEC}  +itcm_init=${PROGRAM}
endif

ifeq ($(DUMPWAVE),1)
TEST_CMD := ${SIM_EXEC}  -t +itcm_init=${TEST_PROGRAM} | tee ${TEST_NAME}.log
else
TEST_CMD := ${SIM_EXEC} +itcm_init=${TEST_PROGRAM} | tee ${TEST_NAME}.log
endif

EXEC_POST_PROC := @cp -f ${BUILD_DIR}/verilator_build/Vtb_top ${CPU_EXEC_DIR}

endif

ifeq ($(TRUE_SIM_TOOL),vcs)
SIM_EXEC      := ${VCS_DIR}/simv +ntb_random_seed_automatic
endif
ifeq ($(TRUE_SIM_TOOL),iverilog)
CPU_EXEC_DIR := ${BUILD_DIR}/alioth_exec_iverilog
SIM_EXEC      := ${IVERILOG_DIR}/vvp ${CPU_EXEC_DIR}/vvp.exec -lxt2
SIM_TOOL_EXEC := ${IVERILOG_DIR}/iverilog
SIM_CMD := ${SIM_EXEC} +dumpwave=${DUMPWAVE} +itcm_init=${PROGRAM} ${TEST_PLUSARGS} 2>&1 | tee ${SIM_OUT_DIR}/run.log
TEST_CMD := mkdir -p ${TEST_RUNDIR} && cd ${TEST_RUNDIR} && ${SIM_EXEC} +dumpwave=${DUMPWAVE} +itcm_init=${TEST_PROGRAM} ${TEST_PLUSARGS} 2>&1 | tee ${TEST_NAME}.log
EXEC_POST_PROC := @cp -f ${BUILD_DIR}/vvp.exec ${CPU_EXEC_DIR}

ifeq ($(wildcard $(IVERILOG_DIR)),)

	ifeq ($(ARCH),x86_64)
		shell := $(shell rm iverilog12.0_x86_64.tar.xz)
		shell := $(shell wget https://bitbucket.org/little-w/e203_simulator/downloads/iverilog12.0_x86_64.tar.xz || rm iverilog12.0_x86_64.tar.xz)
		shell := $(shell rm -rf $(HARDWARE_TOOLS_DIR)/$(SIM_TOOL))
		shell := $(shell mkdir -p $(HARDWARE_TOOLS_DIR)/$(SIM_TOOL) && mv iverilog12.0_x86_64.tar.xz $(HARDWARE_TOOLS_DIR)/$(SIM_TOOL) && cd $(HARDWARE_TOOLS_DIR)/$(SIM_TOOL) && tar -xvf iverilog12.0_x86_64.tar.xz && rm iverilog12.0_x86_64.tar.xz)
	else ifeq ($(ARCH),aarch64)
		shell := $(shell rm iverilog12.0_arm64.tar.xz)
		shell := $(shell wget https://bitbucket.org/little-w/e203_simulator/downloads/iverilog12.0_arm64.tar.xz || rm iverilog12.0_arm64.tar.xz)
		shell := $(shell rm -rf $(HARDWARE_TOOLS_DIR)/$(SIM_TOOL))
		shell := $(shell mkdir -p $(HARDWARE_TOOLS_DIR)/$(SIM_TOOL) && mv iverilog12.0_arm64.tar.xz $(HARDWARE_TOOLS_DIR)/$(SIM_TOOL) && cd $(HARDWARE_TOOLS_DIR)/$(SIM_TOOL) && tar -xvf iverilog12.0_arm64.tar.xz && rm iverilog12.0_arm64.tar.xz)
	else
		$(error Unsupported architecture: $(ARCH))
	endif
endif
endif

#To-ADD: to add RISC-V toolchain download support
ARCH := $(shell uname -m)
ifeq ($(ARCH),x86_64)
	ifeq ($(wildcard $(CC)),)
		ifeq ($(USE_OPEN_GNU_GCC),0)
		ifeq ($(wildcard ${SOTFWARE_TOOLS_DIR}/gcc/bin/$(COMPILE_PREFIX)gcc),)
		shell := $(shell rm -f x86_64-riscv-gnu-toolchain.tar.xz)
		shell := $(shell wget https://bitbucket.org/little-w/e203_simulator/downloads/x86_64-riscv-gnu-toolchain.tar.xz || rm x86_64-riscv-gnu-toolchain.tar.xz)
		shell := $(shell rm -rf ${SOTFWARE_TOOLS_DIR}/gcc)
		shell := $(shell mkdir -p ${SOTFWARE_TOOLS_DIR}/gcc && mv x86_64-riscv-gnu-toolchain.tar.xz ${SOTFWARE_TOOLS_DIR}/gcc && cd ${SOTFWARE_TOOLS_DIR}/gcc && tar -xvf x86_64-riscv-gnu-toolchain.tar.xz && rm x86_64-riscv-gnu-toolchain.tar.xz)
		endif
		else
		ifeq ($(wildcard ${SOTFWARE_TOOLS_DIR}/gcc_open/bin/$(COMPILE_PREFIX)gcc),)
		shell := $(shell rm -f x86_64-open_riscv-gnu-toolchain.tar.xz)
		shell := $(shell wget https://bitbucket.org/little-w/e203_simulator/downloads/x86_64-open_riscv-gnu-toolchain.tar.xz || rm x86_64-open_riscv-gnu-toolchain.tar.xz)
		shell := $(shell rm -rf ${SOTFWARE_TOOLS_DIR}/gcc_open)
		shell := $(shell mkdir -p ${SOTFWARE_TOOLS_DIR}/gcc_open && mv x86_64-open_riscv-gnu-toolchain.tar.xz ${SOTFWARE_TOOLS_DIR}/gcc_open && cd ${SOTFWARE_TOOLS_DIR}/gcc_open && tar -xvf x86_64-open_riscv-gnu-toolchain.tar.xz && rm x86_64-open_riscv-gnu-toolchain.tar.xz)
		endif
		endif
	endif
	ifeq ($(wildcard $(OPENOCD)),)
	ifeq ($(wildcard ${SOTFWARE_TOOLS_DIR}/openocd/bin/openocd),)
	shell := $(shell rm -f openocd-12.0_x86_64.tar.xz)
	shell := $(shell wget https://bitbucket.org/little-w/e203_simulator/downloads/openocd-12.0_x86_64.tar.xz ||  rm openocd-12.0_x86_64.tar.xz)
	shell := $(shell rm -rf ${SOTFWARE_TOOLS_DIR}/openocd)
	shell := $(shell mkdir -p ${SOTFWARE_TOOLS_DIR}/openocd && mv openocd-12.0_x86_64.tar.xz ${SOTFWARE_TOOLS_DIR}/openocd && cd ${SOTFWARE_TOOLS_DIR}/openocd && tar -xvf openocd-12.0_x86_64.tar.xz && rm openocd-12.0_x86_64.tar.xz)
	endif
	endif
	ifeq ($(wildcard $(QEMU_EXEC)),)
	ifeq ($(wildcard ${SOTFWARE_TOOLS_DIR}/qemu/bin/qemu-riscv32),)
	shell := $(shell rm -f x86_64_qemu-riscv.tar.xz)
	shell := $(shell wget https://bitbucket.org/little-w/e203_simulator/downloads/x86_64_qemu-riscv.tar.xz || rm x86_64_qemu-riscv.tar.xz)
	shell := $(shell rm -rf ${SOTFWARE_TOOLS_DIR}/qemu)
	shell := $(shell mkdir -p ${SOTFWARE_TOOLS_DIR}/qemu && mv x86_64_qemu-riscv.tar.xz ${SOTFWARE_TOOLS_DIR}/qemu && cd ${SOTFWARE_TOOLS_DIR}/qemu && tar -xvf x86_64_qemu-riscv.tar.xz && rm x86_64_qemu-riscv.tar.xz)
	endif
	endif

else ifeq ($(ARCH),aarch64)

	ifeq ($(wildcard $(CC)),)
		ifeq ($(USE_OPEN_GNU_GCC),0)
		shell := $(shell rm arm64-riscv-gnu-toolchain.tar.xz)
		shell := $(shell wget https://bitbucket.org/little-w/e203_simulator/downloads/arm64-riscv-gnu-toolchain.tar.xz || rm arm64-riscv-gnu-toolchain.tar.xz)
		shell := $(shell rm -rf ${SOTFWARE_TOOLS_DIR}/gcc)
		shell := $(shell mkdir -p ${SOTFWARE_TOOLS_DIR}/gcc && mv arm64-riscv-gnu-toolchain.tar.xz ${SOTFWARE_TOOLS_DIR}/gcc && cd ${SOTFWARE_TOOLS_DIR}/gcc && tar -xvf arm64-riscv-gnu-toolchain.tar.xz && rm arm64-riscv-gnu-toolchain.tar.xz)
		else
		shell := $(shell rm arm64-open_riscv-gnu-toolchain.tar.xz)
		shell := $(shell wget https://bitbucket.org/little-w/e203_simulator/downloads/arm64-open_riscv-gnu-toolchain.tar.xz || rm arm64-open_riscv-gnu-toolchain.tar.xz)
		shell := $(shell rm -rf ${SOTFWARE_TOOLS_DIR}/gcc_open)
		shell := $(shell mkdir -p ${SOTFWARE_TOOLS_DIR}/gcc_open && mv arm64-open_riscv-gnu-toolchain.tar.xz ${SOTFWARE_TOOLS_DIR}/gcc_open && cd ${SOTFWARE_TOOLS_DIR}/gcc_open && tar -xvf arm64-open_riscv-gnu-toolchain.tar.xz && rm arm64-open_riscv-gnu-toolchain.tar.xz)
		endif
	endif
	ifeq ($(wildcard $(OPENOCD)),)
	shell := $(shell rm openocd-12.0_arm64.tar.xz)
	shell := $(shell wget https://bitbucket.org/little-w/e203_simulator/downloads/openocd-12.0_arm64.tar.xz || rm openocd-12.0_arm64.tar.xz)
	shell := $(shell rm -rf ${SOTFWARE_TOOLS_DIR}/openocd)
	shell := $(shell mkdir -p ${SOTFWARE_TOOLS_DIR}/openocd && mv openocd-12.0_arm64.tar.xz ${SOTFWARE_TOOLS_DIR}/openocd && cd ${SOTFWARE_TOOLS_DIR}/openocd && tar -xvf openocd-12.0_arm64.tar.xz && rm openocd-12.0_arm64.tar.xz)
	endif
	ifeq ($(wildcard $(QEMU_EXEC)),)
	shell := $(shell rm arm64_qemu-riscv.tar.xz)
	shell := $(shell wget https://bitbucket.org/little-w/e203_simulator/downloads/arm64_qemu-riscv.tar.xz || rm arm64_qemu-riscv.tar.xz)
	shell := $(shell rm -rf ${SOTFWARE_TOOLS_DIR}/qemu)
	shell := $(shell mkdir -p ${SOTFWARE_TOOLS_DIR}/qemu && mv arm64_qemu-riscv.tar.xz ${SOTFWARE_TOOLS_DIR}/qemu && cd ${SOTFWARE_TOOLS_DIR}/qemu && tar -xvf arm64_qemu-riscv.tar.xz && rm arm64_qemu-riscv.tar.xz)
	endif

else
    $(error Unsupported architecture: $(ARCH))
endif

#To-ADD: to add the waveform toolSIM_TOOL_EXEC
ifeq ($(TRUE_SIM_TOOL),vcs)
WAV_TOOL := verdi
endif
ifeq ($(TRUE_SIM_TOOL),iverilog)
WAV_TOOL := gtkwave
endif
ifeq ($(TRUE_SIM_TOOL),verilator)
WAV_TOOL := gtkwave
endif
#To-ADD: to add the waveform tool options
ifeq ($(WAV_TOOL),verdi)
WAV_OPTIONS   := +v2k -sverilog
endif
ifeq ($(WAV_TOOL),gtkwave)
WAV_OPTIONS   :=
endif

ifeq ($(SMIC130LL),1)
WAV_OPTIONS   += +define+SMIC130_LL
endif
ifeq ($(GATE_SIM),1)
WAV_OPTIONS   += +define+GATE_SIM
endif
ifeq ($(GATE_SDF),1)
WAV_OPTIONS   += +define+GATE_SDF
endif


#To-ADD: to add the include dir
ifeq ($(WAV_TOOL),verdi)
WAV_INC      := +incdir+"${VSRC_DIR}/core/"+"${VSRC_DIR}/perips/"+"${VSRC_DIR}/perips/apb_i2c/"
endif
ifeq ($(WAV_TOOL),gtkwave)
WAV_INC      :=
endif

#To-ADD: to add RTL and TB files
ifeq ($(WAV_TOOL),verdi)
WAV_RTL      := ${RTL_V_FILES} ${TB_V_FILES}
endif
ifeq ($(WAV_TOOL),gtkwave)
WAV_RTL      :=
endif

#To-ADD: to add the waveform file
ifeq ($(WAV_TOOL),verdi)
WAV_FILE      := -ssf ${TEST_RUNDIR}/tb_top.fsdb
endif
ifeq ($(WAV_TOOL),gtkwave)
TEST_WAV_FILE      := ${TEST_RUNDIR}/tb_top.vcd
SIM_WAV_FILE 	   := ${SIM_OUT_DIR}/tb_top.vcd
endif

# 支持PC_WRITE_TOHOST参数，控制tb_top.sv中的宏定义
PC_WRITE_TOHOST ?= 0

define enable_pc_write_tohost
	@sed -i '/^\/\/ ToHost程序地址,用于监控测试是否结束$$/a\`define ENABLE_PC_WRITE_TOHOST' ${VTB_DIR}/tb_top.sv
endef

define disable_pc_write_tohost
	@sed -i '/^`define ENABLE_PC_WRITE_TOHOST$$/d' ${VTB_DIR}/tb_top.sv
endef

all: run

compile.flg: ${RTL_V_FILES} ${TB_V_FILES}
	@-rm -rf compile.flg
	@rm -rf ${CPU_EXEC_DIR}
	@mkdir -p ${CPU_EXEC_DIR}
	@sed -i '1i\`define ${SIM_TOOL}\'  ${VTB_DIR}/tb_top.sv
ifeq ($(PC_WRITE_TOHOST),1)
	$(enable_pc_write_tohost)
else
	$(disable_pc_write_tohost)
endif
	${SIM_TOOL_EXEC} ${SIM_OPTIONS}  ${RTL_V_FILES} ${TB_V_FILES} ${VERILATOR_CC_FILE} ${SIM_OPTIONS_BACK}
	${VERILATOR_COMPILE_CMD}
	${EXEC_POST_PROC}
	@touch compile.flg

compile: compile.flg

wave:
	gvim -p ${PROGRAM}.dump &
	${WAV_TOOL} ${WAV_OPTIONS} ${WAV_INC} ${WAV_RTL} ${SIM_WAV_FILE}  &

run:
	@rm -rf ${SIM_OUT_DIR}
	@mkdir ${SIM_OUT_DIR}
	@cd ${SIM_OUT_DIR};${SIM_CMD}

test:
	@if [ ! -e ${TEST_RUNDIR} ] ;	\
	then 	\
		mkdir ${TEST_RUNDIR} ;	\
	fi
	echo ${TEST_CMD}
	cd ${TEST_RUNDIR};${TEST_CMD}
	@if [ ${DUMPWAVE} -eq 1 ];	\
	then	\
		gvim -p ${TEST_PROGRAM}.dump & ${WAV_TOOL} ${WAV_OPTIONS} ${WAV_INC} ${WAV_RTL} ${TEST_WAV_FILE} &   \
	fi

debug_env:
	$(eval SIM_OPTIONS  += +incdir+${JTAG_DIR} -CFLAGS -I${JTAG_DIR})
	$(eval VERILATOR_CC_FILE  += ${JTAG_DIR}/jtag_common.c)
	$(eval VERILATOR_CC_FILE  += ${JTAG_DIR}/jtagServer.cpp)
	$(eval SIM_OPTIONS_BACK  += -DJTAGVPI=1 -CFLAGS -DJTAGVPI=1 -Dalioth_CFG_ITCM_ADDR_WIDTH=20)


debug_sim: debug_env compile
	@rm -rf ${SIM_OUT_DIR}
	@mkdir ${SIM_OUT_DIR}
	@cd ${SIM_OUT_DIR};${DEBUG_CMD}

debug_openocd: 
	${OPENOCD} -s ${JTAG_DIR} -f hbird-alioth.cfg

debug_gdb:
	gvim -p ${PROGRAM}.dump &
	${GDB} -ex "set remotetimeout 14000" -ex "target extended-remote localhost:3333"  -ex "info reg" ${PROGRAM}.elf

.PHONY: run

