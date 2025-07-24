SIM_ROOT_DIR     := ${PWD}
include $(SIM_ROOT_DIR)/make.conf

DUMMY_TEST_PROGRAM     := ${BUILD_DIR}/dummy_test/dummy_test
CORE_NAME = $(shell echo $(CORE) | tr a-z A-Z)
core_name = $(shell echo $(CORE) | tr A-Z a-z)

# 定义各类测试集合
UM_TESTS := $(patsubst %.dump,%,$(wildcard ${BUILD_DIR}/test_compiled/rv32um-p*.dump))
UA_TESTS := $(patsubst %.dump,%,$(wildcard ${BUILD_DIR}/test_compiled/rv32ua-p*.dump))
UI_TESTS := $(patsubst %.dump,%,$(wildcard ${BUILD_DIR}/test_compiled/rv${XLEN}ui-p*.dump))
MI_TESTS := $(patsubst %.dump,%,$(wildcard ${BUILD_DIR}/test_compiled/rv${XLEN}mi-p*.dump))

# SELF_TESTS := $(patsubst %.dump,%,$(wildcard ${BUILD_DIR}/test_compiled/rv${XLEN}uc-p*.dump))
SELF_TESTS += $(UM_TESTS)
SELF_TESTS += $(UA_TESTS)
SELF_TESTS += $(UI_TESTS)
SELF_TESTS += $(MI_TESTS)

# 添加ASM编译目录设置
ASM_BUILD_DIR := ${BUILD_DIR}/asm_compiled
ASM_SRC_DIR := ${SIM_ROOT_DIR}/c_src
C_SRC_DIR := ${SIM_ROOT_DIR}/c_src

alioth:
	@mkdir -p ${BUILD_DIR}
	@if [ ! -h ${BUILD_DIR}/Makefile ] ; \
	then \
	rm -f ${BUILD_DIR}/Makefile; \
	ln -s ${HARDWARE_DEPS_ROOT}/Makefile ${BUILD_DIR}/Makefile; \
	fi
	@if [ ! -d ${BUILD_DIR}/${CORE}_tb/ ] ; \
	then	\
	mkdir -p ${BUILD_DIR}/${CORE}_tb/; \
	cp -rf ${HARDWARE_SRC_DIR}/${CORE}/tb/ ${BUILD_DIR}/${CORE}_tb/tb; \
	cp -rf ${HARDWARE_SRC_DIR}/${CORE}/tb_verilator ${BUILD_DIR}/${CORE}_tb/tb_verilator; \
	fi
	make compile SIM_ROOT_DIR=${SIM_ROOT_DIR} SIM_TOOL=${SIM_TOOL} SIM_OPTIONS_COMMON=${SIM_OPTIONS_COMMON} PC_WRITE_TOHOST=0 -C ${BUILD_DIR}

alioth_no_timeout:
	@mkdir -p ${BUILD_DIR}
	@if [ ! -h ${BUILD_DIR}/Makefile ] ; \
	then \
	rm -f ${BUILD_DIR}/Makefile; \
	ln -s ${HARDWARE_DEPS_ROOT}/Makefile ${BUILD_DIR}/Makefile; \
	fi
	@if [ ! -d ${BUILD_DIR}/${CORE}_tb/ ] ; \
	then	\
	mkdir -p ${BUILD_DIR}/${CORE}_tb/; \
	cp -rf ${HARDWARE_SRC_DIR}/${CORE}/tb/ ${BUILD_DIR}/${CORE}_tb/tb; \
	cp -rf ${HARDWARE_SRC_DIR}/${CORE}/tb_verilator ${BUILD_DIR}/${CORE}_tb/tb_verilator; \
	echo "Inserting DISABLE_TIMEOUT macro into tb_top.sv"; \
	sed -i '1i`define DISABLE_TIMEOUT' ${BUILD_DIR}/${CORE}_tb/tb_verilator/tb_top.sv; \
	fi
	make compile SIM_ROOT_DIR=${SIM_ROOT_DIR} SIM_TOOL=${SIM_TOOL} SIM_OPTIONS_COMMON=${SIM_OPTIONS_COMMON} PC_WRITE_TOHOST=0 -C ${BUILD_DIR}

