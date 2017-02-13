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
      subAuType=$7
      #当没有赋值$7时设置subAuType的默认值为“pw”
      if [ -n "$subAuType" ];then subAuTye="pw";fi
      if [ "$subAuType" = "pw" ];then
         if [ -z "$3" ] || [ -z "$4" ] ;then
              echo "ERROR:Please input the mosquitto client usrname and password!"
         fi
         usr=$3
         passwd=$4
         subqos=$5
         msglog=$6
        if $echoFlag;then
                 echo client  \'$subid\' sub topic \'$subtopic\' usrname \'$usr\' passwd \'$passwd\' qos \'$subqos\' 
        fi
        if [ -z "$msglog" ];then
          mosquitto_sub -t $subtopic -h $srv_ip -p $srv_port -q $subqos -i $subid -k $keepLive -u $usr -P $passwd&
        else
          #注意">>"前后都有空格
          mosquitto_sub -t $subtopic -h $srv_ip -p $srv_port -q $subqos -i $subid -k $keepLive -u $usr -P $passwd >> $msglog&
        fi
     elif [ "$subAuType" = "siCa" ];then
         usr=$3
         passwd=$4
         subqos=$5
         msglog=$6
	 mosquitto_sub -t $subtopic -h $srv_ip -p $srv_port -i $subid -k $keepLive -u $usr  -P $passwd --cafile $carPath >> $mesglog&
     elif [ "$subAuType" = "biCa" ];then
         usr=$3
         passwd=$4
         subqos=$5
         msglog=$6
	 mosquitto_sub -t $subtopic -h $srv_ip -p $srv_port -i $subid -k $keepLive -u $usr  -P $passwd --cafile $carPath --cert $crtPath --key $keyPath>> $mesglog&
     else 
       if [ -n "$3" ];then
          subqos=$3
          msglog=$4
          if $echoFlag;then
		 echo client  \'$subid\' sub topic \'$subtopic\' qos \'$subqos\'
	  fi
          if [ -z "$msglog" ];then
             mosquitto_sub -t $subtopic -h $srv_ip -p $srv_port -q $subqos -i $subid -k $keepLive&
    	  else
             mosquitto_sub -t $subtopic -h $srv_ip -p $srv_port -q $subqos -i $subid -k $keepLive >> $msglog&
          fi
       else
         if $echoFlag;then
           echo client  \'$subid\' sub topic \'$subtopic\'
	 fi
         mosquitto_sub -t $subtopic -h $srv_ip -p $srv_port -i $subid -k $keepLive&
      fi
     fi
}

createAccount(){
   if $mqttAuth;then
    IDPre=$1
    SNum=$2
    ENum=$3
    FName=$4
    ssh $rootusr@$redisSrvIP "${remote_dir}/mqttAuth.sh $SNum $ENum $IDPre $FName"
   fi
}

#订阅相同主题
subFixNoAcc(){
   echoFlag=false
   if $capFlag;then
         cap "subFix"
   fi
   #relog收到消息保存到日志
   relog=${sPath}/${subFixRecieved}	
   #nulog命令下发数量计数日志
   nulog=${sPath}/${subFixFName}	
   : > $relog	
   : > $nulog	
   j=0
   for i in `seq $subFixSNum $subFixENum`
   do
      subID="$subFixIDPre$i"
      if $mqttAuth;then
        sub $subFixTopic $subID $defaultUsr $defaultPasswd $j $relog	
      else
        sub $subFixTopic $subID $j $relog	
      fi
      j=`expr $j + 1`
      if [ $j -ge 3 ]; then
          j=0
      fi
      echo `expr $i - $subFixSNum + 1` > $nulog	
   done
}

#创建账户并订阅相同主题
subFix(){
 createAccount $subFixIDPre $subFixSNum $subFixENum "${intf}-${cIP}-subFix"  
 subFixNoAcc 
}

#订阅不同主题
#mosquitto_sub
subLoopNoAcc(){
	if $capFlag;then
	 cap "subLoop"
	fi
          
	j=0
	nulog=${sPath}/${subFName}
	: > $nulog
        #create mqtt usr passwd
	#ssh $rootusr@$srv_ip "${remote_dir}/mqttAuth.sh $sSubNum $eSubNum $subIDPre ${intf}-${cIP}-sub"
	for i in `seq $sSubNum $eSubNum`
	do	
	 subTopic="${subTopicPre}${i}"
	 subID="${subIDPre}${i}"
                if $mqttAuth;then
		   		sub $subTopic $subID $defaultUsr $defaultPasswd $j
  		else
				sub $subTopic $subID $j
  		fi
		j=`expr $j + 1`
                if [ $j -ge 3 ]; then
                         j=0
                fi
	        #echo `date +"%Y-%m-%d %H:%M:%S"`>${sPath}/${subFName}
	       	echo `expr $i - $sSubNum + 1` > $nulog	
	done
	#monitorLog subresult&
	$sPath/logger.sh monitorlog&
}

