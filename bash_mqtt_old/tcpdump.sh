#!/bin/bash
#capture packes and save
#user must be root
#auth:wuhongliang
#date 2016-11-16
# tcpdump tcp port 1883 -i 1 -w test.pcapng -C 81920 -W 10 
#intf="enp2s0"
#port="1883"
#capPath="caps/"
#capFile="cap_$intf.pcapng"
#capFileSize=1
#capFileNum=2
#source ./mqtt.conf
cap(){

if [ -n "$1" ];then
        captureFile=$1
else
        captureFile=$capFile
fi

if [ -n "$2" ];then
        capturePath=$2
else
        capturePath=$capPath
fi

if [ -n "$3" ];then
        fileSize=$3
else
        fileSize=$capFileSize
fi

if [ -n "$4" ];then
        fileNum=$4
else
        fileNum=$capFileNum
fi

if [ -n "$5" ];then
        interface=$5
else
        interface=$intf
fi

if [ -n "$6" ];then
        tcpPort=$6
else
        tcpPort=$filterPort
fi

captureFile="${captureFile}_${intf}_${cIP}.pcapng"
test -d $capPath||mkdir $capPath
#tcpdump -i "$interface" tcp port "$tcpPort" -w "$capturePath$captureFile" -C "$fileSize" -W "$fileNum"&
tcpdump -i "$interface" -w "$capturePath$captureFile" -C "$fileSize" -W "$fileNum"&
}



