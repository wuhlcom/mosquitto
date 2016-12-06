#!/bin/bash 
# send ssh cmd to run script of remote client  
#注意文件加载的顺序
sPath=`dirname $0`
source $sPath/mqttClient.sh
source $sPath/logger.sh

rootusr="root" 
remote_dir="/home/zhilu/mosquitto/bash_mqtt"
remote_mqttClient=$remote_dir/mqttClient.sh
remote_query=$remote_dir/logger.sh

subCMD=mqttsub  
subRsCMD=subresult
subStopCMD=stopsub
subPubCMD=subpub
RetainCMD=subpubretain
stopRetainCMD=stopsubretain
sshPort=22
subRs="0 0"
#每台客户机命令发下成功后等待间隔
waitForSession=5

localPcFlag=true
#localPcFlag=false
localIntf=eth0
localPcIP=`ip a|grep "inet\s*192.168.10.*$localIntf"|awk -F " " '{print $2}'|sed 's/\/24//g'`
local_query=$sPath/logger.sh

#记录进程和会话结果
subLog(){ 
  logPath=$sPath/subLogs/
  ipaddr=$1
  proNum=$2
  sesNum=$3 
  #不能有空格，有空格会当成多个变量的值
  total="Client_$ipaddr:预期mosquitto_sub数为${subNum}个，实际进程数${proNum}个，会话数${sesNum}"
  proRs=""
  sesRs=""

  if [ "$proNum" -lt "$subNum" ];then
    proRs="Client_$ipaddr:实际上有${proNum}个mosquitto_sub进程,少于预期的${subNum}个,相差`expr $subNum - $proNum`个"
  fi
   
  if [ "$proNum" -gt "$subNum" ];then
    proRs="Client_$ipaddr:实际上有${proNum}个mosquitto_sub进程,多于预期的${subNum}个,相差`expr $proNum - $subNum`个,有重复的client"
  fi

  if [ "$sesNum" -lt "$subNum" ];then
    sesRs="Client_$ipaddr:实际上有${sesNum}个mosquitto_sub会话,少于预期的${subNum}个,相差`expr $subNum - $sesNum`个"
  fi

  if [ "$sesNum" -gt "$subNum" ];then
    proRs="Client_$ipaddr:实际上有${sesNum}个mosquitto_sub会话,多于预期的${subNum}个,相差`expr $sesNum - $subNum`个,有重复的client"
  fi

  write_log $total
  write_log $proRs 
  write_log $sesRs
}

#local pc sub
localSub(){ 
  $sPath/mqttClient.sh ${subCMD}
  sleep $waitForSession
}

#查询本地订阅结果
localQuery(){
  i=0
   while true
   do
     subLoop=`cat "${sPath}/${subFName}"`
     mqttSubNum=`echo $subLoop|awk -F " " '{print $3}'`
     #订阅完成则查询订阅结果
     if [ "$mqttSubNum" = "$subNum" ];then
       subRs=$(${local_query} ${subRsCMD})
       break
     fi
     ((i++))
     #订阅超时后也要订阅结果
     if [ "$i" = "$querySubCount" ];then
        subRs=$(${local_query} ${subRsCMD})
	break
     fi
     sleep $querySubGap
  done
  proNum=`echo $subRs|awk -F " " '{print $1}'`
  sesNum=`echo $subRs|awk -F " " '{print $2}'`
  subLog $localPcIP $proNum $sesNum
}
#本地订阅并记录结果
localSQ(){
 localSub
 localQuery
}

#本地下达指令让远程机器进行订阅
remoteSub(){ 
	step=1
	for ip in ${ip_array[*]}  
	do 
	    #if IP is same as local ip,continue
	    if [ "$ip" = "$localPcIP" ];then continue;fi
	    #cp local mqtt.conf to remote client
	    #scp ${sPath}/mqtt.conf root@${ip}:${remote_dir} 
	    #修改配置文件中的值,保证每台机器上的mosquitto_sub的id是唯一的 
	    newStart=`expr $sSubNum + $subNum \* $step`
	    ssh -p $sshPort $rootusr@$ip "sed -i 's/sSubNum=${sSubNum}/sSubNum=${newStart}/g' ${remote_dir}/mqtt.conf"
	    # ssh -t -p $sshPort $user@$ip "$remote_mqttClient"&
	    ssh -p $sshPort $rootusr@$ip "${remote_mqttClient} ${subCMD}"&
	    sleep $waitForSession 
           ((step++))
	done  
}