#创建用户并订阅不同主题
subLoop(){
 createAccount $subIDPre $sSubNum $eSubNum "${intf}-${cIP}-sub"  
 subLoopNoAcc
}

subSiNoAcc(){
  if $capFlag;then cap "subSica";fi
  #relog收到消息保存到日志
  relog=${sPath}/${subSiRecieved}
  nulog=${sPath}/${subSiFName}
  : > $nulog
  : > $relog
  auType="siCa"
  for i in `seq $subSiSNum $subSiENum`
  do
      subSiTopic="${subSiTopicPre}${i}"
      subSiID="${subSiIDPre}${i}"
      sub $subSiTopic $subSiID $defaultUsr $defaultPasswd $qos $relog $auType 
  done
  echo `expr $i - $subSiSNum + 1` > $nulog	
}

subSiLoop(){
  createAccount $subSiIDPre $subSiSNum $subSiENum "${intf}-${cIP}-subSi" 
  subSiNoAcc 
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
       relog=$6
      if [ -z "$7" ];then
        Ccount=$subCcount
      else
        Ccount=$7
      fi

      if $echoFlag;then
            echo client  \'$subid\' sub topic \'$subtopic\' usrname \'$usr\' passwd \'$passwd\' qos \'$subqos\'
      fi
      
      if [ "$mqttAuth" = "singleCa" ];then
         if [ -z "$relog" ];then
		mosquitto_sub -t $subtopic -h $srv_ip -p $srv_port -i $subid -k $keepLive -u $usr  -P $passwd --cafile $carPath -C $Ccount&
 	 else
		mosquitto_sub -t $subtopic -h $srv_ip -p $srv_port -i $subid -k $keepLive -u $usr  -P $passwd --cafile $carPath -C $Ccount >> $relog&
	 fi
      elif [ "$mqttAuth" = "biCa" ];then
         if [ -z "$relog" ];then
		mosquitto_sub -t $subtopic -h $srv_ip -p $srv_port -i $subid -k $keepLive -u $usr  -P $passwd --cafile $carPath --cert $crtPath --key $keyPath -C $Ccount&
	else
		mosquitto_sub -t $subtopic -h $srv_ip -p $srv_port -i $subid -k $keepLive -u $usr  -P $passwd --cafile $carPath --cert $crtPath --key $keyPath -C $Ccount >> $relog&
	fi
      else
         if [ -z "$relog" ];then
         	mosquitto_sub -t $subtopic -h $srv_ip -p $srv_port -q $subqos -i $subid -k $keepLive -u $usr -P $passwd -C $Ccount&
	 else
               #保存收到的消息
         	mosquitto_sub -t $subtopic -h $srv_ip -p $srv_port -q $subqos -i $subid -k $keepLive -u $usr -P $passwd -C $Ccount >> $relog&
         fi
      fi
} 

#一次性订阅同一主题的消息
subCLoopNoAcc(){
        echoFlag=false

        j=0
        relog=${sPath}/${subCRecieved}
        nulog=${sPath}/${subCFName}
        : > $relog
        for i in `seq $subCsNum $subCeNum`
        do
                subID="$subCIDPre$i"
                subC $subCTopic $subID $defaultUsr $defaultPasswd $j $relog
                j=`expr $j + 1`
                if [ $j -ge 3 ]; then
                       j=0
                fi
                : > $nulog
                echo `expr $i - $subCsNum + 1` >> $nulog
        done

}

subCLoop(){
   createAccount $subCIDPre $subCsNum $subCeNum "${intf}-${cIP}-subCLoop"  
   subCLoopNoAcc
}

#一次性订阅同一主题的消息用于长期测试
subCReLoopNoAcc(){
        echoFlag=false
        #if $capFlag;then
         # cap "subCReContinue"
        #fi

        j=0
        relog=$sPath/$subCReRecieved
        nulog=${sPath}/${subCReFName}
        : > $relog
        for i in `seq $subCResNum $subCReeNum`
        do
                subID="$subCReIDPre$i"
                subC $subCReTopic $subID $defaultUsr $defaultPasswd $j $relog
                j=`expr $j + 1`
                if [ $j -ge 3 ]; then
                       j=0
                fi
                :>$nulog
                echo `expr $i - $subCResNum + 1` >> $nulog
        done

}

