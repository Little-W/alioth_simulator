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
    #test_fails=`grep 'TEST_FAIL : *[0-9]*' $1  | sed 's/.*TEST_FAIL : *\([0-9]*\).*/\1/g'`
    test_fails=`grep "TEST_FAIL" $1 | wc -l`
    
    # 提取性能指标
    perf_line=`grep "PERF_METRIC:" $1`
    cycles=`echo $perf_line | grep -o "CYCLES=[0-9]*" | cut -d= -f2`
    insts=`echo $perf_line | grep -o "INSTS=[0-9]*" | cut -d= -f2`
    ipc=`echo $perf_line | grep -o "IPC=[0-9.]*" | cut -d= -f2`
    
    # 提取测试名称
    test_name=`grep -A1 "TESTCASE:" $1 | tail -n1 | tr -d '\r\n'`
    
    res=`expr $test_fails + 0`
    if [ $res -ne 0 ];
    	then 
    	    echo -e "${RED}FAIL${NC} $test_name | ${BLUE}Cycles:${NC} $cycles ${BLUE}Insts:${NC} $insts ${BLUE}IPC:${NC} $ipc | $(basename $1)";
        else 
            echo -e "${GREEN}PASS${NC} $test_name | ${BLUE}Cycles:${NC} $cycles ${BLUE}Insts:${NC} $insts ${BLUE}IPC:${NC} $ipc | $(basename $1)";
    fi
fi
