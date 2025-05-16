SIM_ROOT_DIR     := ${PWD}
include $(SIM_ROOT_DIR)/make.conf

DUMMY_TEST_PROGRAM     := ${BUILD_DIR}/dummy_test/dummy_test
CORE_NAME = $(shell echo $(CORE) | tr a-z A-Z)
core_name = $(shell echo $(CORE) | tr A-Z a-z)

# SELF_TESTS := $(patsubst %.dump,%,$(wildcard ${BUILD_DIR}/test_compiled/rv${XLEN}uc-p*.dump))
SELF_TESTS += $(patsubst %.dump,%,$(wildcard ${BUILD_DIR}/test_compiled/rv32um-p*.dump))
SELF_TESTS += $(patsubst %.dump,%,$(wildcard ${BUILD_DIR}/test_compiled/rv32ua-p*.dump))
SELF_TESTS += $(patsubst %.dump,%,$(wildcard ${BUILD_DIR}/test_compiled/rv${XLEN}ui-p*.dump))
SELF_TESTS += $(patsubst %.dump,%,$(wildcard ${BUILD_DIR}/test_compiled/rv${XLEN}mi-p*.dump))

# 添加ASM编译目录设置
ASM_BUILD_DIR := ${BUILD_DIR}/asm_compiled
ASM_SRC_DIR := ${SIM_ROOT_DIR}/c_src

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
	make compile SIM_ROOT_DIR=${SIM_ROOT_DIR} SIM_TOOL=${SIM_TOOL} SIM_OPTIONS_COMMON=${SIM_OPTIONS_COMMON} -C ${BUILD_DIR}

test: alioth compile_test_src
	@if [ ! -e ${BUILD_DIR}/test_compiled ] ; \
	then	\
		echo ;	\
		echo "****************************************" ;	\
		echo '    do "make compile_test_src" first';	\
		echo "****************************************" ;	\
		echo ;	\
	else	\
		make test SIM_ROOT_DIR=${SIM_ROOT_DIR} DUMPWAVE=${DUMPWAVE} SIM_TOOL=${SIM_TOOL} -C ${BUILD_DIR} ;	\
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

test_all: alioth compile_test_src
	@if [ ! -e ${BUILD_DIR}/test_compiled ] ; \
	then	\
		echo -e "\n" ;	\
		echo "****************************************" ;	\
		echo '    do "make compile_test_src" first';	\
		echo "****************************************" ;	\
		echo -e "\n" ;	\
	else	\
		$(foreach tst,$(SELF_TESTS), make test DUMPWAVE=0 SIM_ROOT_DIR=${SIM_ROOT_DIR} TEST_PROGRAM=${tst} SIM_TOOL=${SIM_TOOL} -C ${BUILD_DIR};)\
		rm -rf ${BUILD_DIR}/regress.res; \
		find ${BUILD_DIR}/test_out/ -name "rv${XLEN}*.log" -exec ${SIM_ROOT_DIR}/deps/tools/find_test_fail.sh {} \; ;	\
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

.PHONY: compile install clean all alioth test test_all compile_test_src debug_gdb debug_openocd debug_sim asm run

