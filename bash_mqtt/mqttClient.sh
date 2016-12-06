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
scp ${sPath}/mqtt.conf $rootusr@${srv_ip}:${remote_dir}
#mosquitto_sub
mqttSub(){
      subtopic=$1
      subid=$2
      if $mqttAuth;then
          if [ -z "$3" ] || [ -z "$4" ] ;then
              echo "ERROR:Please input the mosquitto client usrname and password!"
          fi
         usr=$3
         passwd=$4
         subqos=$5
         mosquitto_sub -t $subtopic -h $srv_ip -p $srv_port -q $subqos -i $subid -k $keepLive -u $usr -P $passwd&
        if $echoFlag;then
                 echo client  \'$subid\' sub topic \'$subtopic\' usrname $usr passwd $passwd qos $subqos 
        fi
     else 
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
     fi
}

#mosquitto_sub
mqtt_sub(){
	if $capFlag;then
	 cap
	fi
          
	j=0
        subIDPre="mosquittoSubId"
	subTopicPre="mosquittoTopic"
        #create mqtt usr passwd
        if $mqttAuth;then
	        #cp local mqtt.conf to remote client
		ssh $rootusr@$srv_ip "${remote_dir}/mqttAuth.sh $sSubNum $eSubNum $subIDPre ${intf}-${cIP}-sub"
		for i in `seq $sSubNum $eSubNum`
		do	
			subTopic="$subTopicPre$i"
			subID="$subIDPre$i"
			mqttSub $subTopic $subID $defaultUsr $defaultPasswd $j
			j=`expr $j + 1`
                        if [ $j -ge 3 ]; then
                               j=0
                        fi
 
			echo `date +"%Y-%m-%d %H:%M:%S"`>${sPath}/${subFName}
	        	echo `expr $i - $sSubNum + 1`>>${sPath}/${subFName}	
		done
        else
		for i in `seq $sSubNum $eSubNum`
		do	
			subTopic="$subTopicPre$i"
			subID="$subIDPre$i"
			mqttSub $subTopic $subID $j
			j=`expr $j + 1`
			if [ $j -ge 3 ]; then
				j=0
			fi
			echo `date +"%Y-%m-%d %H:%M:%S"`>${sPath}/${subFName}
		        echo `expr $i - $sSubNum + 1`>>${sPath}/${subFName}	
		done
        fi

	#monitor_log subresult&
	$sPath/logger.sh monitorlog&
}

subPerform(){
	ssh $rootusr@$srv_ip "${remote_dir}/mqttAuth.sh $subPersNum $subPereNum $subPerIDPre ${intf}-${cIP}-subPerform"
	for i in `seq $subPersNum $subPereNum`
	do	
		subID="$subPerIDPre$i"
		mqttSub $subPerTopic $subID $defaultUsr $defaultPasswd $j -C 1
		j=`expr $j + 1`
	        if [ $j -ge 3 ]; then
        	       j=0
	        fi
	done
}
 
#mqtt pub
mqttPub(){
        pubtopic=$1
        pubmsg=$2
	pubid=$3
        if $mqttAuth;then
                 if [ -z "$3" ] || [ -z "$4" ] ;then
              		echo "ERROR:Please input the mosquitto client usrname and password!"
	         fi
        	 pubqos=$4
        	 usr=$5
	         passwd=$6
		 mosquitto_pub -t $pubtopic -m $pubmsg -h $srv_ip -p $srv_port -i $pubid -q $pubqos -u $usr -P $passwd&
        else
		if [ -n "$4" ];then
        		pubqos=$4
			mosquitto_pub -t $pubtopic -m $pubmsg -h $srv_ip -p $srv_port -i $pubid  -q $pubqos&
		else
			mosquitto_pub -t $pubtopic -m $pubmsg -h $srv_ip -p $srv_port -i $pubid&
		fi
	fi
}

pubPerform(){
	ssh $rootusr@$srv_ip "${remote_dir}/mqttAuth.sh 0 0 $pubPerID ${intf}-${cIP}-perPub"
	mqttPub $subPerTopic $pubPerMsg $pubPerID $pubQos $defaultUsr $defaultPasswd
}

