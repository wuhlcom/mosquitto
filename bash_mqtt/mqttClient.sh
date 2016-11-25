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
#source $sPath/logger.sh
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
		echo `date +"%Y-%m-%d %H:%M:%S"`>"$sPath"/subLoopNum
	        echo `expr $i - $sNum + 1`>>"$sPath"/subLoopNum	
	done
	#eTime=`date +"%Y-%m-%d %H:%M:%S"`
	#end=`date +%s -d "$eTime"`

	#monitor_log subresult&
	$sPath/logger.sh monitorlog&

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

mqttSub(){
      subtopic=$1
      subid=$2
      if [ -n "$3" ];then
         subqos=$3
         mosquitto_sub -t $subtopic -h $srv_ip -p $srv_port -q $subqos -i $subid -k $keepLive&
         echo client  \'$subid\' sub topic \'$subtopic\' qos \'$subqos\'
      else
         mosquitto_sub -t $subtopic -h $srv_ip -p $srv_port -i $subid -k $keepLive&
         echo client  \'$subid\' sub topic \'$subtopic\'
      fi
      
}

#mosuqitto_sub
mqtt_sub(){
	if $capFlag;then
	 cap
	fi

	j=0
	for i in `seq $sSubNum $eSubNum`
	do	
		subTopic="mosquittoTopic$i"
		subID="mosquittoSubId$i"
		mqttSub $subTopic $subID $j
		j=`expr $j + 1`
		if [ $j -ge 3 ]; then
			j=0
		fi
		echo `date +"%Y-%m-%d %H:%M:%S"`>"$sPath"/mqttSubNum
	        echo `expr $i - $sSubNum + 1`>>"$sPath"/mqttSubNum	
	done

	#monitor_log subresult&
	$sPath/logger.sh monitorlog&

}

mqttPub(){
        pubtopic=$1
        pubmsg=$2
	pubid=$3
        if [ -n "$4" ];then
        	pubqos=$4
		mosquitto_pub -t $pubtopic -m $pubmsg -h $srv_ip -p $srv_port -i $pubid  -q $pubqos
	else
		mosquitto_pub -t $pubtopic -m $pubmsg -h $srv_ip -p $srv_port -i $pubid 
	fi
}

#mosquitto_pub
mqtt_pub(){
	while true 
	do
		for i in `seq $sPubNum $ePubNum`
		do
			pubTopic="mosquittoTopic$i"
			pubID="mosquittoPubId$i"
			pubMsg="mosquittoMSG$i"
			mqttPub $pubTopic $pubID $pubMsg $pubQos
		done
	done
}

#stop sub or pub process
stopSubPub(){
	  pkill mosquitto_sub
	  pids=`ps -ef |grep mqttClient.sh|grep "\/bin\/bash"|awk -F " " '{print $2}'`
	  OLD_IFS="$IFS"
	  IFS=" "
	  arr=($pids)
	  IFS="$OLD_IFS"
	  for pid in ${arr[@]};
	  do 
	    kill -9 $pid
	  done
}

case $1 in
   "mqttsub")
     mqtt_sub
     ;;
   "mqttpub")
     mqtt_pub
     ;;
   "mqttclient")
     mqttClient
     ;;
   "stopsub")
     stopSubPub
     ;;
   *)
     echo "Please input mqttsub or mqttpub or mqttclient"
     ;;
esac