subCReLoop(){
   createAccount $subCReIDPre $subCResNum $subCReeNum "${intf}-${cIP}-subCReLoop"  
   subCReLoopNoAcc
}

#订阅不同主题的保留消息 
subCRNoAcc(){
        echoFlag=false
        j=0
        relog=${sPath}/${subCPubRRecieved}
        nulog=${sPath}/${subRFName}
        : > $relog
        for i in `seq $pubRsNum $pubReNum`
        do
                subRID="$subRIDPre$i"
                subCRTopic="$pubRTopicPre$i"
                subC $subCRTopic $subRID $defaultUsr $defaultPasswd $j $relog
                j=`expr $j + 1`
                if [ $j -ge 3 ]; then
                       j=0
                fi
                : > $nulog
                echo `expr $i - $pubRsNum + 1` >> $nulog
        done

}
#订阅的主题，起始和结束序列与pubRLoop()保持一致
subCRLoop(){
   createAccount $subRIDPre $pubRsNum $pubReNum "${intf}-${cIP}-subCRLoop"  
   subCRNoAcc
}
#mqtt pub
pub(){
        pubtopic=$1
        pubmsg=$2
	pubid=$3
        pubqos=$4
        usr=$5
	passwd=$6
        if [ "$mqttAuth" = "pw" ] ;then
                 if [ -z "$3" ] || [ -z "$4" ] ;then
              		echo "ERROR:Please input the mosquitto client usrname and password!"
	         fi
		 mosquitto_pub -t $pubtopic -m $pubmsg -h $srv_ip -p $srv_port -i $pubid -q $pubqos -u $usr -P $passwd&
        elif [ "$mqttAuth" = "singleCa" ] ;then
		 mosquitto_pub -t $pubtopic -m $pubmsg -h $srv_ip -p $srv_port -i $pubid -q $pubqos -u $usr -P $passwd --carfile $carPath&
        elif [ "$mqttAuth" = "biCa" ] ;then
		 mosquitto_pub -t $pubtopic -m $pubmsg -h $srv_ip -p $srv_port -i $pubid -q $pubqos -u $usr -P $passwd --carfile $carPath&
        else
		if [ -n "$4" ];then
        		pubqos=$4
			mosquitto_pub -t $pubtopic -m $pubmsg -h $srv_ip -p $srv_port -i $pubid  -q $pubqos&
		else
			mosquitto_pub -t $pubtopic -m $pubmsg -h $srv_ip -p $srv_port -i $pubid&
		fi
	fi
}

#发布单条固定主题消息
pubCNoAcc(){
     pub $subCTopic $pubCMsg $pubCID $pubQos $defaultUsr $defaultPasswd
}

#pub msg
pubC(){
   #ssh $rootusr@$srv_ip "${remote_dir}/mqttAuth.sh 0 0 $pubCID ${intf}-${cIP}-pubC"
   #pub $subCTopic $pubCMsg $pubCID $pubQos $defaultUsr $defaultPasswd
   createAccount $pubCID 0 0 "${intf}-${cIP}-pubC"  
   pubCNoAcc
}

#发布单条固定主题消息
pubCReNoAcc(){
     pub $subCReTopic $pubCReMsg $pubCReID $pubQos $defaultUsr $defaultPasswd
}

#pub msg
pubCRe(){
   createAccount $pubCReID 0 0 "${intf}-${cIP}-pubCRe"  
   pubCReNoAcc
}

#大量发布
pubLoopNoAcc(){
        #cp local mqtt.conf to remote client
	#ssh $rootusr@$srv_ip "${remote_dir}/mqttAuth.sh $sPubNum $ePubNum $pubIDPre ${intf}-${cIP}-pub"
	for i in `seq $sPubNum $ePubNum`
	do
		pubTopic="$pubTopicPre$i"
		pubMsg="$pubMsgPre$i"
		pubID="$pubIDPre$i"
  		if $mqttAuth;then
			pub $pubTopic $pubMsg $pubID $pubQos $defaultUsr $defaultPasswd
        	else
			pub $pubTopic $pubID $pubMsg $pubQos
        	fi	
	done
}