mqtt_pub(){
	pubTopicPre="mosquittoTopic"
	pubMsgPre="mosquittoMSG"
	pubIDPre="mosquittoPubId"
	if $mqttAuth;then
	        #cp local mqtt.conf to remote client
		ssh $rootusr@$srv_ip "${remote_dir}/mqttAuth.sh $sPubNum $ePubNum $pubIDPre ${intf}-${cIP}-pub"
		for i in `seq $sPubNum $ePubNum`
		do
			pubTopic="$pubTopicPre$i"
			pubMsg="$pubMsgPre$i"
			pubID="$pubIDPre$i"
			mqttPub $pubTopic $pubMsg $pubID $pubQos $defaultUsr $defaultPasswd
		done
       else 
		for i in `seq $sPubNum $ePubNum`
		do
			pubTopic="$pubTopicPre$i"
			pubID="$pubIDPre$i"
			pubMsg="$pubMsgPre$i"
			mqttPub $pubTopic $pubID $pubMsg $pubQos
		done
	fi
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
        subIDPre="mqttsubid"
	pubIDPre="mosquittoPubId"
	pubMsgPre="mosquittoMSG"
	if $mqttAuth;then
		ssh $rootusr@$srv_ip "${remote_dir}/mqttAuth.sh $pubSubSNum $pubSubENum $subIDPre ${intf}-${cIP}-pubsub"
		for i in `seq $pubSubSNum $pubSubENum`
		do	
			subID="$subIDPre$i"
			mqttSub $subPubTopic $subID $defaultUsr $defaultPasswd $j>>$sPath/${subPubFName}
			j=`expr $j + 1`
                        if [ $j -ge 3 ]; then
                               j=0
                        fi
		done
	        
		sleep $subPubGap 
        	
		#发布消息的序列可以与订阅的序列不一样
		ssh $rootusr@$srv_ip "${remote_dir}/mqttAuth.sh $subPubSNum $subPubENum $pubIDPre ${intf}-${cIP}-subpub"
		for i in `seq $subPubSNum $subPubENum`
		do
			pubID="$pubIDPre$i"
			pubMsg="$pubMsgPre$i"
			mqttPub $subPubTopic $pubMsg $pubID $pubQos $defaultUsr $defaultPasswd
		done
	else
		for i in `seq $pubSubSNum $pubSubENum`
		do	
			sid="$pubIDPre$i"
			mqttSub $subPubTopic $sid $j>>$sPath/${subPubFName}
			j=`expr $j + 1`
			if [ $j -ge 3 ]; then
				j=0
			fi
		done
	        sleep $subPubGap 
        	#发布消息的序列可以与订阅的序列不一样
		for i in `seq $subPubSNum $subPubENum`
		do
			pid="$pubIDPre$i"
			msg="$subMsgPre$i"
			mqttPub $subPubTopic $msg $pid $pubQos
		done
	fi
}

#mqtt pub retain
mqttPubR(){
        pubtopic=$1
        pubmsg=$2
	pubid=$3
	if $mqttAuth;then
		usrname=$4
		passwd=$5
		mosquitto_pub -t $pubtopic -m $pubmsg -h $srv_ip -p $srv_port -i $pubid  -q $pubQos -r -u $usrname -P $passwd&
	else
		mosquitto_pub -t $pubtopic -m $pubmsg -h $srv_ip -p $srv_port -i $pubid  -q $pubQos -r&
	fi
}

#plenty of mqtt pub retain msg
mqttPub_R(){
  rPubIDPre="pubIDRetain"
  rPubTopicPre="pubTopicRetain"
  rPubMsgPre="pubMsgRetain"
  if $mqttAuth;then
      ssh $rootusr@$srv_ip "${remote_dir}/mqttAuth.sh $pubRsNum $pubReNum $rPubIDPre ${intf}-${cIP}-pubR"
      for i in `seq $pubRsNum $pubReNum`
      do
    	rPubTopic="$rPubTopicPre${i}"
	rPubMsg="$rPubMsgPre${i}"
	rPubID="$rPubIDPre${i}"
	mqttPubR $rPubTopic $rPubMsg $rPubID $defaultUsr $defaultPasswd 
     done
  else  
     for i in `seq $pubRsNum $pubReNum`
     do
       rPubTopic="$rPubTopicPre${i}"
       rPubMsg="$rPubMsgPre${i}"
       rPubID="$rPubIDPre${i}"
       mqttPubR $rPubTopic $rPubMsg $rPubID 
     done
 fi
}