#本地下达指令查询远程订阅结果
remoteQuery(){
 i=0
 for ip in ${ip_array[*]}
  do
    #排除本地IP
    if [ "$ip" = "$localPcIP" ];then continue;fi
    while true
    do
       subLoop=`ssh -p $sshPort $rootusr@$ip "cat ${remote_dir}/${subFName}"`
       mqttSubNum=`echo $subLoop|awk -F " " '{print $3}'`
       #订阅完成则查询订阅结果
       if [ "$mqttSubNum" = "$subNum" ];then
          subRs=$(ssh -p $sshPort $rootusr@$ip "${remote_query} ${subRsCMD}")
         break
      fi
      ((i++))
      #订阅超时后也要订阅结果
      if [ "$i" = 10 ];then
        subRs=$(ssh -p $sshPort $rootusr@$ip "${remote_query} ${subRsCMD}")
	break
      fi
      sleep 5
   done
   proNum=`echo $subRs|awk -F " " '{print $1}'`
   sesNum=`echo $subRs|awk -F " " '{print $2}'`
   subLog $ip $proNum $sesNum
 done
}

#远程订阅并记录结果
remoteSQ(){
  remoteSub
  sleep $waitForSession 
  remoteQuery
}

#停止远程订阅
stopRemoteSub(){
	for ip in ${ip_array[*]}  
	do 
	    #if IP is same as local ip,continue
	    if [ "$ip" = "$localPcIP" ];then continue;fi
 	    #必须加&
	    ssh -p $sshPort $rootusr@$ip "${remote_mqttClient} ${subStopCMD}"&
	done  
}

#记录进程和会话结果
subPubLog(){
  message=$1 
  if [ -z $2 ];then
  	logPath=$sPath/subPubLogs/
  else
	logPath=$2
  fi
  write_log $message
}

#local pc sub pub
mqttSubPubLocal(){
    $sPath/mqttClient.sh ${subPubCMD}
    sleep $waitForSession
    session_num=0
    query_num=1

    while true
    do
       	session_num=`cat ${sPath}/${subPubFName}|wc -l`
       	if [ "$session_num" = "$sub_pub_num" ];then
            localRs="执行PC${localPcIP}预期订阅/发布总数为$sub_pub_num,实际数量为$session_num"
            subPubLog $localRs
    	    break 
	fi

	((query_num++))
        if [ "$query_num" = "$querySubCount"  ];then
	 	break
	fi
       	sleep $querySubGap
   done

   if [ "$sub_pub_num" -ne "$session_num" ];then
      value=`expr $sub_pub_num - $session_num`
      localRs="执行PC${localPcIP}预期订阅/发布总数为$sub_pub_num,实际数量为$session_num,相差${value}"
      subPubLog $localRs
   fi
}