alioth_test:
	@mkdir -p ${BUILD_DIR}
	@if [ ! -h ${BUILD_DIR}/Makefile ] ; \
	then \
	rm -f ${BUILD_DIR}/Makefile; \
	ln -s ${HARDWARE_DEPS_ROOT}/Makefile ${BUILD_DIR}/Makefile; \
	fi
	@if [ ! -d ${BUILD_DIR}/${CORE}_tb/ ] ; \
	then	\
	mkdir -p ${BUILD_DIR}/${CORE}_tb/; \
	cp -rf ${HARDWARE_SRC_DIR}/${CORE}/tb/ ${BUILD_DIR}/${CORE}_tb/tb; \
	cp -rf ${HARDWARE_SRC_DIR}/${CORE}/tb_verilator ${BUILD_DIR}/${CORE}_tb/tb_verilator; \
	fi
	make compile SIM_ROOT_DIR=${SIM_ROOT_DIR} SIM_TOOL=${SIM_TOOL} SIM_OPTIONS_COMMON=${SIM_OPTIONS_COMMON} PC_WRITE_TOHOST=1 -C ${BUILD_DIR}

test: alioth_test compile_test_src
	@if [ ! -e ${BUILD_DIR}/test_compiled ] ; \
	then	\
		echo ;	\
		echo "****************************************" ;	\
		echo '    do "make compile_test_src" first';	\
		echo "****************************************" ;	\
		echo ;	\
	else	\
		if [ ! -z "$(TESTCASE)" ] ; then \
			TEST_PROGRAM_PATH=${BUILD_DIR}/test_compiled/$(TESTCASE); \
			make test SIM_ROOT_DIR=${SIM_ROOT_DIR} DUMPWAVE=${DUMPWAVE} SIM_TOOL=${SIM_TOOL} TEST_PROGRAM=$$TEST_PROGRAM_PATH -C ${BUILD_DIR} ;	\
		else \
			make test SIM_ROOT_DIR=${SIM_ROOT_DIR} DUMPWAVE=${DUMPWAVE} SIM_TOOL=${SIM_TOOL} -C ${BUILD_DIR} ;	\
		fi; \
		if [ -e "${BUILD_DIR}/dump.vcd" ] ; then \
			if command -v gtkwave > /dev/null 2>&1; then \
				gtkwave ${BUILD_DIR}/dump.vcd & \
			else \
				echo "gtkwave not found, skipping waveform display"; \
			fi \
		fi; \
		if [ -e "${BUILD_DIR}/run.log" ] ; then \
			if command -v gvim > /dev/null 2>&1; then \
				gvim ${BUILD_DIR}/run.log & \
			elif command -v vim > /dev/null 2>&1; then \
				vim ${BUILD_DIR}/run.log & \
			else \
				echo "vim/gvim not found, skipping log view"; \
			fi \
		fi \
	fi

compile_test_src:
	@if [ ! -e ${TEST_PROGRAM} ] ; \
	then	\
		make SIM_ROOT_DIR=${SIM_ROOT_DIR} XLEN=${XLEN} USE_OPEN_GNU_GCC=${USE_OPEN_GNU_GCC} -j$(nproc) -C ${ISA_TEST_DIR}/test_src/;	\
		echo "Processing .verilog files for dual memory layout..."; \
		find ${BUILD_DIR}/test_compiled/ -name "*.verilog" -exec ${SIM_ROOT_DIR}/deps/tools/split_memory.sh {} \; ; \
		echo "Memory splitting completed"; \
	fi

asm: alioth
	@mkdir -p ${ASM_BUILD_DIR}
	@echo "Compiling assembly files from ${ASM_SRC_DIR}"
	@if [ ! -d ${ASM_SRC_DIR} ] ; \
	then \
		echo "Error: ${ASM_SRC_DIR} directory not found"; \
		exit 1; \
	fi
	make SIM_ROOT_DIR=${SIM_ROOT_DIR} XLEN=${XLEN} -C ${ASM_SRC_DIR}
	@echo "Assembly compilation completed"

