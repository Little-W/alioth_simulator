#!/bin/bash
# 定义颜色
GREEN='\033[32m'
RED='\033[31m'
YELLOW='\033[33m'
NC='\033[0m' # No Color

ok=`grep "Test Result Summary" $1 | wc -l`
if [ $ok -ne "1" ];
then 
    echo -e "${YELLOW}NOT_FINISHED${NC} $1"
else
    #test_fails=`grep 'TEST_FAIL : *[0-9]*' $1  | sed 's/.*TEST_FAIL : *\([0-9]*\).*/\1/g'`
    test_fails=`grep "TEST_FAIL" $1 | wc -l`
    res=`expr $test_fails + 0`
    if [ $res -ne 0 ];
    	then echo -e "${RED}FAIL${NC} $1";
        else echo -e "${GREEN}PASS${NC} $1";
    fi
fi
