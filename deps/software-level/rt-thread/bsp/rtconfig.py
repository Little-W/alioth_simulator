import os
import platform

# toolchains options
ARCH='risc-v'
CPU='alioth'
CROSS_TOOL='gcc'

if os.getenv('RTT_CC'):
    CROSS_TOOL = os.getenv('RTT_CC')

if CROSS_TOOL == 'gcc':
    PLATFORM 	= 'gcc'
    # 优先从环境变量获取SOTFWARE_TOOLS_DIR
    SOFTWARE_TOOLS_DIR = os.getenv(
        'SOFTWARE_TOOLS_DIR',
        os.path.abspath(os.path.join(os.path.dirname(__file__), '../../bin'))
    )
    USE_OPEN_GNU_GCC = os.getenv('USE_OPEN_GNU_GCC', '1')
    if USE_OPEN_GNU_GCC == '0':
        GCC_ROOT = os.path.join(SOFTWARE_TOOLS_DIR, 'gcc')
    else:
        GCC_ROOT = os.path.join(SOFTWARE_TOOLS_DIR, 'gcc_open')
    EXEC_PATH = os.path.join(GCC_ROOT, 'bin')
    if not os.path.exists(EXEC_PATH):
        print("Warning: Toolchain path %s doesn't exist, assume it is already in PATH" % EXEC_PATH)
        EXEC_PATH = '' # Don't set path if not exist
else:
    print("CROSS_TOOL = %s not yet supported" % CROSS_TOOL)

if os.getenv('RTT_EXEC_PATH'):
	EXEC_PATH = os.getenv('RTT_EXEC_PATH')

BUILD = ''
# Fixed configurations below

# BSP_DIR从环境变量获得，未设置则使用默认值 ../../bsp
if os.getenv('BSP_DIR'):
    BSP_DIR = os.path.abspath(os.getenv('BSP_DIR'))
elif os.getenv('SIM_ROOT_DIR'):
    BSP_DIR = os.path.abspath(os.path.join(os.getenv('SIM_ROOT_DIR'), 'deps', 'software-level', 'bsp'))
else:
    BSP_DIR = os.path.abspath(os.path.join(os.getcwd(), '../../bsp'))

# Configurable options below
if PLATFORM == 'gcc':
    # toolchains
    PREFIX  = 'riscv64-unknown-elf-'
    CC      = PREFIX + 'gcc'
    CXX     = PREFIX + 'g++'
    AS      = PREFIX + 'gcc'
    AR      = PREFIX + 'ar'
    LINK    = PREFIX + 'gcc'
    GDB     = PREFIX + 'gdb'
    TARGET_EXT = 'elf'
    SIZE    = PREFIX + 'size'
    OBJDUMP = PREFIX + 'objdump'
    OBJCPY  = PREFIX + 'objcopy'
    DEVICE = ' -march=rv32im_zicsr -mabi=ilp32 -DSDK_BANNER=1 -DRTOS_RTTHREAD=1  \
            -mcmodel=medany -ffunction-sections -fdata-sections \
            -fno-builtin-printf -fno-builtin-malloc \
            -L.  -nostartfiles -nostdlib -lc'
    CFLAGS = DEVICE
    AFLAGS  = CFLAGS
    LFLAGS = DEVICE
    LFLAGS += ' -Wl,--gc-sections'
    # 添加32位库路径
    LFLAGS += f' -L{GCC_ROOT}/riscv64-unknown-elf/lib/rv32im/ilp32'
    LFLAGS += f' -L{GCC_ROOT}/lib/gcc/riscv64-unknown-elf/12.2.0/rv32im/ilp32'
    # 添加链接脚本
    LFLAGS += f' -T{BSP_DIR}/link.lds'
    # LFLAGS += ' -Wl,-cref,-Map=rtthread.map'
    # LFLAGS  += ' -u _isatty -u _write -u _sbrk -u _read -u _close -u _fstat -u _lseek '
    CPATH   = ''
    LPATH   = ''
    # 推荐顺序：c库、gcc库、stdc++库
    LIBS = ['c', 'gcc', 'stdc++']
    AFLAGS += ' -D"irq_entry=SW_handler" '

    if BUILD == 'debug':
        CFLAGS += ' -O2 -ggdb'
        AFLAGS += ' -ggdb'
    else:
        CFLAGS += ' -O2 -Os'

    CXXFLAGS = CFLAGS

DUMP_ACTION = OBJDUMP + ' -D -S $TARGET > rtt.asm\n'
POST_ACTION = OBJCPY + ' -O binary $TARGET rtthread.bin\n' + SIZE + ' $TARGET \n'

def dist_handle(BSP_ROOT, dist_dir):
    import sys
    cwd_path = os.getcwd()
    sys.path.append(os.path.join(os.path.dirname(BSP_ROOT), 'tools'))
    from sdk_dist import dist_do_building
    dist_do_building(BSP_ROOT, dist_dir)