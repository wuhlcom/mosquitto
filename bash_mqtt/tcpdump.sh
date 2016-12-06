#!bin/bash
#capture packes and save
#user must be root
#auth:wuhongliang
#date 2016-11-16
#intf="enp2s0"
#port="1883"
#capPath="caps/"
#capFile="cap_$intf.pcapng"
#capFileSize=1
#capFileNum=2
#
#source ./mqtt.conf
# tcpdump tcp port 1883 -i 1 -w test.pcapng -C 81920 -W 10 
cap(){
test -d $capPath||mkdir $capPath
sudo nohup tcpdump -i "$intf" tcp port "$filterPort" -w "$capPath$capFile" -C "$capFileSize" -W "$capFileNum"&
}
