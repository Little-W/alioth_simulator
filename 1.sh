#!/bin/bash

# 查找所有 .v 文件（不包括以 .sv 结尾的），递归遍历
find . -type f -name "*.v" ! -name "*.sv" | while read -r file; do
    # 获取目录名和基础文件名
    dir=$(dirname "$file")
    base=$(basename "$file" .v)
    new_file="$dir/$base.sv"

    # 重命名
    mv "$file" "$new_file"
    echo "Renamed $file to $new_file"
done