pubLoop(){
  createAccount $pubIDPre $sPubNum $ePubNum "${intf}-${cIP}-pub"  
  pubLoopNoAcc
}

pubFixNoAcc(){
	for i in `seq $pubFixSNum $pubFixENum`
	do
		 pubMsg="$pubMsgPre$i"
		 pubID="$pubIDPre$i"
  		if $mqttAuth;then
			pub $subFixTopic $pubMsg $pubID $pubQos $defaultUsr $defaultPasswd
        	else
			pub $subFixTopic $pubID $pubMsg $pubQos
        	fi	
	done
}

pubFix(){
  createAccount $pubIDPre $pubFixSNum $pubFixENum "${intf}-${cIP}-pubFix"  
  pubFixNoAcc
}

#stopScipt
stopScript(){
          if [ -z "$1" ];then
	        scriptName=`basename $0`
	  else
                scriptName=$1
          fi
	  bash_pids=`ps -ef |grep ${scriptName}|grep "\/bin\/bash"|awk -F " " '{print $2}'`
	  ssh_pids=`ps -ef |grep ${scriptName}|grep "ssh"|awk -F " " '{print $2}'`
          pids="${bash_pids} ${ssh_pids}"
	  OLD_IFS="$IFS"
	  IFS=" "
	  arr=($pids)
	  IFS="$OLD_IFS"
	  for pid in ${arr[@]};
	  do
	    kill -9 $pid
	  done
}

##
stopSpecScript(){
 stopScript "logger.sh"
 stopScript "mqttClient.sh"
}

#stop sub
stopSub(){
	  pkill -9 mosquitto_sub
	  pkill -9 mosquitto_sub
 	  pkill -9 tcpdump
}

#先订阅后发布，主题保持不变
subPubNoAcc(){
	echoFlag=false
	#if $capFlag;then
	# cap "subPub"
	#fi
 
	j=0
	relog=$sPath/${subPubRecieved}
	: > $relog
	#ssh $rootusr@$srv_ip "${remote_dir}/mqttAuth.sh $pubSubSNum $pubSubENum $subIDPre ${intf}-${cIP}-pubsub"
	for i in `seq $pubSubSNum $pubSubENum`
	do	
			subID="$subIDPre$i"
			if $mqttAuth;then
			  sub $subPubTopic $subID $defaultUsr $defaultPasswd $j $relog
			else
			  sub $subPubTopic $sid $j $relog
			fi
			j=`expr $j + 1`
                        if [ $j -ge 3 ]; then
                               j=0
                        fi
	done
	        
	sleep $subPubGap 
        	
	#发布消息的序列可以与订阅的序列不一样
	#ssh $rootusr@$srv_ip "${remote_dir}/mqttAuth.sh $subPubSNum $subPubENum $pubIDPre ${intf}-${cIP}-subpub"
	for i in `seq $subPubSNum $subPubENum`
	do
			pubID="$pubIDPre$i"
			pubMsg="$pubMsgPre$i"
			if $mqttAuth;then
			  pub $subPubTopic $pubMsg $pubID $pubQos $defaultUsr $defaultPasswd
 			else
		          pub $subPubTopic $msg $pid $pubQos
			fi
       done
}