#mosquitto_sub retain msg
mqttSub_R(){
	echoFlag=false
	if $capFlag;then
	 cap
	fi

        :>${subPubRFName}
	j=0
	rSubIDPre="subMsgRetainId"
       	rPubTopicPre="pubTopicRetain"
	if $mqttAuth;then
		ssh $rootusr@$srv_ip "${remote_dir}/mqttAuth.sh $pubRsNum $pubReNum $rSubIDPre ${intf}-${cIP}-subR"
		for i in `seq $pubRsNum $pubReNum`
		do	
        	   rPubTopic="$rPubTopicPre${i}"
		   rSubID="$rSubIDPre$i"
  		   mqttSub $rPubTopic $rSubID $defaultUsr $defaultPasswd $j>>${sPath}/${subPubRFName}
		   j=`expr $j + 1`
		   if [ $j -ge 3 ]; then
			j=0
		   fi
	       done
	else
		for i in `seq $pubRsNum $pubReNum`
		do	
        	   rPubTopic="$rPubTopicPre${i}"
		   rSubID="$rSubIDPre$i"
  		   mqttSub $rPubTopic $rSubID $j>>${sPath}/${subPubRFName}
		   j=`expr $j + 1`
		   if [ $j -ge 3 ]; then
			j=0
		   fi
	       done
	fi
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
  
  rPubTopicPre="pubTopicRetain"
  rPubMsgPre="pubMsgRetain"
  rPubIDPre="pubRetainID"
  rSubIDPre="subRetainID"
  if $mqttAuth;then 
	ssh $rootusr@$srv_ip "${remote_dir}/mqttAuth.sh $pubRsNum $pubReNum $rPubIDPre ${intf}-${cIP}-subpubR"
  	for i in `seq $pubRsNum $pubReNum`
	do
	    rPubTopic="$rPubTopicPre${i}"
	    rPubMsg="$rPubMsgPre${i}"
	    rPubID="$rPubIDPre${i}"
	    mqttPubR $rPubTopic $rPubMsg $rPubID $defaultUsr $defaultPasswd 
	 done

	 sleep $retainGap 

	ssh $rootusr@$srv_ip "${remote_dir}/mqttAuth.sh $pubRsNum $pubReNum $rSubIDPre ${intf}-${cIP}-pubsubR"
	for i in `seq $pubRsNum $pubReNum`
	do	
	       rPubTopic="$rPubTopicPre${i}"
	       rSubID="$rSubIDPre$i"
	       #必须加&
	       mqttSub $rPubTopic $rSubID $defaultUsr $defaultPasswd $j>>${sPath}/${subPubRFName}&
	       j=`expr $j + 1`
	       if [ $j -ge 3 ]; then
	        	j=0
	       fi
	done
  else
	for i in `seq $pubRsNum $pubReNum`
	do
	    rPubTopic="$rPubTopicPre${i}"
	    rPubMsg="$rPubMsgPre${i}"
	    rPubID="$rPubID${i}"
	    mqttPubR $rPubTopic $rPubMsg $rPubID 
	done

	sleep $retainGap 

	for i in `seq $pubRsNum $pubReNum`
	do	
	   rPubTopic="$rPubTopicPre${i}"
	   rSubID="$rSubIDPre$i"
	   #必须加&
  	   mqttSub $rPubTopic $rSubID $j>>${sPath}/${subPubRFName}&
	   j=`expr $j + 1`
	   if [ $j -ge 3 ]; then
        	j=0
	   fi
	done
 fi

 $sPath/logger.sh monitorlog&
}

#stop plenty of mqtt pub retain msg
stopMqttPub_R(){
 rPubTopicPre="pubTopicRetain"
 rPubIDPre="pubIDRetain"
 if $mqttAuth;then
   for i in `seq $pubRsNum $pubReNum`
   do
     rPubTopic="$rPubTopicPre${i}"
     rPubID="$rPubIDPre${i}"
     mosquitto_pub -t $rPubTopic -n -h $srv_ip -p $srv_port -i $rPubID  -q 2 -r -u $defaultUsr -P $defaultPasswd&
   done
 else
   for i in `seq $pubRsNum $pubReNum`
   do
     rPubTopic="$rPubTopicPre${i}"
     rPubID="$rPubIDPre${i}"
     mosquitto_pub -t $rPubTopic -n -h $srv_ip -p $srv_port -i $rPubID  -q 2 -r&
   done
 fi
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

