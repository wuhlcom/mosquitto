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
echoFlag=true

mqttSub(){
      subtopic=$1
      subid=$2
      if [ -n "$3" ];then
         subqos=$3
         mosquitto_sub -t $subtopic -h $srv_ip -p $srv_port -q $subqos -i $subid -k $keepLive&
        if $echoFlag;then
		 echo client  \'$subid\' sub topic \'$subtopic\' qos \'$subqos\'
	fi
      else
         mosquitto_sub -t $subtopic -h $srv_ip -p $srv_port -i $subid -k $keepLive&
        if $echoFlag;then
         echo client  \'$subid\' sub topic \'$subtopic\'
	fi
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

mqttSubPub(){
        topic="mqtttopic"
	echoFlag=false
	if $capFlag;then
	 cap
	fi
 
	j=0
	>subPubMsg
	for i in `seq $pubSubSNum $pubSubENum`
	do	
		sid="mqttsubid$i"
		mqttSub $topic $sid $j>>subPubMsgNum
		j=`expr $j + 1`
		if [ $j -ge 3 ]; then
			j=0
		fi
	done

#	while true 
#	do
		for i in `seq $subPubSNum $subPubENum`
		do
			pid="mqttpubid$i"
			msg="mqttpubmsg$i"
			mqttPub $topic $pid $msg $pubQos
		done
#	done
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
   "subpub")
     mqttSubPub
     ;;
   *)
     echo "Please input mqttsub or mqttpub or mqttclient"
     ;;
esac