#remote pc sub pub
mqttSubPubRemote(){
	sum=0
	step=1

	for ip in ${ip_array[*]}  
	do
	    num=0
            queryNum=1
	    #scp ${sPath}/mqtt.conf $rootusr@${ip}:${remote_dir} 
	    #修改配置文件中的值,保证每台机器上的mosquitto_sub的id和pub id是唯一的 
	    pubSubNewStart=`expr $pubSubSNum + $pubSubNum \* $step`
	    subPubNewStart=`expr $subPubSNum + $subPubNum \* $step`
	    ssh -p $sshPort $rootusr@$ip "sed -i 's/pubSubSNum=${pubSubSNum}/pubSubSNum=${pubSubNewStart}/g' ${remote_dir}/mqtt.conf"
	    ssh -p $sshPort $rootusr@$ip "sed -i 's/subPubSNum=${subPubSNum}/subPubSNum=${subPubNewStart}/g' ${remote_dir}/mqtt.conf"
	    #if IP is same as local ip,continue
	    if [ "$ip" = "$localPcIP" ];then continue;fi
            #必须加&
	    ssh -p $sshPort $rootusr@$ip "${remote_mqttClient} ${subPubCMD}"&
  	    sleep $waitForSession 
  	    while true
	    do
           	num=`ssh -p $sshPort $rootusr@$ip "cat ${remote_dir}/${subPubFName}|wc -l"`
            	if [ "$num" = "$sub_pub_num" ];then
		        pcRs="远程PC${ip}预期订阅/发布数为$sub_pub_num,实际数量为$num"
			subPubLog $pcRs
    		        break 
		fi

		((queryNum++))
                if [ "$queryNum" = "$querySubCount"  ];then
		 	break
		fi
              	sleep $querySubGap
	    done

	    if [ "$sub_pub_num" -ne "$num" ];then
            	diffvalue=`expr $sub_pub_num - $num`
	    	pcRs="远程PC${ip}预期订阅/发布数为$sub_pub_num,实际数量为$num,相差${diffvalue}"
		subPubLog $pcRs
	    fi

	    #统计所有pc的会话数
	    sum=`expr $sum + $num`
	    ((step++))
            sleep $clientGap 
	done
 
        len=${#ip_array[@]} 
        #多个客户端预期订阅/发布总数
        expectNum=`expr $len \* $sub_pub_num`

        if [ "$sum" = "$expectNum" ];then
	        rs="远程预期订阅/发布总数为$expectNum,实际数量为$sum"       
	else 
        	value=`expr $expectNum - $sum`
	        rs="远程预期订阅/发布总数为$expectNum,实际数量为$sum,相差${value}"        
	fi
	subPubLog $rs
}

#local pub retain,then sub them
retainLocal(){
        logdir=$sPath/pubRetainLogs/
	num=0
        queryNum=1
	subPubRetain
  	sleep $waitForSession 
  	while true
	    do
           	num=`cat ${sPath}/${subPubRFName}|wc -l`
	        if [ "$pubRetainNum" =  "$num" ];then
		        pcRs="执行PC${localPcIP}预期订阅到保留消息数为$pubRetainNum,实际数量为$num"
			subPubLog $pcRs $logdir
    		        break 
		fi

		((queryNum++))
                if [ "$queryNum" = "$querySubCount"  ];then
		 	break
		fi
              	sleep $querySubGap
	    done

      if [ "$pubRetainNum" -ne "$num" ];then
         diffvalue=`expr $pubRetainNum - $num`
         pcRs="执行PC${localPcIP}预期订阅到保留消息数为$pubRetainNum,实际数量为$num,相差${diffvalue}"
	 subPubLog $pcRs $logdir
      fi

}

#remote pub retain,then sub them
retainRemote(){
	sum=0
	step=1
        logdir=$sPath/pubRetainLogs/
	for ip in ${ip_array[*]}  
	do
	    num=0
            queryNum=1
	    #scp ${sPath}/mqtt.conf $rootusr@${ip}:${remote_dir} 
	    #修改配置文件中的值,保证每台机器上的mosquitto_sub的id和pub id是唯一的 
	    RetainNewStart=`expr $pubRsNum + $pubRetainNum \* $step`
	    ssh -p $sshPort $rootusr@$ip "sed -i 's/pubRsNum=${pubRsNum}/pubRsNum=${RetainNewStart}/g' ${remote_dir}/mqtt.conf"
	    #if IP is same as local ip,continue
	    if [ "$ip" = "$localPcIP" ];then continue;fi
	    ssh -p $sshPort $rootusr@$ip "${remote_mqttClient} ${RetainCMD}"&
            
            #订阅保留时消息时会较大的延时，生成结果日志会较慢必须增加延时
            sleep $retainReportGap
  	    while true
	    do
           	num=`ssh -p $sshPort $rootusr@$ip "cat ${remote_dir}/${subPubRFName}|wc -l"`
            	if [ "$num" = "$pubRetainNum" ];then
		        pcRs="远程PC${ip}预期订阅到保留消息数为$pubRetainNum,实际数量为$num"
			subPubLog $pcRs $logdir
    		        break 
		fi

		((queryNum++))
                if [ "$queryNum" = "$querySubCount"  ];then
		 	break
		fi
              	sleep $querySubGap
	    done

	    if [ "$pubRetainNum" -ne "$num" ];then
            	diffvalue=`expr $pubRetainNum - $num`
		pcRs="远程PC${ip}预期订阅到保留消息数为$pubRetainNum,实际数量为$num,相差${diffvalue}"
		subPubLog $pcRs $logdir
	    fi

	    #统计所有pc的会话数
	    sum=`expr $sum + $num`
	    ((step++))
            sleep $clientGap 
	done
 
        len=${#ip_array[@]} 
        #多个客户端预期订阅/发布总数
        expectNum=`expr $len \* $pubRetainNum`

        if [ "$sum" = "$expectNum" ];then
	        rs="远程预期订阅保留消息总数为$expectNum,实际数量为$sum"       
	else 
        	value=`expr $expectNum - $sum`
	        rs="远程预期订阅保留消息总数为$expectNum,实际数量为$sum,相差${value}"        
	fi
	subPubLog $rs $logdir
}

#停止远程订阅保留消息
stopRetainRemote(){
	for ip in ${ip_array[*]}  
	do
	    ssh -p $sshPort $rootusr@$ip "${remote_mqttClient} ${stopRetainCMD}"
	done
}
