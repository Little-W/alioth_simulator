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
itcm_mem_file="${dir}/${basename}_itcm.mem"
dtcm_mem_file="${dir}/${basename}_dtcm.mem"

# 如果输出文件已存在，则直接退出，避免重复操作
if [ -f "$itcm_file" ] || [ -f "$dtcm_file" ] || [ -f "$itcm_mem_file" ] || [ -f "$dtcm_mem_file" ]; then
    echo "Output files already exist, aborting to avoid overwrite."
    exit 0
fi

# 定义地址范围 (按字节地址计算)
# ITCM: 0x80000000 - 0x8003FFFF (256KB)
# DTCM: 0x80100000 - 0x8013FFFF (256KB)
ITCM_START=$((0x80000000))
ITCM_END=$((0x8003FFFF))
DTCM_START=$((0x80100000))
DTCM_END=$((0x8013FFFF))

# 清空输出文件
> "$itcm_file"
> "$dtcm_file"
> "$itcm_mem_file"
> "$dtcm_mem_file"

echo "Processing $input_file..."
echo "ITCM range: 0x$(printf '%08x' $ITCM_START) - 0x$(printf '%08x' $ITCM_END)"
echo "DTCM range: 0x$(printf '%08x' $DTCM_START) - 0x$(printf '%08x' $DTCM_END)"

current_addr=0
itcm_count=0
dtcm_count=0
# 跟踪上一次写入的地址
last_itcm_addr=-1
last_dtcm_addr=-1

# 用于收集所有字节数据（普通数组，地址即下标）
declare -a itcm_bytes_arr
declare -a dtcm_bytes_arr
itcm_min_addr=-1
itcm_max_addr=-1
dtcm_min_addr=-1
dtcm_max_addr=-1

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
    # 清理所有空白和换行，只保留字节
    clean_data_str=$(echo "$data_str" | tr -s ' \t\r\n' ' ')
    read -ra bytes_arr <<< "$clean_data_str"
    for byte in "${bytes_arr[@]}"; do
        if [ $current_addr -ge $ITCM_START ] && [ $current_addr -le $ITCM_END ]; then
            relative_addr=$((current_addr - ITCM_START))
            if [ $last_itcm_addr -eq -1 ] || [ $relative_addr -ne $((last_itcm_addr + 1)) ]; then
                # 如果是首次写入或地址不连续，输出地址标记
                echo "@$(printf '%08x' $relative_addr)" >> "$itcm_file"
            fi
            # 输出数据
            echo "$byte" >> "$itcm_file"
            itcm_bytes_arr[$relative_addr]="$byte"
            if [ $itcm_min_addr -eq -1 ] || [ $relative_addr -lt $itcm_min_addr ]; then
                itcm_min_addr=$relative_addr
            fi
            if [ $itcm_max_addr -eq -1 ] || [ $relative_addr -gt $itcm_max_addr ]; then
                itcm_max_addr=$relative_addr
            fi
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
            dtcm_bytes_arr[$relative_addr]="$byte"
            if [ $dtcm_min_addr -eq -1 ] || [ $relative_addr -lt $dtcm_min_addr ]; then
                dtcm_min_addr=$relative_addr
            fi
            if [ $dtcm_max_addr -eq -1 ] || [ $relative_addr -gt $dtcm_max_addr ]; then
                dtcm_max_addr=$relative_addr
            fi
            last_dtcm_addr=$relative_addr
            dtcm_count=$((dtcm_count + 1))
        fi
        current_addr=$((current_addr + 1))
    done
    
done < "$input_file"

echo "Memory split completed:"
echo "  ITCM: $itcm_file ($itcm_count entries)"
echo "  DTCM: $dtcm_file ($dtcm_count entries)"

# 更高效的mem输出函数
output_mem_file_arr() {
    local -n bytes_arr=$1
    local min_addr=$2
    local max_addr=$3
    local mem_file="$4"
    if [ $min_addr -eq -1 ]; then
        echo "// No data found" > "$mem_file"
        return
    fi
    > "$mem_file"
    local addr=$min_addr
    while [ $addr -le $max_addr ]; do
        # 取4字节
        byte0=${bytes_arr[$addr]:-00}
        byte1=${bytes_arr[$((addr+1))]:-00}
        byte2=${bytes_arr[$((addr+2))]:-00}
        byte3=${bytes_arr[$((addr+3))]:-00}
        printf "%s%s%s%s\n" "$byte3" "$byte2" "$byte1" "$byte0" >> "$mem_file"
        addr=$((addr + 4))
    done
}

# 输出ITCM和DTCM的mem文件（使用数组版本）
output_mem_file_arr itcm_bytes_arr $itcm_min_addr $itcm_max_addr "$itcm_mem_file"
output_mem_file_arr dtcm_bytes_arr $dtcm_min_addr $dtcm_max_addr "$dtcm_mem_file"

# 如果DTCM文件为空，创建一个空的占位符
if [ $dtcm_count -eq 0 ]; then
    echo "// No DTCM data found" > "$dtcm_file"
fi

# 如果ITCM文件为空，创建一个空的占位符
if [ $itcm_count -eq 0 ]; then
    echo "// No ITCM data found" > "$itcm_file"
fi