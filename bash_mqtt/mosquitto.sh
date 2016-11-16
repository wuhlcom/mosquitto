#!/bin/bash
#mosquitto client
#date: 2016-11-10
#auth: wuhongliang
#params:
#  snum,start number
#  enum,end number
#  host,mqtt server ip or domain
#
#source client_monitor.sh
if [ -z $1 ];then
  host=192.168.10.188
else
  host=$1
fi

if [ -z $2 ];then
  port=1883
else
  port=$2
fi

if [ -z $3 ];then
  snum=1
else
  snum=$3
fi

if [ -z $4 ];then
  enum=10000
else
  enum=$4
fi

j=0
for i in `seq $snum $enum`
do	
	topic="sendtopicpc166$i"
	id="clientidpc166$i"
	mosquitto_sub -t $topic -h $host -p $port -q $j -i $id -k 120&
	echo client  \'$id\' sub topic \'$topic\'
	j=`expr $j + 1`
	if [ $j -ge 3 ]; then
		j=0
	fi	
done

source ./logger.sh
monitor_log&

while true 
do
	for i in `seq $snum $enum`
	do
		topic="sendtopicpc166$i"
		id="pubidpc166$i"
		msg="PC166testMSG$i"
		mosquitto_pub -t $topic -m $msg -h $host -p $port -i $id  -q 2 
		sleep 1
	done
done
