#!/bin/bash
#mosquitto client
#date: 2016-11-10
#auth: wuhongliang
# 
#mosquitto_sub mosquitto_pub
#
#sPath=`pwd`
sPath=`dirname $0`
source $sPath/mqtt.conf
source $sPath/tcpdump.sh
echoFlag=true

#mosquitto_sub
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

#mosquitto_sub
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
		echo `date +"%Y-%m-%d %H:%M:%S"`>${sPath}/${subFName}
	        echo `expr $i - $sSubNum + 1`>>${sPath}/${subFName}	
	done

	#monitor_log subresult&
	$sPath/logger.sh monitorlog&

}

#mqtt pub
mqttPub(){
        pubtopic=$1
        pubmsg=$2
	pubid=$3
        if [ -n "$4" ];then
        	pubqos=$4
		mosquitto_pub -t $pubtopic -m $pubmsg -h $srv_ip -p $srv_port -i $pubid  -q $pubqos&
	else
		mosquitto_pub -t $pubtopic -m $pubmsg -h $srv_ip -p $srv_port -i $pubid&
	fi
}

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

#先订阅后发布，主题保持不变
mqttSubPub(){
	echoFlag=false
	if $capFlag;then
	 cap
	fi
 
	j=0
	:>$sPath/${subPubFName}
	for i in `seq $pubSubSNum $pubSubENum`
	do	
		sid="mqttsubid$i"
		mqttSub $subPubTopic $sid $j>>$sPath/${subPubFNamei}
		j=`expr $j + 1`
		if [ $j -ge 3 ]; then
			j=0
		fi
	done
        sleep $subPubGap 
        #发布消息的序列可以与订阅的序列不一样
	for i in `seq $subPubSNum $subPubENum`
	do
		pid="mqttpubid$i"
		msg="mqttpubmsg$i"
		mqttPub $subPubTopic $msg $pid $pubQos
	done
}

#mqtt pub retain
mqttPubR(){
        pubtopic=$1
        pubmsg=$2
	pubid=$3
     	pubqos=2
	mosquitto_pub -t $pubtopic -m $pubmsg -h $srv_ip -p $srv_port -i $pubid  -q $pubqos -r&
}

#plenty of mqtt pub retain msg
mqttPub_R(){
  for i in `seq $pubRsNum $pubReNum`
  do
    rPubTopic="pubTopicRetain${i}"
    rPubMsg="pubMsgRetain${i}"
    rPubID="pubIDRetain${i}"
    mqttPubR $rPubTopic $rPubMsg $rPubID 
  done
}

#mosquitto_sub retain msg
mqttSub_R(){
	echoFlag=false
	if $capFlag;then
	 cap
	fi
        :>${subPubRFName}
	j=0
	for i in `seq $pubRsNum $pubReNum`
	do	
           rPubTopic="pubTopicRetain${i}"
	   rSubID="subMsgRetainId$i"
  	   mqttSub $rPubTopic $rSubID $j>>${sPath}/${subPubRFName}
	   j=`expr $j + 1`
	   if [ $j -ge 3 ]; then
		j=0
	   fi
       done
       $sPath/logger.sh monitorlog&
}
#pub retain message,then sub them
subPubRetain(){
  echoFlag=false
  :>${subPubRFName}
  j=0
 
  if $capFlag;then
    cap
  fi
  
  for i in `seq $pubRsNum $pubReNum`
  do
    rPubTopic="pubTopicRetain${i}"
    rPubMsg="pubMsgRetain${i}"
    rPubID="pubRetainID${i}"
    mqttPubR $rPubTopic $rPubMsg $rPubID 
  done

  sleep $retainGap 

  for i in `seq $pubRsNum $pubReNum`
    do	
       rPubTopic="pubTopicRetain${i}"
       rSubID="subRetainID$i"
       #必须加&
       mqttSub $rPubTopic $rSubID $j>>${sPath}/${subPubRFName}&
       j=`expr $j + 1`
       if [ $j -ge 3 ]; then
        	j=0
       fi
    done
    $sPath/logger.sh monitorlog&
}

#stop plenty of mqtt pub retain msg
stopMqttPub_R(){
  for i in `seq $pubRsNum $pubReNum`
  do
    rPubTopic="pubTopicRetain${i}"
    rPubID="pubIDRetain${i}"
    mosquitto_pub -t $rPubTopic -n -h $srv_ip -p $srv_port -i $rPubID  -q 2 -r&
  done
}

stopSubRetain(){
 stopSubPub
 stopMqttPub_R
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
   "pubretain")
     mqttPub_R
     ;;
   "subretain")
     mqttSub_R
     ;;
   "stopretain")
     stopMqttPub_R
     ;;
   "stopsubretain")
     stopSubRetain
     ;;
   "subpubretain")
     subPubRetain
     ;;
   *)
     echo "mqttClient.sh"
     ;;
esac

