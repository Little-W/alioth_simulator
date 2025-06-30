#!/bin/bash

# 内存分割脚本 - 将.verilog文件分割为ITCM和DTCM两部分
# 参数: $1 = 输入的.verilog文件路径

if [ $# -ne 1 ]; then
    echo "Usage: $0 <verilog_file>"
    exit 1
fi

input_file="$1"
if [ ! -f "$input_file" ]; then
    echo "Error: File $input_file not found"
    exit 1
fi

# 获取文件名和目录
dir=$(dirname "$input_file")
basename=$(basename "$input_file" .verilog)

# 输出文件
itcm_file="${dir}/${basename}_itcm.verilog"
dtcm_file="${dir}/${basename}_dtcm.verilog"

# 定义地址范围 (按字节地址计算)
# ITCM: 0x80000000 - 0x8000FFFF (64KB)
# DTCM: 0x80100000 - 0x8010FFFF (64KB)
ITCM_START=$((0x80000000))
ITCM_END=$((0x8000FFFF))
DTCM_START=$((0x80100000))
DTCM_END=$((0x8010FFFF))

# 清空输出文件
> "$itcm_file"
> "$dtcm_file"

echo "Processing $input_file..."
echo "ITCM range: 0x$(printf '%08x' $ITCM_START) - 0x$(printf '%08x' $ITCM_END)"
echo "DTCM range: 0x$(printf '%08x' $DTCM_START) - 0x$(printf '%08x' $DTCM_END)"

current_addr=0
itcm_count=0
dtcm_count=0
# 跟踪上一次写入的地址
last_itcm_addr=-1
last_dtcm_addr=-1

# 读取输入文件并分割
while IFS= read -r line; do
    # 跳过空行和注释行
    if [[ -z "$line" || "$line" =~ ^[[:space:]]*$ || "$line" =~ ^[[:space:]]*// ]]; then
        continue
    fi
    
    # 处理地址行 (格式: @address)
    if [[ "$line" =~ ^@([0-9a-fA-F]+)[[:space:]]*$ ]]; then
        addr_hex="${BASH_REMATCH[1]}"
        # 转换地址为十进制
        current_addr=$((16#$addr_hex))
        continue
    fi
    
    # 处理数据行 (格式: 多个十六进制字节，如 EF EF 00 00)
    if [[ "$line" =~ ^@([0-9a-fA-F]+)[[:space:]]+(([0-9a-fA-F]{2}[[:space:]]*)+) ]]; then
        # 带地址的数据行
        addr_hex="${BASH_REMATCH[1]}"
        data_str="${BASH_REMATCH[2]}"
        current_addr=$((16#$addr_hex))
    elif [[ "$line" =~ ^(([0-9a-fA-F]{2}[[:space:]]*)+) ]]; then
        # 纯数据行
        data_str="${BASH_REMATCH[1]}"
    else
        continue
    fi
    
    # 处理数据字符串中的每个字节
    for byte in $data_str; do
        # 判断当前地址属于哪个内存区域
        if [ $current_addr -ge $ITCM_START ] && [ $current_addr -le $ITCM_END ]; then
            # ITCM区域 - 计算相对地址
            relative_addr=$((current_addr - ITCM_START))
            if [ $last_itcm_addr -eq -1 ] || [ $relative_addr -ne $((last_itcm_addr + 1)) ]; then
                # 如果是首次写入或地址不连续，输出地址标记
                echo "@$(printf '%08x' $relative_addr)" >> "$itcm_file"
            fi
            # 输出数据
            echo "$byte" >> "$itcm_file"
            last_itcm_addr=$relative_addr
            itcm_count=$((itcm_count + 1))
        elif [ $current_addr -ge $DTCM_START ] && [ $current_addr -le $DTCM_END ]; then
            # DTCM区域 - 转换为相对地址
            relative_addr=$((current_addr - DTCM_START))
            if [ $last_dtcm_addr -eq -1 ] || [ $relative_addr -ne $((last_dtcm_addr + 1)) ]; then
                # 如果是首次写入或地址不连续，输出地址标记
                echo "@$(printf '%08x' $relative_addr)" >> "$dtcm_file"
            fi
            # 输出数据
            echo "$byte" >> "$dtcm_file"
            last_dtcm_addr=$relative_addr
            dtcm_count=$((dtcm_count + 1))
        fi
        
        # 地址递增1字节
        current_addr=$((current_addr + 1))
    done
    
done < "$input_file"

echo "Memory split completed:"
echo "  ITCM: $itcm_file ($itcm_count entries)"
echo "  DTCM: $dtcm_file ($dtcm_count entries)"

# 如果DTCM文件为空，创建一个空的占位符
if [ $dtcm_count -eq 0 ]; then
    echo "// No DTCM data found" > "$dtcm_file"
fi

# 如果ITCM文件为空，创建一个空的占位符
if [ $itcm_count -eq 0 ]; then
    echo "// No ITCM data found" > "$itcm_file"
fi