run: alioth
	@if [ -z "$(PROGRAM_NAME)" ] ; \
	then \
		echo "Error: Please specify a program with PROGRAM_NAME=<filename>"; \
		echo "Example: make run PROGRAM_NAME=test"; \
		exit 1; \
	fi
	
	@if [ ! -e "${ASM_BUILD_DIR}/$(PROGRAM_NAME).verilog" ] ; \
	then \
		echo "Error: Program files not found at ${ASM_BUILD_DIR}/$(PROGRAM_NAME)"; \
		echo "Please compile it first with 'make asm'"; \
		exit 1; \
	fi
	
	@echo "Running $(PROGRAM_NAME)"
	@make run SIM_ROOT_DIR=${SIM_ROOT_DIR} DUMPWAVE=1 PROGRAM="${ASM_BUILD_DIR}/$(PROGRAM_NAME)" SIM_TOOL=${SIM_TOOL} -C ${BUILD_DIR}
	
	@# 打开波形和日志文件
	@if [ -e "${BUILD_DIR}/sim_out/tb_top.vcd" ] ; \
	then \
		if command -v gtkwave > /dev/null 2>&1; then \
			gtkwave ${BUILD_DIR}/sim_out/tb_top.vcd & \
		else \
			echo "gtkwave not found, skipping waveform display"; \
		fi \
	fi
	
	@if [ -e "${ASM_BUILD_DIR}/$(PROGRAM_NAME).dump" ] ; \
	then \
		if command -v gvim > /dev/null 2>&1; then \
			gvim ${ASM_BUILD_DIR}/$(PROGRAM_NAME).dump & \
		elif command -v vim > /dev/null 2>&1; then \
			vim ${ASM_BUILD_DIR}/$(PROGRAM_NAME).dump & \
		else \
			echo "vim/gvim not found, skipping asm view"; \
		fi \
	fi

test_all: alioth_test compile_test_src
	@if [ ! -e ${BUILD_DIR}/test_compiled ] ; then \
		echo -e "\n" ; \
		echo "****************************************" ; \
		echo '    do "make compile_test_src" first' ; \
		echo "****************************************" ; \
		echo -e "\n" ; \
	else \
		echo "清理之前的测试日志..." ; \
		rm -rf ${BUILD_DIR}/test_out ; \
		mkdir -p ${BUILD_DIR}/test_out ; \
		echo "TESTCASE值是: '$(TESTCASE)'" ; \
		TESTCASE_VALUE="$(TESTCASE)" ; \
		# 编译后重新定义各类测试集合 \
		UM_TESTS=$$(ls ${BUILD_DIR}/test_compiled/rv32um-p*.dump 2>/dev/null | sed 's/\.dump$$//') ; \
		UA_TESTS=$$(ls ${BUILD_DIR}/test_compiled/rv32ua-p*.dump 2>/dev/null | sed 's/\.dump$$//') ; \
		UI_TESTS=$$(ls ${BUILD_DIR}/test_compiled/rv${XLEN}ui-p*.dump 2>/dev/null | sed 's/\.dump$$//') ; \
		MI_TESTS=$$(ls ${BUILD_DIR}/test_compiled/rv${XLEN}mi-p*.dump 2>/dev/null | sed 's/\.dump$$//') ; \
		SELF_TESTS="$$UM_TESTS $$UA_TESTS $$UI_TESTS $$MI_TESTS" ; \
		if [ -n "$$TESTCASE_VALUE" ] ; then \
			TESTS_TO_RUN="" ; \
			if echo ",$$TESTCASE_VALUE," | grep -E "um" > /dev/null; then \
				echo "包含um测试" ; \
				TESTS_TO_RUN="$$TESTS_TO_RUN $$UM_TESTS" ; \
			fi ; \
			if echo ",$$TESTCASE_VALUE," | grep -E "ua" > /dev/null; then \
				echo "包含ua测试" ; \
				TESTS_TO_RUN="$$TESTS_TO_RUN $$UA_TESTS" ; \
			fi ; \
			if echo ",$$TESTCASE_VALUE," | grep -E "ui" > /dev/null; then \
				echo "包含ui测试" ; \
				TESTS_TO_RUN="$$TESTS_TO_RUN $$UI_TESTS" ; \
			fi ; \
			if echo ",$$TESTCASE_VALUE," | grep -E "mi" > /dev/null; then \
				echo "包含mi测试" ; \
				TESTS_TO_RUN="$$TESTS_TO_RUN $$MI_TESTS" ; \
			fi ; \
			echo "Running selected test categories: $$TESTCASE_VALUE" ; \
			echo "测试集合: $$TESTS_TO_RUN" ; \
			for tst in $$TESTS_TO_RUN; do \
				make test DUMPWAVE=0 SIM_ROOT_DIR=${SIM_ROOT_DIR} TEST_PROGRAM=$$tst SIM_TOOL=${SIM_TOOL} -C ${BUILD_DIR} ; \
			done ; \
		else \
			echo "运行所有测试" ; \
			for tst in $$SELF_TESTS; do \
				make test DUMPWAVE=0 SIM_ROOT_DIR=${SIM_ROOT_DIR} TEST_PROGRAM=$$tst SIM_TOOL=${SIM_TOOL} -C ${BUILD_DIR} ; \
			done ; \
		fi ; \
		rm -rf ${BUILD_DIR}/regress.res ; \
		find ${BUILD_DIR}/test_out/ -name "rv${XLEN}*.log" -exec ${SIM_ROOT_DIR}/deps/tools/find_test_fail.sh {} \; ; \
	fi

