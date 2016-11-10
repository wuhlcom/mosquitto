#!/bin/sh
#mosquitto client
#date: 2016-11-10
#auth: wuhongliang
#params:
#  snum,start number
#  enum,end number
#  host,mqtt server ip or domain
#
snum=1
enum=100
j=0
host=192.168.10.103
for i in `seq $snum $enum`
do	
	topic="sensortopicpc166$i"
	id="clientidpc166$i"
	mosquitto_sub -t $topic -h $host -q $j -i $id -k 120&
	echo client  \'$id\' sub topic \'$topic\'
	j=`expr $j + 1`
	if [ $j -ge 3 ]; then
		j=0
	fi	
done

while true 
do
	for i in `seq $snum $enum`
	do
		topic="sensortopicpc166$i"
		id="pubidpc166$i"
		msg="PC166testMSG$i"
		mosquitto_pub -t $topic -m $msg -h $host -i $id  -q 2 
		sleep 1
	done
done