subPub(){
  createAccount $subIDPre $pubSubSNum $pubSubENum "${intf}-${cIP}-pubsub"  
  createAccount $pubIDPre $subPubSNum $subPubENum "${intf}-${cIP}-subpub"  
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

#plenty of mqtt pub retain msg
pubRLoopNoAcc(){
     # ssh $rootusr@$srv_ip "${remote_dir}/mqttAuth.sh $pubRsNum $pubReNum $pubRIDPre ${intf}-${cIP}-pubR"
      nulog=$sPath/$pubRFName
      for i in `seq $pubRsNum $pubReNum`
      do
    	pubRTopic="${pubRTopicPre}${i}"
	pubRMsg="${pubRMsgPre}${i}"
	pubRID="${pubRIDPre}${i}"
  	if $mqttAuth;then
	     pubR $pubRTopic $pubRMsg $pubRID $defaultUsr $defaultPasswd 
	else
	     pubR $pubRTopic $pubRMsg $pubRID 
	fi
	: > $nulog
        echo `expr $i - $pubRsNum + 1` >> $nulog
     done
}

pubRLoop(){
  createAccount $pubRIDPre $pubRsNum $pubReNum "${intf}-${cIP}-pubR"  
  pubRLoopNoAcc
}  

#mosquitto_sub retain msg
subRLoopNoAcc(){
	echoFlag=false
	#if $capFlag;then
	# cap "subRLoop"
	#fi

        relog=${subPubRRecieved}
        : > $relog
	j=0
	#ssh $rootusr@$srv_ip "${remote_dir}/mqttAuth.sh $pubRsNum $pubReNum $subRIDPre ${intf}-${cIP}-subR"
	for i in `seq $pubRsNum $pubReNum`
	do	
                pubRTopic="$pubRTopicPre${i}"
		subRID="$subRIDPre$i"
		if $mqttAuth;then
  		   sub $pubRTopic $subRID $defaultUsr $defaultPasswd $j $relog
		else
  		   sub $pubRTopic $subRID $j $relog
		fi
		   j=`expr $j + 1`
		   if [ $j -ge 3 ]; then
			j=0
		   fi
       done
       $sPath/logger.sh monitorlog&
}

subRLoop(){
  createAccount $subRIDPre $pubRsNum $pubReNum "${intf}-${cIP}-subR"  
  subRLoopNoAcc
}

#pub retain message,then sub them
subPubRNoAcc(){
  echoFlag=false
  relog=${subPubRRecieved}
  : > $relog
  j=0
 
  #if $capFlag;then
   # cap "subPubR"
  #fi
  
  #ssh $rootusr@$srv_ip "${remote_dir}/mqttAuth.sh $pubRsNum $pubReNum $pubRIDPre ${intf}-${cIP}-subpubR"
  for i in `seq $pubRsNum $pubReNum`
  do
	    pubRTopic="${pubRTopicPre}${i}"
	    pubRMsg="${pubRMsgPre}${i}"
	    pubRID="${pubRIDPre}${i}"
            if $mqttAuth;then 
	     pubR $pubRTopic $pubRMsg $pubRID $defaultUsr $defaultPasswd
            else
             pubR $pubRTopic $pubRMsg $pubRID 
           fi 
  done
  sleep $retainGap 
  #ssh $rootusr@$srv_ip "${remote_dir}/mqttAuth.sh $pubRsNum $pubReNum $subRIDPre ${intf}-${cIP}-pubsubR"
  for i in `seq $pubRsNum $pubReNum`
  do	
            pubRTopic="${pubRTopicPre}${i}"
            subRID="${subRIDPre}${i}"
            if $mqttAuth;then 
	        sub $pubRTopic $subRID $defaultUsr $defaultPasswd $j $relog
	    else
  		sub $pubRTopic $subRID $j $relog
	    fi
	    j=`expr $j + 1`
	    if [ $j -ge 3 ]; then
	      	j=0
	    fi
  done
  $sPath/logger.sh monitorlog&
}

subPubR(){
  createAccount $pubRIDPre $pubRsNum $pubReNum "${intf}-${cIP}-subpubR"  
  createAccount $subRIDPre $pubRsNum $pubReNum "${intf}-${cIP}-pubsubR"  
  subPubRNoAcc
}

#stop plenty of mqtt pub retain msg
stopPubR(){
 for i in `seq $pubRsNum $pubReNum`
 do
     pubRTopic="${pubRTopicPre}${i}"
     pubRID="${pubRIDPre}${i}"
     if $mqttAuth;then
        mosquitto_pub -t $pubRTopic -n -h $srv_ip -p $srv_port -i $pubRID -r -u $defaultUsr -P $defaultPasswd&
     else
        mosquitto_pub -t $pubRTopic -n -h $srv_ip -p $srv_port -i $pubRID -r&
     fi
 done
}

stopSubPubR(){
 stopSub
 stopPubR
}

case $1 in
   "subloop")
     subLoop
     ;;
   "publoop")
     pubLoop
     ;;
   "stopsub")
     stopSub
     ;;
   "stopspecscript")
     stopSpecScript
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
   "stopsubpubr")
     stopSubPubR
     ;;
   "subpubr")
     subPubR
     ;;
   "subcloop")
     subCLoop
     ;;
   "subcloopnoacc")
     subCLoopNoAcc
     ;;
   "subcreloop")
     subCReLoop
     ;;
   "subcreloopnoacc")
     subCReLoopNoAcc
     ;;
   "subcrloop")
     subCRLoop
     ;;
   "subfix")
     subFix
     ;;
   "pubfix")
     pubFix
     ;;
   "pubc")
     pubC
     ;;
   "subsiloop")
     subSiLoop
     ;;
   *)
     #echo "mqttClient.sh"
     ;;
esac