debug_env:
	@rm -f ${BUILD_DIR}/Makefile
	@ln -s ${HARDWARE_DEPS_ROOT}/Makefile ${BUILD_DIR}/Makefile
	
debug_sim: debug_env
	@if [ ! -d ${BUILD_DIR}/${CORE}_tb/ ] ; \
	then	\
	mkdir -p ${BUILD_DIR}/${CORE}_tb/; \
	cp -rf ${HARDWARE_SRC_DIR}/${CORE}/tb/ ${BUILD_DIR}/${CORE}_tb/tb; \
	cp -rf ${HARDWARE_SRC_DIR}/${CORE}/tb_verilator ${BUILD_DIR}/${CORE}_tb/tb_verilator; \
	fi
	make debug_sim SIM_ROOT_DIR=${SIM_ROOT_DIR} DUMPWAVE=${DUMPWAVE} PROGRAM=${DUMMY_TEST_PROGRAM} SIM_TOOL=${SIM_TOOL} -C ${BUILD_DIR}

debug_openocd: 
	make debug_openocd SIM_ROOT_DIR=${SIM_ROOT_DIR} -C ${BUILD_DIR}

debug_gdb: 
	@mkdir -p ${BUILD_DIR}
	@rm -f ${BUILD_DIR}/Makefile
	@ln -s ${HARDWARE_DEPS_ROOT}/Makefile ${BUILD_DIR}/Makefile
	make debug_gdb SIM_ROOT_DIR=${SIM_ROOT_DIR} DUMPWAVE=${DUMPWAVE} PROGRAM=${PROGRAM} SIM_TOOL=${SIM_TOOL} -C ${BUILD_DIR}

clean:
	@rm -rf build
	@echo "Clean done."

c_src:
	@mkdir -p ${BUILD_DIR}/bsp_tmp
	@if [ ! -h ${BUILD_DIR}/bsp_tmp/Makefile ]; then \
		ln -sf ${SIM_ROOT_DIR}/deps/software-level/bsp/bsp.mk ${BUILD_DIR}/bsp_tmp/Makefile; \
	fi
	@make SIM_ROOT_DIR=${SIM_ROOT_DIR} BSP_DIR=${SIM_ROOT_DIR}/deps/software-level/bsp C_SRC_DIR=${C_SRC_DIR} BUILD_DIR=${BUILD_DIR}/bsp_tmp -C ${BUILD_DIR}/bsp_tmp

run_csrc: c_src sim_csrc

