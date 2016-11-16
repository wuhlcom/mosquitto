#!bin/bash
#auth:wuhongliang
#date 2016-11-16
#intf="enp2s0"
#port="1883"
#capPath="caps/"
#capFile="cap_$intf.pcapng"
#capFileSize=1
#capFileNum=2
source ./mqtt.conf
echo $capPath
echo $capFileSize
cap(){
test -d $capPath||mkdir $capPath
tcpdump -i intf tcp port "$port" -w "$capPath$capFile" -C "$capFileSize" -W "$capFileNum"&
}
