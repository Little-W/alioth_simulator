#!/bin/bash
# 定义颜色
GREEN='\033[32m'
RED='\033[31m'
YELLOW='\033[33m'
BLUE='\033[34m'
NC='\033[0m' # No Color

ok=`grep "Test Result Summary" $1 | wc -l`
if [ $ok -ne "1" ];
then 
    echo -e "${YELLOW}NOT_FINISHED${NC} $1"
else
    test_fails=`grep "TEST_FAIL" $1 | wc -l`
    
    # 提取性能指标
    perf_line=`grep "PERF_METRIC:" $1`
    cycles=`echo $perf_line | grep -o "CYCLES=[0-9]*" | cut -d= -f2`
    insts=`echo $perf_line | grep -o "INSTS=[0-9]*" | cut -d= -f2`
    ipc=`echo $perf_line | grep -o "IPC=[0-9.]*" | cut -d= -f2`
    
    # 提取测试名称并只保留有效部分（去除cycle_count信息）
    test_name=`grep -A1 "TESTCASE:" $1 | tail -n1 | sed 's/~~~~~~~~~~~~~~Total cycle_count value:.*~//' | tr -d '\r\n'`
    
    res=`expr $test_fails + 0`
    if [ $res -ne 0 ];
    	then 
    	    printf "${RED}FAIL${NC} %-4s | ${BLUE}Cycles:${NC} %-6s ${BLUE}Insts:${NC} %-6s ${BLUE}IPC:${NC} %-6s | %s\n" \
               "$test_name" "$cycles" "$insts" "$ipc" "$(basename $1)"
        else 
            printf "${GREEN}PASS${NC} %-4s | ${BLUE}Cycles:${NC} %-6s ${BLUE}Insts:${NC} %-6s ${BLUE}IPC:${NC} %-6s | %s\n" \
               "$test_name" "$cycles" "$insts" "$ipc" "$(basename $1)"
    fi
fi