coremark: alioth_no_timeout
	@mkdir -p ${BUILD_DIR}/coremark_tmp
	@cp -f ${SIM_ROOT_DIR}/deps/software-level/bsp/bsp.mk ${BUILD_DIR}/coremark_tmp/Makefile
	@ln -sf ${SIM_ROOT_DIR}/deps/software-level/test/coremark/coremark.mk ${BUILD_DIR}/coremark_tmp/coremark.mk
	@echo '' >> ${BUILD_DIR}/coremark_tmp/Makefile
	@echo 'include coremark.mk' >> ${BUILD_DIR}/coremark_tmp/Makefile
	@make SIM_ROOT_DIR=${SIM_ROOT_DIR} BSP_DIR=${SIM_ROOT_DIR}/deps/software-level/bsp C_SRC_DIR=${SIM_ROOT_DIR}/deps/software-level/test/coremark BUILD_DIR=${BUILD_DIR}/coremark_tmp -C ${BUILD_DIR}/coremark_tmp
	@echo "Splitting coremark.verilog for ITCM/DTCM..."
	@if [ -e ${BUILD_DIR}/coremark_tmp/main.verilog ]; then \
		${SIM_ROOT_DIR}/deps/tools/split_memory.sh ${BUILD_DIR}/coremark_tmp/coremark.verilog; \
		echo "Memory splitting completed"; \
	else \
		echo "coremark.verilog not found, skip memory split"; \
	fi
	@echo "------ Running coremark simulation ------"
	@mkdir -p ${BUILD_DIR}
	@if [ ! -h ${BUILD_DIR}/Makefile ]; then \
		ln -s ${HARDWARE_DEPS_ROOT}/Makefile ${BUILD_DIR}/Makefile; \
	fi
	@if [ ! -e ${BUILD_DIR}/coremark_tmp/main_itcm.verilog ] ; then \
		echo "Error: ITCM file not found, please check coremark build."; \
		exit 1; \
	fi
	@echo "Simulating with ITCM: ${BUILD_DIR}/coremark_tmp/main_itcm.verilog"
	@echo "Simulating with DTCM: ${BUILD_DIR}/coremark_tmp/main_dtcm.verilog"
	@make SIM_ROOT_DIR=${SIM_ROOT_DIR} DUMPWAVE=${DUMPWAVE} PROGRAM="${BUILD_DIR}/coremark_tmp/main" SIM_TOOL=${SIM_TOOL} -C ${BUILD_DIR}
	@if [ "${SIM_DEBUG}" = "1" ]; then \
		if [ -e "${BUILD_DIR}/sim_out/tb_top.vcd" ] ; then \
			if command -v gtkwave > /dev/null 2>&1; then \
				gtkwave ${BUILD_DIR}/sim_out/tb_top.vcd & \
			else \
				echo "gtkwave not found, skipping waveform display"; \
			fi \
		fi; \
		if [ -e "${BUILD_DIR}/coremark_tmp/main.dump" ] ; then \
			if command -v gvim > /dev/null 2>&1; then \
				gvim ${BUILD_DIR}/coremark_tmp/main.dump & \
			elif command -v vim > /dev/null 2>&1; then \
				vim ${BUILD_DIR}/coremark_tmp/main.dump & \
			else \
				echo "vim/gvim not found, skipping dump view"; \
			fi \
		fi; \
	fi

sim_csrc: alioth_no_timeout
	@mkdir -p ${BUILD_DIR}
	@if [ ! -h ${BUILD_DIR}/Makefile ]; then \
		ln -s ${HARDWARE_DEPS_ROOT}/Makefile ${BUILD_DIR}/Makefile; \
	fi
	@if [ ! -e ${BUILD_DIR}/bsp_tmp/main_itcm.verilog ] ; \
	then \
		echo "Error: ITCM file not found, please check c_src build."; \
		exit 1; \
	fi
	@echo "Simulating with ITCM: ${BUILD_DIR}/bsp_tmp/main_itcm.verilog"
	@echo "Simulating with DTCM: ${BUILD_DIR}/bsp_tmp/main_dtcm.verilog"
	@make SIM_ROOT_DIR=${SIM_ROOT_DIR} DUMPWAVE=${DUMPWAVE} PROGRAM="${BUILD_DIR}/bsp_tmp/main" SIM_TOOL=${SIM_TOOL} -C ${BUILD_DIR}
	@if [ -e "${BUILD_DIR}/sim_out/tb_top.vcd" ] ; then \
		if command -v gtkwave > /dev/null 2>&1; then \
			gtkwave ${BUILD_DIR}/sim_out/tb_top.vcd & \
		else \
			echo "gtkwave not found, skipping waveform display"; \
		fi \
	fi
	@if [ -e "${BUILD_DIR}/bsp_tmp/main.dump" ] ; then \
		if command -v gvim > /dev/null 2>&1; then \
			gvim ${BUILD_DIR}/bsp_tmp/main.dump & \
		elif command -v vim > /dev/null 2>&1; then \
			vim ${BUILD_DIR}/bsp_tmp/main.dump & \
		else \
			echo "vim/gvim not found, skipping dump view"; \
		fi \
	fi

.PHONY: compile install clean all alioth test test_all compile_test_src debug_gdb debug_openocd debug_sim asm run c_src run_csrc sim_csrc alioth_no_timeout

