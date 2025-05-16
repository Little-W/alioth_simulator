# Alioth RISC-V CPU 仿真测试环境

## 项目概述

这是一个用于测试和验证代号为Alioth的RISC-V处理器的仿真项目。本项目提供了完整的编译、仿真和测试环境，可用于验证处理器功能和性能。

## 功能特性

- RISC-V Alioth处理器的Verilator仿真
- RISC-V汇编和C代码的编译与执行
- 标准RISC-V指令集测试套件的运行与验证
- 波形查看和调试支持

## 目录结构

```
.
├── .gitignore              # Git忽略文件配置
├── make.conf               # 构建配置文件
├── Makefile                # 项目主Makefile
├── README.md               # 项目说明文档
├── build/                  # 构建输出目录
│   ├── alioth_exec_verilator/ # Verilator执行环境
│   ├── alioth_tb/          # 测试平台文件
│   ├── test_compiled/      # 编译后的测试文件
│   ├── test_out/           # 测试输出结果
│   └── verilator_build/    # Verilator构建文件
├── c_src/                  # C源代码及汇编代码目录
├── deps/                   # 依赖项目目录
    ├── hardware-level/     # 硬件级模拟器相关
    ├── hardware/           # 硬件模拟相关文件
    ├── software-level/     # 软件级工具链和测试
    └── tools/              # 辅助脚本和工具
```

## 系统要求

**⚠️ 重要提示：本项目仅支持在Linux系统环境下运行**

- 必须使用Linux操作系统
- 推荐使用Ubuntu 22.04等较新的Linux发行版
- 不支持Windows或macOS系统

## 命令指南

### 核心命令

| 命令 | 说明 |
|------|------|
| `make alioth` | 编译Alioth处理器的Verilator仿真模型 |
| `make test_all` | **一键编译CPU仿真模型并执行所有指令集测试** |
| `make clean` | 清理所有构建产物 |

### 代码编译指令

| 命令 | 说明 |
|------|------|
| `make asm` | 编译汇编源代码 |
| `make compile_test_src` | 编译RISC-V指令集测试源代码 |

### 执行与测试指令

| 命令 | 说明 |
|------|------|
| `make run PROGRAM_NAME=xxx` | 运行指定程序(需先用`make asm`编译) |
| `make test` | 编译并运行单个测试用例 |

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
```

## 环境兼容性

项目会自动下载所需的工具链和依赖项。**仅在Linux系统**上测试通过:

- Ubuntu 22.04 LTS
- openSUSE Tumbleweed 20250531

本项目依赖于多个Linux特有的工具和库，无法在Windows或macOS上运行。

## 调试功能

本项目支持多种调试方式:

- 通过`make run`命令会自动打开波形查看器(如果安装了gtkwave)
- 支持汇编代码查看(通过vim/gvim)
- 提供gdb和openocd调试接口

## 注意事项

- 本项目**只能在Linux系统上运行**，不支持Windows或macOS
- 首次运行需要下载工具链，请确保网络连接正常
- 波形查看需要安装gtkwave工具
- 项目使用了Linux特有的工具和系统调用，无法移植至其他操作系统