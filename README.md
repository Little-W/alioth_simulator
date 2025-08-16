# Alioth RISC-V CPU 仿真测试环境

## 项目概述

这是一个用于测试和验证代号为Alioth的RISC-V处理器的仿真项目。本项目提供了完整的编译、仿真和测试环境，可用于验证处理器功能和性能。

**CPU源代码位置**: 本项目的RISC-V CPU（Alioth）源代码存储在 `deps/hardware-level/src/alioth/` 目录中。

## 功能特性

- RISC-V Alioth处理器的Verilator仿真
- RISC-V汇编和C代码的编译与执行
- 标准RISC-V指令集测试套件的运行与验证
- 支持RT-Thread/RT-Thread Nano实时操作系统仿真
- 支持CoreMark跑分测试
- 支持C语言裸机程序仿真
- 波形查看和调试支持
- 自动化测试与批量回归
- 支持多种调试方式（波形/日志）

## 目录结构

```
.
├── .gitignore              # Git忽略文件配置
├── make.conf               # 构建配置文件
├── Makefile                # 项目主Makefile
├── README.md               # 项目说明文档
├── build/                  # 构建输出目录
├── c_src/                  # C源代码及汇编代码目录（裸机程序/测试用例）
├── deps/                   # 依赖项目目录
│   ├── hardware-level/     # 硬件级模拟器相关
│   │   └── src/alioth/     # CPU源代码存储位置
│   ├── software-level/     # 软件级工具链和测试
│   │   ├── bsp/                # C语言裸机BSP支持包
│   │   ├── test/               # 测试相关源代码
│   │   │   ├── coremark/       # CoreMark源代码
│   │   │   └── isa/            # RISC-V指令集测试源代码
│   │   ├── rt-thread/          # RT-Thread操作系统源代码
│   │   └── rt-thread-nano/     # RT-Thread Nano操作系统源代码
│   └── tools/              # 辅助脚本和工具
```

## 系统要求

**⚠️ 重要提示：本项目仅支持在Linux系统环境下运行**

- 必须使用Linux操作系统
- 推荐使用Ubuntu 22.04等较新的Linux发行版
- 不支持Windows或macOS系统
- 系统需具备基础C++编译套件（如GCC、G++）
- 依赖`libelf`开发库（如`libelf-dev`，可通过`sudo apt install libelf-dev`安装）

## 命令指南

### 核心命令

| 命令 | 说明 |
|------|------|
| `make alioth` | 编译Alioth处理器的Verilator仿真模型 |
| `make test_all TESTCASE=xxx` | **一键编译CPU仿真模型并执行所有指令集测试，可选参数TESTCASE指定测试类型(支持um,ui,mi)** |
| `make clean` | 清理所有构建产物 |

### 代码编译指令

| 命令 | 说明 |
|------|------|
| `make asm` | 编译汇编源代码 |
| `make compile_test_src` | 编译RISC-V指令集测试源代码 |
| `make c_src` | 编译C语言裸机程序 |
| `make coremark` | 编译并仿真CoreMark跑分程序 |
| `make build_rt_thread` | 编译RT-Thread实时操作系统 |
| `make rt_thread_nano` | 编译并仿真RT-Thread Nano |

### 执行与测试指令

| 命令 | 说明 |
|------|------|
| `make run PROGRAM_NAME=xxx` | 运行指定程序(需先用`make asm`编译) |
| `make test TESTCASE=xxx` | 编译并运行测试用例，可选参数TESTCASE指定特定的RISC-V指令测试程序 |
| `make run_csrc` | 仿真C语言裸机程序 |
| `make sim_rt_thread` | 仿真RT-Thread操作系统 |
| `make sim_rt_thread` | 仿真RT-Thread |
| `make sim_rt_thread_nano` | 仿真RT-Thread Nano |

## 使用教程

### 快速开始

编译CPU仿真器并运行测试程序:

```bash
# 编译Alioth处理器仿真器
make alioth

# 编译测试程序
make asm

# 运行测试程序,默认名称为test
make run
```

### 全面测试

验证CPU对RISC-V指令集的支持:

```bash
# 运行所有指令集测试
make test_all

# 只运行整数乘除法(um)和基本整数(ui)指令集测试
make test_all TESTCASE=um,ui

# 运行特定的测试程序
make test TESTCASE=rv32um-p-div
```

#### 测试集分类说明

- `ui`: 基本整数指令测试 (如add, sub, and, or等)
- `um`: 整数乘除法指令测试 (如mul, div, rem等)
- `mi`: 机器模式指令测试 (如csr访问等)

### C语言/RT-Thread/CoreMark仿真

```bash
# 编译并仿真C语言裸机程序
make run_csrc

# 编译并仿真CoreMark
make coremark

# 编译并仿真RT-Thread
make sim_rt_thread

# 编译并仿真RT-Thread Nano
make rt_thread_nano
```

## 环境兼容性

项目会自动下载所需的工具链和依赖项。**仅在以下Linux发行版**上进行了测试:

- Ubuntu 22.04 LTS
- openSUSE Tumbleweed 20250531

本项目依赖于多个Linux特有的工具和库，**需要安装libelf开发库**（如`libelf-dev`），无法在Windows或macOS上运行。

## 调试功能

本项目支持多种调试方式:

- 通过`make run`、`make run_csrc`、`make coremark`等命令会自动打开波形查看器(如果安装了gtkwave)
- 支持汇编/反汇编/内存dump文件查看(通过vim/gvim)
- 支持RT-Thread/RT-Thread Nano仿真调试
- 支持批量自动化测试与回归分析

## 注意事项

- 本项目**只能在Linux系统上运行**，不支持Windows或macOS
- 首次运行需要下载工具链，请确保网络连接正常
- 波形查看需要安装gtkwave工具
- 需要安装libelf开发库（如`sudo apt install libelf-dev`）
- 项目使用了Linux特有的工具和系统调用，无法移植至其他操作系统