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
sub(){
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

subAcc(){
   if $mqttAuth;then
    subIDPre="mosquittoSubId"
    ssh $rootusr@$srv_ip "${remote_dir}/mqttAuth.sh $sSubNum $eSubNum $subIDPre ${intf}-${cIP}-sub"
  fi
}

#mosquitto_sub
subLoopNoAcc(){
	if $capFlag;then
	 cap
	fi
          
	j=0
        subIDPre="mosquittoSubId"
	subTopicPre="mosquittoTopic"
        #create mqtt usr passwd
        if $mqttAuth;then
		#ssh $rootusr@$srv_ip "${remote_dir}/mqttAuth.sh $sSubNum $eSubNum $subIDPre ${intf}-${cIP}-sub"
 		#subAcc
		for i in `seq $sSubNum $eSubNum`
		do	
			subTopic="$subTopicPre$i"
			subID="$subIDPre$i"
			sub $subTopic $subID $defaultUsr $defaultPasswd $j
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
			sub $subTopic $subID $j
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

subLoop(){
 subAcc
 subLoopNoAcc
}
#一次性订阅
subC(){
      subtopic=$1
      subid=$2
      if [ -z "$3" ] || [ -z "$4" ] ;then
            echo "ERROR:Please input the mosquitto client usrname and password!"
      fi
      
      usr=$3
      passwd=$4
      subqos=$5

      if [ -z "$6" ];then
        count=1
      else
        count=$6
      fi

      mosquitto_sub -t $subtopic -h $srv_ip -p $srv_port -q $subqos -i $subid -k $keepLive -u $usr -P $passwd -C $count&
      if $echoFlag;then
            echo client  \'$subid\' sub topic \'$subtopic\' usrname $usr passwd $passwd qos $subqos
      fi
} 

#一次性订阅账户创建
subCAcc(){
    ssh $rootusr@$srv_ip "${remote_dir}/mqttAuth.sh $subCsNum $subCeNum $subCIDPre ${intf}-${cIP}-subCLoop"
}

subCLoopNoAcc(){
        j=0
        for i in `seq $subCsNum $subCeNum`
        do
                subID="$subCIDPre$i"
                subC $subCTopic $subID $defaultUsr $defaultPasswd $j
                j=`expr $j + 1`
                if [ $j -ge 3 ]; then
                       j=0
                fi
                :>${sPath}/${subCFName}
                echo `expr $i - $subCsNum + 1`>>${sPath}/${subCFName}
        done

}

subCLoop(){
   subCAcc
   subCLoopNoAcc
}
 
#mqtt pub
pub(){
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

#
pubCAcc(){
      ssh $rootusr@$srv_ip "${remote_dir}/mqttAuth.sh 0 0 $pubCID ${intf}-${cIP}-pubC"
}
#
pubCNoAcc(){
     pub $subCTopic $pubCMsg $pubCID $pubQos $defaultUsr $defaultPasswd
}

#pub msg
pubC(){
	#ssh $rootusr@$srv_ip "${remote_dir}/mqttAuth.sh 0 0 $pubCID ${intf}-${cIP}-pubC"
	#pub $subCTopic $pubCMsg $pubCID $pubQos $defaultUsr $defaultPasswd
        pubCAcc
        pubCNoAcc
}

pubAcc(){
	if $mqttAuth;then
	  pubIDPre="mosquittoPubId"
	  ssh $rootusr@$srv_ip "${remote_dir}/mqttAuth.sh $sPubNum $ePubNum $pubIDPre ${intf}-${cIP}-pub"
	fi
}

#大量发布
pubLoopNoAcc(){
	pubTopicPre="mosquittoTopic"
	pubMsgPre="mosquittoMSG"
	pubIDPre="mosquittoPubId"
	if $mqttAuth;then
	        #cp local mqtt.conf to remote client
		#ssh $rootusr@$srv_ip "${remote_dir}/mqttAuth.sh $sPubNum $ePubNum $pubIDPre ${intf}-${cIP}-pub"
		for i in `seq $sPubNum $ePubNum`
		do
			pubTopic="$pubTopicPre$i"
			pubMsg="$pubMsgPre$i"
			pubID="$pubIDPre$i"
			pub $pubTopic $pubMsg $pubID $pubQos $defaultUsr $defaultPasswd
		done
       else 
		for i in `seq $sPubNum $ePubNum`
		do
			pubTopic="$pubTopicPre$i"
			pubID="$pubIDPre$i"
			pubMsg="$pubMsgPre$i"
			pub $pubTopic $pubID $pubMsg $pubQos
		done
	fi
}
pubLoop(){
  pubAcc
  pubLoopNoAcc
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

subPubAcc(){
	if $mqttAuth;then
                subIDPre="mqttsubid"
		ssh $rootusr@$srv_ip "${remote_dir}/mqttAuth.sh $pubSubSNum $pubSubENum $subIDPre ${intf}-${cIP}-pubsub"
	fi
}

#先订阅后发布，主题保持不变
subPubNoAcc(){
	echoFlag=false
	if $capFlag;then
	 cap
	fi
 
	j=0
	:>$sPath/${subPubRecieved}
        subIDPre="mqttsubid"
	pubIDPre="mosquittoPubId"
	pubMsgPre="mosquittoMSG"
	if $mqttAuth;then
		#ssh $rootusr@$srv_ip "${remote_dir}/mqttAuth.sh $pubSubSNum $pubSubENum $subIDPre ${intf}-${cIP}-pubsub"
		for i in `seq $pubSubSNum $pubSubENum`
		do	
			subID="$subIDPre$i"
			sub $subPubTopic $subID $defaultUsr $defaultPasswd $j>>$sPath/${subPubRecieved}
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
			pub $subPubTopic $pubMsg $pubID $pubQos $defaultUsr $defaultPasswd
		done
	else
		for i in `seq $pubSubSNum $pubSubENum`
		do	
			sid="$pubIDPre$i"
			sub $subPubTopic $sid $j>>$sPath/${subPubRecieved}
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
			pub $subPubTopic $msg $pid $pubQos
		done
	fi
}

subPub(){
 subPubAcc
 subPubNoAcc
}

#mqtt pub retain
pubR(){
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
pubRAcc(){
  if $mqttAuth;then
      rPubIDPre="pubIDRetain"
      ssh $rootusr@$srv_ip "${remote_dir}/mqttAuth.sh $pubRsNum $pubReNum $rPubIDPre ${intf}-${cIP}-pubR"
  fi
}
#plenty of mqtt pub retain msg
pubRLoopNoAcc(){
  rPubIDPre="pubIDRetain"
  rPubTopicPre="pubTopicRetain"
  rPubMsgPre="pubMsgRetain"
  if $mqttAuth;then
     # ssh $rootusr@$srv_ip "${remote_dir}/mqttAuth.sh $pubRsNum $pubReNum $rPubIDPre ${intf}-${cIP}-pubR"
      for i in `seq $pubRsNum $pubReNum`
      do
    	rPubTopic="$rPubTopicPre${i}"
	rPubMsg="$rPubMsgPre${i}"
	rPubID="$rPubIDPre${i}"
	pubR $rPubTopic $rPubMsg $rPubID $defaultUsr $defaultPasswd 
     done
  else  
     for i in `seq $pubRsNum $pubReNum`
     do
       rPubTopic="$rPubTopicPre${i}"
       rPubMsg="$rPubMsgPre${i}"
       rPubID="$rPubIDPre${i}"
       pubR $rPubTopic $rPubMsg $rPubID 
     done
 fi
}

pubRLoop(){
 pubRAcc
 pubRLoopNoAcc
}  

subRAcc(){
	rSubIDPre="subMsgRetainId"
	if $mqttAuth;then
		ssh $rootusr@$srv_ip "${remote_dir}/mqttAuth.sh $pubRsNum $pubReNum $rSubIDPre ${intf}-${cIP}-subR"
	fi
} 
#mosquitto_sub retain msg
subRLoopNoAcc(){
	echoFlag=false
	if $capFlag;then
	 cap
	fi

        :>${subPubRRecieved}
	j=0
	rSubIDPre="subMsgRetainId"
       	rPubTopicPre="pubTopicRetain"
	if $mqttAuth;then
		#ssh $rootusr@$srv_ip "${remote_dir}/mqttAuth.sh $pubRsNum $pubReNum $rSubIDPre ${intf}-${cIP}-subR"
		for i in `seq $pubRsNum $pubReNum`
		do	
        	   rPubTopic="$rPubTopicPre${i}"
		   rSubID="$rSubIDPre$i"
  		   sub $rPubTopic $rSubID $defaultUsr $defaultPasswd $j>>${sPath}/${subPubRRecieved}
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
  		   sub $rPubTopic $rSubID $j>>${sPath}/${subPubRRecieved}
		   j=`expr $j + 1`
		   if [ $j -ge 3 ]; then
			j=0
		   fi
	       done
	fi
       $sPath/logger.sh monitorlog&
}
subRLoop(){
 subRAcc
 subRLoopNoAcc
}

subPubRetainAcc(){
  rPubIDPre="pubRetainID"
  if $mqttAuth;then 
	ssh $rootusr@$srv_ip "${remote_dir}/mqttAuth.sh $pubRsNum $pubReNum $rPubIDPre ${intf}-${cIP}-subpubR"
  fi
}
 
#pub retain message,then sub them
subPubRetainNoAcc(){
  echoFlag=false
  :>${subPubRRecieved}
  j=0
 
  if $capFlag;then
    cap
  fi
  
  rPubTopicPre="pubTopicRetain"
  rPubMsgPre="pubMsgRetain"
  rPubIDPre="pubRetainID"
  rSubIDPre="subRetainID"
  if $mqttAuth;then 
#	ssh $rootusr@$srv_ip "${remote_dir}/mqttAuth.sh $pubRsNum $pubReNum $rPubIDPre ${intf}-${cIP}-subpubR"
  	for i in `seq $pubRsNum $pubReNum`
	do
	    rPubTopic="$rPubTopicPre${i}"
	    rPubMsg="$rPubMsgPre${i}"
	    rPubID="$rPubIDPre${i}"
	    pubR $rPubTopic $rPubMsg $rPubID $defaultUsr $defaultPasswd 
	 done

	 sleep $retainGap 

	ssh $rootusr@$srv_ip "${remote_dir}/mqttAuth.sh $pubRsNum $pubReNum $rSubIDPre ${intf}-${cIP}-pubsubR"
	for i in `seq $pubRsNum $pubReNum`
	do	
	       rPubTopic="$rPubTopicPre${i}"
	       rSubID="$rSubIDPre$i"
	       #必须加&
	       sub $rPubTopic $rSubID $defaultUsr $defaultPasswd $j>>${sPath}/${subPubRRecieved}&
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
	    pubR $rPubTopic $rPubMsg $rPubID 
	done

	sleep $retainGap 

	for i in `seq $pubRsNum $pubReNum`
	do	
	   rPubTopic="$rPubTopicPre${i}"
	   rSubID="$rSubIDPre$i"
	   #必须加&
  	   sub $rPubTopic $rSubID $j>>${sPath}/${subPubRRecieved}&
	   j=`expr $j + 1`
	   if [ $j -ge 3 ]; then
        	j=0
	   fi
	done
 fi

 $sPath/logger.sh monitorlog&
}

subPubRetain(){
 subPubRetainAcc
 subPubRetainNoAcc
}

#stop plenty of mqtt pub retain msg
stopPubR(){
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
 stopPubR
}

case $1 in
   "subloop")
     subLoop
     ;;
   "publoop")
     pubLoop
     ;;
   "stopsubpub")
     stopSubPub
     ;;
   "subpub")
     subPub
     ;;
   "pubrloop")
     pubRLoop
     ;;
   "subrloop")
     subRLoop
     ;;
   "stoppubr")
     stopPubR
     ;;
   "stopsubretain")
     stopSubRetain
     ;;
   "subpubretain")
     subPubRetain
     ;;
   "subcloop")
     subCLoop
     ;;
   "subcloopnoacc")
     subCLoopNoAcc
     ;;
   "pubc")
     pubC
     ;;
   *)
     #echo "mqttClient.sh"
     ;;
esac

