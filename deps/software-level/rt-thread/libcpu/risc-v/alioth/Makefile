# Makefile for libcpu (alioth)

CFLAGS  += -I$(CURDIR)
ASFLAGS += -I$(CURDIR)

C_SRCS  := $(wildcard *.c)
CPP_SRCS := $(wildcard *.cpp)
S_SRCS  := $(wildcard *_gcc.S)

# 根据 RT_USING_HW_ATOMIC 宏控制 atomic_riscv.c 的编译
ifeq ($(RT_USING_HW_ATOMIC),n)
	C_SRCS := $(filter-out atomic_riscv.c,$(C_SRCS))
endif

OBJS := $(C_SRCS:.c=.o) $(CPP_SRCS:.cpp=.o) $(S_SRCS:.S=.o)