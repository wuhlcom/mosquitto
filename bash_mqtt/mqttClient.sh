#!/bin/bash
#mosquitto client
#date: 2016-11-10
#auth: wuhongliang
#params:
#  snum,start number
#  enum,end number
#  srv_ip,mqtt server ip or domain
#
#sPath=`pwd`
sPath=`dirname $0`
source $sPath/mqtt.conf
source $sPath/logger.sh
source $sPath/tcpdump.sh
mqttClient(){

if $capFlag;then
 cap
fi
 
j=0
#sTime=`date +"%Y-%m-%d %H:%M:%S"`
#start=`date +%s -d "$sTime"`
for i in `seq $sNum $eNum`
do	
	topic="sendtopicpc166$i"
	id="clientidpc166$i"
        mosquitto_sub -t $topic -h $srv_ip -p $srv_port -q $j -i $id -k $keepLive&
	echo client  \'$id\' sub topic \'$topic\'
	j=`expr $j + 1`
	if [ $j -ge 3 ]; then
		j=0
	fi
	echo `date +"%Y-%m-%d %H:%M:%S"`>"$sPath"/subLoop
        echo `expr $i - $sNum + 1`>>"$sPath"/subLoop	
done
#eTime=`date +"%Y-%m-%d %H:%M:%S"`
#end=`date +%s -d "$eTime"`

monitor_log&

while true 
do
	for i in `seq $sNum $eNum`
	do
		topic="sendtopicpc166$i"
		id="pubidpc166$i"
		msg="PC166testMSG$i"
		mosquitto_pub -t $topic -m $msg -h $srv_ip -p $srv_port -i $id  -q 2 
		sleep 1
	done
done
}
mqttClient
