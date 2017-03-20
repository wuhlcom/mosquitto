#!/bin/bash 
#auth:wuhongliang
#date:2016-12-11
#desc:
# send ssh cmd to run script of remote client  
#注意文件加载的顺序
sPath=`dirname $0`
source $sPath/mqttClient.sh
source $sPath/logger.sh
logsPath=$sPath/logs
remote_mqttClient=$remote_dir/mqttClient.sh
remote_query=$remote_dir/logger.sh

subCMD=subloop  
subCRCMD=subcrloop  
subFixCMD=subfix  
pubFixCMD=pubfix
subRsCMD=subresult
subStopCMD=stopsub
subStopScriptCMD=stopspecscript
subPubCMD=subpub
subCCMD=subcloop
subCNoAccCMD=subcloopnoacc
subCReCMD=subcreloop
subCReNoAccCMD=subcreloopnoacc
retainCMD=subpubr
pubRCMD=pubrloop
subCaAuthCMD=subcaauth
stopRetainCMD=stopsubpubr
subCCaCMD=subcca
subCCaNoAccCMD=subccanoacc
pubCCaCMD=pubcca
pubCCaNoAccCMD=pubccanoacc
pubCaConAccCMD=pubcaconacc
pubCaConNoAccCMD=pubcaconnoacc
subCaConCMD=subcacon
subCaMuCMD=subcamu
pubCaMuAccCMD=pubcamuacc
pubCaMuNoAccCMD=pubcamunoacc
sshPort=22
subRs="0 0"
#每台客户机命令发下成功后等待间隔
waitForSession=5
puballwaittime=30

local_query=$sPath/logger.sh

#记录进程和会话结果
reportLog(){
  logPath=$1
  if [ "$#" = 2 ];then
    message=$2
    writeLog $message
  else 
        ipaddr=$2
        proNum=$3
        sesNum=$4
        expect=$5
        if [ "-z" $6 ];then
            client_type=mosquitto_sub 
	else
            client_type=$6 
	fi
        if [ -z "$proNum" ];then 
		proNum=0
		nulmsg="prosess num is null"
		writeLog $nulmsg
	fi
        
	if [ -z "$sesNum" ];then 
		sesNum=0
		nulmsg="session num is null"
		writeLog $nulmsg
	fi
	#不能有空格，有空格会当成多个变量的值
	total="Client_$ipaddr:预期${client_type}数为${expect}个，实际进程数${proNum}个，会话数${sesNum}"
	proRs=""
	sesRs=""
	if [ "$proNum" -lt "$expect" ];then
	    proRs="Client_$ipaddr:实际上有${proNum}个${client_type}进程,少于预期的${expect}个,相差`expr $expect - $proNum`个"
	fi
   
	if [ "$proNum" -gt "$expect" ];then
	    proRs="Client_$ipaddr:实际上有${proNum}个${client_type}进程,多于预期的${expect}个,相差`expr $proNum - $expect`个,有重复的client"
	fi

	if [ "$sesNum" -lt "$expect" ];then
	    sesRs="Client_$ipaddr:实际上有${sesNum}个${client_type}会话,少于预期的${expect}个,相差`expr $expect - $sesNum`个"
	fi

	if [ "$sesNum" -gt "$expect" ];then
	   proRs="Client_$ipaddr:实际上有${sesNum}个${client_type}会话,多于预期的${expect}个,相差`expr $sesNum - $expect`个,有重复的client"
	fi

	writeLog $total
	writeLog $proRs 
	writeLog $sesRs
 fi
}

#local pc sub
subLocal(){ 
  $sPath/mqttClient.sh ${subCMD}
}

#查询本地订阅结果
queryLocal(){
   reportPath=$1
   fileName=$2
   exprNum=$3

   if [ -z "$4" ];then 
	local srvIP=$srv_ip;
   else
	local srvIP=$4
   fi

   if [ -z "$5" ];then
	 local srvPort=$srv_port;
   else
	 local srvPort=$5
   fi

   proNum1=0
   sesNum1=0
   sleep $querySubGap
   i=0
   while true
   do
     subRsNum=`cat "${sPath}/${fileName}"`
     #订阅完成则查询订阅结果
     if [ "$subRsNum" = "$exprNum" ];then
       subRs=$(${local_query} ${subRsCMD} $srvIP $srvPort)
       break
     fi
     ((i++))
     #订阅超时后也要查询订阅结果
     if [ "$i" = "$querySubCount" ];then
        subRs=$(${local_query} ${subRsCMD} $srvIP $srvPort)
	break
     fi
     sleep $querySubGap
  done
  countMsg="-----${localPcIP}下发订阅数为${subRsNum}-----"
  reportLog $reportPath $countMsg 
  proNum1=`echo $subRs|awk -F " " '{print $1}'`
  sesNum1=`echo $subRs|awk -F " " '{print $2}'`
  reportLog $reportPath $localPcIP $proNum1 $sesNum1 $exprNum
}

#本地订阅并记录结果
subQuLocal(){
 subLogPath=$sPath/subAllSessionLogs
 subLocal
 sleep $subWait
 queryLocal $subLogPath $subFName $subNum
}

#本地下达指令让远程机器进行订阅
subRemote(){ 
	step=1
	for ip in ${ip_array[*]}  
	do 
	    scp ${sPath}/mqtt.conf $rootusr@${ip}:${remote_dir} 
	    if [ "$ip" = "$localPcIP" ];then continue;fi
	    #修改配置文件中的值,保证每台机器上的mosquitto_sub的id是唯一的 
	    newStart=`expr $sSubNum + $subNum \* $step`
	    ssh -p $sshPort $rootusr@$ip "sed -i 's/sSubNum=${sSubNum}/sSubNum=${newStart}/g' ${remote_dir}/mqtt.conf"
	    # ssh -t -p $sshPort $user@$ip "$remote_mqttClient"&
	    ssh -p $sshPort $rootusr@$ip "${remote_mqttClient} ${subCMD}"&
           ((step++))
	done  
}

#本地下达指令查询远程订阅结果
queryRemote(){
 reportPath=$1
 fileName=$2
 exprNum=$3
   if [ -z "$4" ];then 
	local srvIP=$srv_ip;
   else
	local srvIP=$4
   fi

   if [ -z "$5" ];then
	 local srvPort=$srv_port;
   else
	 local srvPort=$5
   fi
 i=0
 expectNum=0
 sumPro1=0
 sumSes1=0
 #reportPath=$sPath/subLogs/
 len=${#ip_array[@]}
 if [ "$len" = 0 ];then return;fi
 sleep $querySubGap
 for ip in ${ip_array[*]}
  do
    #排除本地IP
    if [ "$ip" = "$localPcIP" ];then continue;fi
    while true
    do
      subRsNum=`ssh -p $sshPort $rootusr@$ip "cat ${remote_dir}/${fileName}"`
      #pcSubNum=`echo $subResult|awk -F " " '{print $3}'`
      #订阅完成则查询订阅结果
      if [ "$subRsNum" = "$exprNum" ];then
         subRs=$(ssh -p $sshPort $rootusr@$ip "${remote_query} ${subRsCMD} ${srvIP} ${srvPort}")
         break
      fi
      ((i++))
      #订阅超时后也要订阅结果
      if [ "$i" = "$querySubCount" ];then
        subRs=$(ssh -p $sshPort $rootusr@$ip "${remote_query} ${subRsCMD} ${srvIP} $srvPort")
	break
      fi
      sleep $querySubGap
   done
   countMsg="-----${ip}下发订阅数为${subRsNum}-----"
   reportLog $reportPath $countMsg 
   proNum=`echo $subRs|awk -F " " '{print $1}'`
   sesNum=`echo $subRs|awk -F " " '{print $2}'`
   reportLog $reportPath $ip $proNum $sesNum $exprNum
   sumPro1=`expr $sumPro1 + $proNum`   
   sumSes1=`expr $sumSes1 + $sesNum`   
 done
 len=${#ip_array[@]}
 #多个客户端预期订阅/发布总数
 expectNum=`expr $len \* $exprNum`

 if [ "$sumPro1" = "$expectNum" ];then
    proTotal="远程预期订阅总process数为$expectNum,实际数量为$sumPro1"
 else
    value=`expr $expectNum - $sumPro1`
    proTotal="远程预期订阅总process数为$expectNum,实际数量为$sumPro1,相差${value}"
 fi
 reportLog $reportPath $proTotal

 if [ "$sumSes1" = "$expectNum" ];then
    sesTotal="远程预期订阅总session数为$expectNum,实际数量为$sumSes1"
 else
    value=`expr $expectNum - $sumSes1`
    sesTotal="远程预期订阅总session数为$expectNum,实际数量为$sumSes1,相差${value}"
 fi
 reportLog $reportPath $sesTotal
}

#本地下达指令查询远程订阅结果
queryContinue(){
 reportPath=$sPath/subContinueSessionLogs/
 k=1
 spentTime=0
 while [ "$spentTime" -le "$queryTime" ] 
 do
    sumPro2=0
    sumSes2=0
    proNum=0
    sesNum=0
    proNumLocal=0
    sesNumLocal=0
    msg="=====================第${k}次查询订阅情况=================================="
    reportLog $reportPath $msg
    for ip in ${ip_array[*]}
    do
        #排除本地IP
        if [ "$ip" = "$localPcIP" ];then continue;fi
        sleep $waitForSession
        subRs=$(ssh -p $sshPort $rootusr@$ip "${remote_query} ${subRsCMD}")
        proNum=`echo $subRs|awk -F " " '{print $1}'`
        sesNum=`echo $subRs|awk -F " " '{print $2}'`
        reportLog $reportPath $ip $proNum $sesNum $subNum
        sumPro2=`expr $sumPro2 + $proNum`   
        sumSes2=`expr $sumSes2 + $sesNum`   
    done
    if $localPcFlag;then
	    subRsLocal=$(${local_query} ${subRsCMD})
            proNumLocal=`echo $subRsLocal|awk -F " " '{print $1}'`
            sesNumLocal=`echo $subRsLocal|awk -F " " '{print $2}'`
            reportLog $reportPath $localPcIP $proNum $sesNum $subNum
            sumPro2=`expr $sumPro2 + $proNumLocal`
            sumSes2=`expr $sumSes2 + $sesNumLocal`
    fi
   
    len=${#ip_array[@]}
    if $localPcFlag;then
       len=`expr $len + 1`
    fi
    #多个客户端预期订阅/发布总数
    expectNum=`expr $len \* $subNum`

    if $localPcFlag;then
       if [ "$sumPro2" = "$expectNum" ];then
         proTotal="预期订阅总process数为$expectNum,实际数量为$sumPro2"
       else
         value=`expr $expectNum - $sumPro2`
         proTotal="预期订阅总process数为$expectNum,实际数量为$sumPro2,相差${value}"
       fi
       reportLog $reportPath $proTotal

       if [ "$sumSes2" = "$expectNum" ];then
          sesTotal="预期订阅总session数为$expectNum,实际数量为$sumSes2"
       else
          value=`expr $expectNum - $sumSes2`
          sesTotal="预期订阅总session数为$expectNum,实际数量为$sumSes2,相差${value}"
       fi
       reportLog $reportPath $sesTotal
    else
       if [ "$sumPro2" = "$expectNum" ];then
         proTotal="远程预期订阅总process数为$expectNum,实际数量为$sumPro2"
       else
          value=`expr $expectNum - $sumPro2`
           proTotal="远程预期订阅总process数为$expectNum,实际数量为$sumPro2,相差${value}"
       fi
       reportLog $reportPath $proTotal

       if [ "$sumSes2" = "$expectNum" ];then
         sesTotal="远程预期订阅总session数为$expectNum,实际数量为$sumSes2"
       else
          value=`expr $expectNum - $sumSes2`
          sesTotal="远程预期订阅总session数为$expectNum,实际数量为$sumSes2,相差${value}"
       fi
       reportLog $reportPath $sesTotal
   fi
   spentTime=`expr $k \* $queryGap`
   ((k++))
  done
}

#远程订阅并记录结果
subQuRemote(){
  #与subQuLocal路径保持一致
  subLogPath=$sPath/subAllSessionLogs
  subRemote
  sleep $subWait
  queryRemote $subLogPath $subFName $subNum
}

#停止远程订阅
stopSubRemote(){
	for ip in ${ip_array[*]}  
	do 
	    #if IP is same as local ip,continue
	    if [ "$ip" = "$localPcIP" ];then continue;fi
 	    #必须加&
	    ssh -p $sshPort $rootusr@$ip "${remote_mqttClient} ${subStopScriptCMD}"&
   	    sleep 2
	    ssh -p $sshPort $rootusr@$ip "${remote_mqttClient} ${subStopCMD}"&
	done  
}

#查询收到的消息
queryFixMsgNum(){
        reportPath=$1
        msg=$2
        fileName=$3
        numbers=$4 
        reportLog $reportPath $msg 

        sum=0
        subMsgRs=0
        
        if $localPcFlag;then 
          subMsgRs=`cat ${sPath}/${fileName}|wc -l`
          message="查询本地PC-${localPcIP}当前订阅到的消息数为$subMsgRs"
          reportLog $reportPath $message
          sum=`expr $sum + $subMsgRs`
        fi
 
        for ip in ${ip_array[*]}
        do
	     subMsgRs=`ssh -p $sshPort $rootusr@$ip "cat ${remote_dir}/${fileName}|wc -l"`
             message="查询远程PC-${ip}当前订阅到的消息数为$subMsgRs"
             reportLog $reportPath $message 
             sum=`expr $sum + $subMsgRs`
	done
        
        message="预期订阅和发布交互数为${numbers}查询到当前订阅到的消息总数为$sum"
        reportLog $reportPath $message
        echo ${sum}
}

subFixLocal(){
 subFix
}

subFixRemote(){
        step=1
        for ip in ${ip_array[*]}
        do
	    scp ${sPath}/mqtt.conf $rootusr@${ip}:${remote_dir} 
            if [ "$ip" = "$localPcIP" ];then continue;fi
            #修改配置文件中的值,保证每台机器上的mosquitto_sub的id是唯一的
            newStart=`expr $subFixSNum + $subFixNum \* $step`
            ssh -p $sshPort $rootusr@$ip "sed -i 's/subFixSNum=${subFixSNum}/subFixSNum=${newStart}/g' ${remote_dir}/mqtt.conf"
            ssh -p $sshPort $rootusr@$ip "${remote_mqttClient} ${subFixCMD}"
	    ((step++))
        done
}

pubFixLocal(){
 pubFix
}

pubFixRemote(){
        step=1
        for ip in ${ip_array[*]}
        do
            if [ "$ip" = "$localPcIP" ];then continue;fi
            #修改配置文件中的值,保证每台机器上的mosquitto_sub的id是唯一的 
            newStart=`expr $pubFixSNum + $pubFixNum \* $step`
            ssh -p $sshPort $rootusr@$ip "sed -i 's/pubFixSNum=${pubFixSNum}/pubFixSNum=${newStart}/g' ${remote_dir}/mqtt.conf"
            ssh -p $sshPort $rootusr@$ip "${remote_mqttClient} ${pubFixCMD}"&
            ((step++))
        done
}

#local pc sub pub
subPubLocal(){
    $sPath/mqttClient.sh ${subPubCMD}
}

#local pc sub pub query
subPubQuLocal(){
    subPubPath=$sPath/subPubSessionLogs/
    subPubMsgPath=$sPath/subPubMsgLogs/
    session_num=0
    query_num=1
    subRecieved=""
    sleep $waitForSession
    while true
    do
       	session_num=`cat ${sPath}/${subPubRecieved}|wc -l`
       	if [ "$session_num" = "$sub_pub_num" ];then
	    subRs=$(${local_query} ${subRsCMD})
            subRecieved="执行PC${localPcIP}预期订阅/发布总数为$sub_pub_num,实际数量为$session_num"
    	    break 
	fi

	((query_num++))
        if [ "$query_num" = "$querySubCount"  ];then
	    subRs=$(${local_query} ${subRsCMD})
	    break
	fi
       	sleep $querySubGap
   done
   proNum=`echo $subRs|awk -F " " '{print $1}'`
   sesNum=`echo $subRs|awk -F " " '{print $2}'`
   reportLog $subPubPath $localPcIP $proNum $sesNum $sub_pub_num
   reportLog $subPubMsgPath $subRecived
   if [ "$sub_pub_num" -ne "$session_num" ];then
      value=`expr $sub_pub_num - $session_num`
      subRecived="执行PC${localPcIP}预期订阅/发布总数为$sub_pub_num,实际数量为$session_num,相差${value}"
      reportLog $subPubMsgPath $subRecived
   fi
}

subpubQuLocal(){
 subPubLocal
 subPubQuLocal
}

#remote pc sub pub
subPubRemote(){
	step=1
	for ip in ${ip_array[*]}  
	do
	    num=0
	    session_num=0
            queryNum=1
	    subRecievedR=""
	    scp ${sPath}/mqtt.conf $rootusr@${ip}:${remote_dir} 
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
           ((step++))
       done
}

#query remote pc sub pub
subPubQuRemote(){
        subPubPath=$sPath/subPubSessionLogs/
        subPubMsgPath=$sPath/subPubMsgLogs/
	sum=0
	for ip in ${ip_array[*]}  
	do
	    num=0
	    session_num=0
            queryNum=1
	    subRecievedR=""
	    #if IP is same as local ip,continue
	    if [ "$ip" = "$localPcIP" ];then continue;fi
  	    while true
	    do
           	session_num=`ssh -p $sshPort $rootusr@$ip "cat ${remote_dir}/${subPubRecieved}|wc -l"`
            	if [ "$session_num" = "$sub_pub_num" ];then
           	        subRsRemote=`ssh -p $sshPort $rootusr@$ip "${remote_query} ${subRsCMD}"`
		        subRecievedR="远程PC${ip}预期订阅/发布数为$sub_pub_num,实际数量为$num"
    		        break 
		fi

		((queryNum++))
                if [ "$queryNum" = "$querySubCount"  ];then
           	        subRsRemote=`ssh -p $sshPort $rootusr@$ip "${remote_query} ${subRsCMD}"`
		 	break
		fi
              	sleep $querySubGap
	    done
	    proNum=`echo $subRsRemote|awk -F " " '{print $1}'`
	    sesNum=`echo $subRsRemote|awk -F " " '{print $2}'`
	    reportLog $subPubPath $ip $proNum $sesNum $sub_pub_num
	    reportLog $subPubMsgPath $subRecivedR

	    if [ "$sub_pub_num" -ne "$num" ];then
            	diffvalue=`expr $sub_pub_num - $num`
	    	subRecivedR="远程PC${ip}预期订阅/发布数为$sub_pub_num,实际数量为$num,相差${diffvalue}"
	        reportLog $subPubMsgPath $subRecivedR
	    fi

	    #统计所有pc的会话数
	    sum=`expr $sum + $num`
	done
 
        len=${#ip_array[@]} 
        #多个客户端预期订阅/发布总数
        expectNum=`expr $len \* $sub_pub_num`

        if [ "$sum" = "$expectNum" ];then
	       recievedTotal="远程预期订阅/发布总数为$expectNum,实际数量为$sum"       
	else 
               value=`expr $expectNum - $sum`
	       recievedTotal="远程预期订阅/发布总数为$expectNum,实际数量为$sum,相差${value}"        
	fi
	reportLog $subPubMsgPath $subRecivedR
}

subpubQuRemote(){
 subPubRemote
 subPubQuRemote
}

#local pub retain,then sub them
retainLocal(){
   subPubR
}

#local pub retain,then sub them
retainQuLocal(){
        reportPath=$sPath/pubRMsgLogs/
	num=0
        queryNum=1
        retainRs=""
  	sleep $waitForSession 
  	while true
        do
           	num=`cat ${sPath}/${subPubRRecieved}|wc -l`
	        if [ "$pubRNum" =  "$num" ];then
		        retainRs="执行PC${localPcIP}预期订阅到保留消息数为$pubRNum,实际数量为$num"
    		        break 
		fi

		((queryNum++))
                if [ "$queryNum" = "$querySubCount"  ];then
		 	break
		fi
              	sleep $querySubGap
       done
       reportLog $reportPath $retainRs
       if [ "$pubRNum" -ne "$num" ];then
         diffvalue=`expr $pubRNum - $num`
         retainRs="执行PC${localPcIP}预期订阅到保留消息数为$pubRNum,实际数量为$num,相差${diffvalue}"
	 reportLog $reportPath $retainRs
       fi
}

retainQLocal(){
  retainLocal
  retainQuLocal
}

#remote pub retain,then sub them
retainRemote(){
	step=1
	for ip in ${ip_array[*]}  
	do
	    #修改配置文件中的值,保证每台机器上的mosquitto_sub的id和pub id是唯一的 
	    scp ${sPath}/mqtt.conf $rootusr@${ip}:${remote_dir} 
	    retainNewStart=`expr $pubRsNum + $pubRNum \* $step`
	    ssh -p $sshPort $rootusr@$ip "sed -i 's/pubRsNum=${pubRsNum}/pubRsNum=${retainNewStart}/g' ${remote_dir}/mqtt.conf"
	    #if IP is same as local ip,continue
	    if [ "$ip" = "$localPcIP" ];then continue;fi
	    ssh -p $sshPort $rootusr@$ip "${remote_mqttClient} ${retainCMD}"&
            #订阅保留时消息时会较大的延时，生成结果日志会较慢必须增加延时
	    ((step++))
            sleep $clientGap 
	done
}

#remote pub retain,then sub them
retainQuRemote(){
        #retainQuLocal保持一致
        reportPath=$sPath/pubRMsgLogs/
	sum=0
	for ip in ${ip_array[*]}  
	do
	    num=0
            queryNum=1
	    #if IP is same as local ip,continue
	    if [ "$ip" = "$localPcIP" ];then continue;fi
  	    while true
	    do
           	num=`ssh -p $sshPort $rootusr@$ip "cat ${remote_dir}/${subPubRRecieved}|wc -l"`
            	if [ "$num" = "$pubRNum" ];then
		        retainRsR="远程PC${ip}预期订阅到保留消息数为$pubRNum,实际数量为$num"
    		        break 
		fi

		((queryNum++))
                if [ "$queryNum" = "$querySubCount"  ];then
		 	break
		fi
              	sleep $querySubGap
	    done

            reportLog $reportPath $retainRsR
	    if [ "$pubRNum" -ne "$num" ];then
            	diffvalue=`expr $pubRNum - $num`
		retainRsR="远程PC${ip}预期订阅到保留消息数为$pubRNum,实际数量为$num,相差${diffvalue}"
	        reportLog $reportPath $retainRsR
	    fi

	    #统计所有pc的会话数
	    sum=`expr $sum + $num`
	done
 
        len=${#ip_array[@]} 
        #多个客户端预期订阅/发布总数
        expectNum=`expr $len \* $pubRNum`

        if [ "$sum" = "$expectNum" ];then
	        retainTotal="远程预期订阅保留消息总数为$expectNum,实际数量为$sum"       
	else 
        	value=`expr $expectNum - $sum`
	        retainTotal="远程预期订阅保留消息总数为$expectNum,实际数量为$sum,相差${value}"        
	fi
        reportLog $reportPath $retainTotal
}

retainQRemote(){
 retainRemote
 retainQuRemote
}

#停止远程订阅保留消息
stopRetainRemote(){
	for ip in ${ip_array[*]}  
	do
	    ssh -p $sshPort $rootusr@$ip "${remote_mqttClient} ${stopRetainCMD}"
	    ssh -p $sshPort $rootusr@$ip "${remote_mqttClient} ${subStopScriptCMD}"&
	done
}

#本地一次性订阅
subCLocal(){
 $sPath/mqttClient.sh ${subCCMD}
}

#查询本地一次性订阅
subCQuLocal(){
  reportPath=$sPath/subCSessionLogs/
  subCProNum=0 
  subCSesNum=0
  i=0
  while true
  do
	subCnumber=`cat "${sPath}/${subCFName}"`
	if [ "$subCnumber" = "$subCNum" ];then
	   subCRs=$(${local_query} $subRsCMD)
	   break
	fi
	if [ "$i" = "$querySubCount" ];then
	   subCRs=$(${local_query} $subRsCMD)
	   break
	fi
        ((i++))
	sleep $querySubGap
  done
  countMsg="-----${localPcIP}下发订阅数为${subCnumber}-----"
  reportLog $reportPath $countMsg 
  subCProNum=`echo $subCRs|awk -F " " '{print $1}'`
  subCSesNum=`echo $subCRs|awk -F " " '{print $2}'`
  reportLog $reportPath $localPcIP $subCProNum $subCSesNum $subCNum
}
#一次性订阅和查询
subCQLocal(){
 subCLocal
 subCQuLocal
}
#远程一性订阅
subCRemote(){
   step=1
   for ip in ${ip_array[*]}
   do
     scp ${sPath}/mqtt.conf $rootusr@${ip}:${remote_dir} 
     if [ "$ip" = "$localPcIP" ];then continue;fi
     newStart=`expr $subCsNum + $subCNum \* $step`
     #修改远程客户机创建客户端的范围
     ssh -p $sshPort $rootusr@$ip "sed -i 's/subCsNum=${subCsNum}/subCsNum=${newStart}/g' ${remote_dir}/mqtt.conf"
     #远程客户机进行订阅
     ssh -p $sshPort $rootusr@$ip "${remote_mqttClient} ${subCCMD}"&
     ((step++))
   done
} 
#添加一次用户后再使用 
subCNoAccRemote(){
   for ip in ${ip_array[*]}
   do
     if [ "$ip" = "$localPcIP" ];then continue;fi
     #远程客户机进行订阅
     ssh -p $sshPort $rootusr@$ip "${remote_mqttClient} ${subCNoAccCMD}"&
   done
}
  
#远程一性订阅查询
subCQuRemote(){
   #与subCQuLocal保持一致
   reportPath=$sPath/subCSessionLogs/
   sumPro=0
   sumSes=0
   for ip in ${ip_array[*]}
   do
     num=0
     queryNum=1
     if [ "$ip" = "$localPcIP" ];then continue;fi
     while true
     do
		sleep $waitForSession
                num=`ssh -p $sshPort $rootusr@$ip "cat ${remote_dir}/${subCFName}"`
                if [ "$num" = "$subCNum" ];then
			subCRsR=$(ssh -p $sshPort $rootusr@$ip "${remote_query} ${subRsCMD}")
                        break
                fi

                ((queryNum++))
                if [ "$queryNum" = "$querySubCount"  ];then
			subCRsR=$(ssh -p $sshPort $rootusr@$ip "${remote_query} ${subRsCMD}")
                        break
                fi
                sleep $querySubGap
     done
     countMsg="-----${ip}下发订阅数为${num}-----"
     reportLog $reportPath $countMsg 
     proNum=`echo $subRs|awk -F " " '{print $1}'`
     sesNum=`echo $subRs|awk -F " " '{print $2}'`
     reportLog $reportPath $ip $proNum $sesNum $subCNum
     sumPro=`expr $sumPro + $proNum`
     sumSes=`expr $sumSes + $sesNum`
  done
  len=${#ip_array[@]}
  #多个客户端预期订阅/发布总数
  expectNum=`expr $len \* $subCNum`
  if [ "$sumPro" = "$expectNum" ];then
    proTotal="远程预期订阅总进程数为$expectNum,实际数量为$sumPro"
  else
    value=`expr $expectNum - $sumPro`
    proTotal="远程预期订阅总进程数为$expectNum,实际数量为$sumPro,相差${value}"
  fi

  reportLog $reportPath $proTotal
  if [ "$sumSes" = "$expectNum" ];then
    sesTotal="远程预期订阅总会话数为$expectNum,实际数量为$sumSes"
  else
    value=`expr $expectNum - $sumSes`
    sesTotal="远程预期订阅总会话数为$expectNum,实际数量为$sumSes,相差${value}"
  fi
  reportLog $reportPath $sesTotal
} 

#远程一次性订阅和查询
subCQRemote(){
 subCRemote
 subCQuRemote
}

subCQuContinue(){
   local msg=$1
   local reportPath=$2
   local fileName=$3
   local expect=$4
   reportLog $reportPath $msg
   local proNum=0
   local sesNum=0
   
   local subCProNum=0
   local subCSesNum=0
   
   local sumPro=0
   local sumSes=0
 
   for ip in ${ip_array[*]}
   do
     num=0
     queryNum=1
     if [ "$ip" = "$localPcIP" ];then continue;fi
     while true
     do
                sleep $querySubGap
                num=`ssh -p $sshPort $rootusr@$ip "cat ${remote_dir}/${fileName}"`
                if [ "$num" = "$expect" ];then
                        subCRsR=$(ssh -p $sshPort $rootusr@$ip "${remote_query} ${subRsCMD}")
                        break					
                fi

                if [ "$queryNum" = "$querySubCount"  ];then
                        subCRsR=$(ssh -p $sshPort $rootusr@$ip "${remote_query} ${subRsCMD}")
                        break
                fi
                ((queryNum++))
     done
     countMsg="-----${ip}下发订阅数为${num}-----"
     reportLog $reportPath $countMsg 
     proNum=`echo $subCRsR|awk -F " " '{print $1}'`	 
     sesNum=`echo $subCRsR|awk -F " " '{print $2}'`
     reportLog $reportPath $ip $proNum $sesNum $expect
     sumPro=`expr $sumPro + $proNum`
     sumSes=`expr $sumSes + $sesNum`				           
	 if [ "${proNum}" -gt "${expect}" ];then 	
	    msg="${ip}订阅数异常，预期订阅进程数为${expect}实际进程数为${proNum}" 
		reportLog $reportPath $msg
	    return 1;
	 fi
  done

  if $localPcFlag;then 
      i=0
      while true
      do
        sleep $querySubGap
        subCnumber=`cat "${sPath}/${fileName}"`
        if [ "$subCnumber" = "$expect" ];then
           subCRs=$(${local_query} $subRsCMD)
           break
        fi
        if [ "$i" = "$querySubCount" ];then
           subCRs=$(${local_query} $subRsCMD)
           break
        fi
        ((i++))
     done
     countMsg="-----${localPcIP}下发订阅数为${subCnumber}-----"
     reportLog $reportPath $countMsg 
     subCProNum=`echo $subCRs|awk -F " " '{print $1}'`
     subCSesNum=`echo $subCRs|awk -F " " '{print $2}'`
	 
     reportLog $reportPath $localPcIP $subCProNum $subCSesNum $expect
     sumPro=`expr $sumPro + $subCProNum`
     sumSes=`expr $sumSes + $subCSesNum`
	 if [ "${subCProNum}" -gt "${expect}" ];then 	    
	    msg="${localPcIP}订阅数异常，预期订阅进程数为${expect}实际进程数为${subCProNum}" 
		reportLog $reportPath $msg
	    return 1;
	 fi
  fi
  
  len=${#ip_array[@]}
  if $localPcFlag;then
    len=`expr $len + 1`
  fi
  #多个客户端预期订阅/发布总数
  expectNum=`expr $len \* $expect`
  if $localPcFlag;then
     if [ "$sumPro" = "$expectNum" ];then
        proTotal="预期订阅总process数为$expectNum,实际数量为$sumPro"
     else
        value=`expr $expectNum - $sumPro`
        proTotal="预期订阅总process数为$expectNum,实际数量为$sumPro,相差${value}"
     fi

     reportLog $reportPath $proTotal
     if [ "$sumSes" = "$expectNum" ];then
       sesTotal="预期订阅总session数为$expectNum,实际数量为$sumSes"
     else
       value=`expr $expectNum - $sumSes`
       sesTotal="预期订阅总session数为$expectNum,实际数量为$sumSes,相差${value}"
     fi
     reportLog $reportPath $sesTotal
  else
     if [ "$sumPro" = "$expectNum" ];then
        proTotal="远程预期订阅总process数为$expectNum,实际数量为$sumPro"
     else
        value=`expr $expectNum - $sumPro`
        proTotal="远程预期订阅总process数为$expectNum,实际数量为$sumPro,相差${value}"
     fi

     reportLog $reportPath $proTotal
     if [ "$sumSes" = "$expectNum" ];then
       sesTotal="远程预期订阅总session数为$expectNum,实际数量为$sumSes"
     else
       value=`expr $expectNum - $sumSes`
       sesTotal="远程预期订阅总session数为$expectNum,实际数量为$sumSes,相差${value}"
     fi
     reportLog $reportPath $sesTotal
 fi 
}

unsubCQuContinue(){
   msg=$1
   reportPath=$2
   reportLog $reportPath $msg
   sumPro=0
   sumSes=0
   zero=0
   for ip in ${ip_array[*]}
   do
     queryNum=1
     if [ "$ip" = "$localPcIP" ];then continue;fi
     while true
     do
                sleep $waitForSession
                subCRsR=$(ssh -p $sshPort $rootusr@$ip "${remote_query} ${subRsCMD}")
                proNum=`echo $subCRsR|awk -F " " '{print $1}'`
                if [ "$proNum" = "$zero" ];then
                        break			   
                fi

                if [ "$queryNum" = "$querySubCount"  ];then
                        subCRsR=$(ssh -p $sshPort $rootusr@$ip "${remote_query} ${subRsCMD}")
                        break
                fi
                ((queryNum++))
     done
	 
     proNum=`echo $subCRsR|awk -F " " '{print $1}'`
     sesNum=`echo $subCRsR|awk -F " " '{print $2}'`
	 
     reportLog $reportPath $ip $proNum $sesNum $zero 
     sumPro=`expr $sumPro + $proNum`
     sumSes=`expr $sumSes + $sesNum`
	 if [ "$proNum" -ne "$zero" ];then
	    msg="${ip}取消订阅失败，预期进程数为0实际进程数为${proNum}" 
		reportLog $reportPath $msg
		return 1
	 fi
  done

  if $localPcFlag;then 
      i=0
      while true
      do
        sleep $querySubGap
        subCRs=$(${local_query} $subRsCMD)
        subCProNum=`echo $subCRs|awk -F " " '{print $1}'`
        if [ "$subCProNum" = "$zero" ];then
           break
        fi

        if [ "$i" = "$querySubCount" ];then
           subCRs=$(${local_query} $subRsCMD)
           break
        fi
        ((i++))
     done
     subCProNum=`echo $subCRs|awk -F " " '{print $1}'`
     subCSesNum=`echo $subCRs|awk -F " " '{print $2}'`
     reportLog $reportPath $localPcIP $subCProNum $subCSesNum $zero
     sumPro=`expr $sumPro + $subCProNum`
     sumSes=`expr $sumSes + $subCSesNum`
	 if [ "$subCProNum" -ne "${zero}" ];then
	    msg="${localPcIP}取消订阅失败，预期进程数为0实际进程数为${subCProNum}" 
		reportLog $reportPath $msg
		return 1
	 fi
  fi

  if $localPcFlag;then
     if [ "$sumPro" = "$zero" ];then
        proTotal="预期订阅总process数为$zero,实际数量为$sumPro"
     else
        value=`expr $sumPro - $zero`
        proTotal="预期订阅总process数为$zero,实际数量为$sumPro,相差${value}"
     fi
     reportLog $reportPath $proTotal

     if [ "$sumSes" = "$zero" ];then
       sesTotal="预期订阅总session数为$zero,实际数量为$sumSes"
     else
       value=`expr $sumSes - $zero`
       sesTotal="预期订阅总session数为$zero,实际数量为$sumSes,相差${value}"
     fi
     reportLog $reportPath $sesTotal
  else
     if [ "$sumPro" = "$zero" ];then
        proTotal="远程预期订阅总process数为$zero,实际数量为$sumPro"
     else
        value=`expr $sumPro - $zero`
        proTotal="远程预期订阅总process数为$zero,实际数量为$sumPro,相差${value}"
     fi
     reportLog $reportPath $proTotal

     if [ "$sumSes" = "$zero" ];then
       sesTotal="远程预期订阅总session数为$zero,实际数量为$sumSes"
     else
       value=`expr $sumSes - $zero`
       sesTotal="远程预期订阅总session数为$zero,实际数量为$sumSes,相差${value}"
     fi
     reportLog $reportPath $sesTotal	 
 fi
 
}

subCReRemote(){
   step=1
   for ip in ${ip_array[*]}
   do
     scp ${sPath}/mqtt.conf $rootusr@${ip}:${remote_dir}
     if [ "$ip" = "$localPcIP" ];then continue;fi
     newStart=`expr $subCResNum + $subCReNum \* $step`
     #修改远程客户机创建客户端的范围
     ssh -p $sshPort $rootusr@$ip "sed -i 's/subCResNum=${subCResNum}/subCResNum=${newStart}/g' ${remote_dir}/mqtt.conf"
     #远程客户机进行订阅
     ssh -p $sshPort $rootusr@$ip "${remote_mqttClient} ${subCReCMD}"&
     ((step++))
   done
}
#添加一次用户后再使用 
subCReNoAccRemote(){
   for ip in ${ip_array[*]}
   do
     if [ "$ip" = "$localPcIP" ];then continue;fi
     #远程客户机进行订阅
     ssh -p $sshPort $rootusr@$ip "${remote_mqttClient} ${subCReNoAccCMD}"&
   done
}

#查询收到的消息数量
queryMsgNum(){
        local reportPath=$1
	local msg=$2
	local fileName=$3
        msgNum=$4 
	num=0
        sum=0
        expectNum=0
        local subMsgRs=""
        reportLog $reportPath $msg 
        if $localPcFlag;then 
            subMsgRs=`cat ${sPath}/${fileName}|wc -l`
            local message="查询本地PC-${localPcIP}当前订阅到的消息数为$subMsgRs"
            reportLog $reportPath $message
            sum=`expr $sum + $subMsgRs`
	    num=1
        fi
 
        for ip in ${ip_array[*]}
        do
	     subMsgRs=`ssh -p $sshPort $rootusr@$ip "cat ${remote_dir}/${fileName}|wc -l"`
             local message="查询远程PC-${ip}当前订阅到的消息数为$subMsgRs"
             reportLog $reportPath $message 
             sum=`expr $sum + $subMsgRs`
             num=`expr $num + 1`
        done
        # 计算预期消息总数
        expectNum=`expr $num \* $msgNum`
        if [ "$expectNum" = "$sum" ];then
	        message="预期订阅和发布交互数为${expectNum},实际收到的消息总数为$sum"
        elif [ "$expectNum" -lt "$sum" ];then
		value=`expr $sum - $expectNum`
	        message="异常:预期订阅和发布交互数为${expectNum},实际收到的消息总数为$sum,多收到${value}个消息"
        elif [ "$expectNum" -ge "$sum" ];then
		value=`expr $expectNum - $sum`
	        message="错误:预期订阅和发布交互数为${expectNum},实际收到的消息总数为$sum,少收到${value}个消息"
        fi
        reportLog $reportPath $message
        echo ${sum}
}

#本机与远程机器均发布多条保留消息，且主题和消息内容都是唯一的
pubRetain(){
 step=1
 if $localPcFlag;then
    pubRLoop
 fi  
 for ip in ${ip_array[*]}
 do
    scp ${sPath}/mqtt.conf $rootusr@${ip}:${remote_dir} 
    if [ "$ip" = "$localPcIP" ];then continue;fi
     #修改配置文件中的值,保证每台机器上的mosquitto_sub的id是唯一的 
     newStart=`expr $pubRsNum + $pubRNum \* $step`
     ssh -p $sshPort $rootusr@$ip "sed -i 's/pubRsNum=${pubRsNum}/pubRsNum=${newStart}/g' ${remote_dir}/mqtt.conf"
     ssh -p $sshPort $rootusr@$ip "${remote_mqttClient} ${pubRCMD}"
     sleep $pubRWait
    ((step++))
 done
}

reportPubLog(){
  logPath=$1
  if [ "$#" = 2 ];then
    message=$2
    writeLog $message
  else
        ipaddr=$2
        pubnum=$3
        expect=$4
        total="Client_$ipaddr:预期mosquitto_pub数为${expect}个，实际数${pubnum}个"
        pubrRs=""
        if [ "$pubnum" -lt "$expect" ];then
           pubrRs="Client_$ipaddr:实际上有${pubnum}个mosquitto_pub个,少于预期的${expect}个,相差`expr $expect - $pubnum`个"
        fi
  	writeLog $total
  	writeLog $pubrRs
  fi
}

queryPubRLocal(){
 reportPath=${sPath}/subCPubRCountLogs/
 i=0
 pubrNum=0
 if $localPcFlag;then
    while true
    do
      sleep $waitForSession
      pubrNum=`cat ${sPath}/${pubRFName}`
      if [ "$pubrNum" = "$pubRNum" ];then
         break
      fi
      
      if [ "$i" = "$querySubCount" ];then
        pubrNum=`cat ${sPath}/${pubRFName}`  
        break
      fi
     ((i++))
    done  
 fi
 reportPubLog $reportPath $localPcIP $pubrNum $pubRNum 
}
 
queryPubRRemote(){
 reportPath=$sPath/subCPubRCountLogs/
 for ip in ${ip_array[*]}
 do
    i=0
    pubrNum=0
    while true
    do
      sleep $waitForSession
      pubrNum=`ssh -p $sshPort $rootusr@$ip "cat ${remote_dir}/${pubRFName}"`
      if [ "$pubrNum" = "$pubRNum" ];then
         break
      fi
      
      if [ "$i" = "$querySubCount" ];then
	 pubrNum=`ssh -p $sshPort $rootusr@$ip "cat ${remote_dir}/${pubRName}"`
        break
      fi
      ((i++))
    done  
    reportPubLog $reportPath $ip $pubrNum $pubRNum 
 done 
}

#远程和本地一次性订阅保留消息
subCRetain(){
 if $localPcFlag;then
    subCRLoop
    sleep $waitForSession
 fi
 
 for ip in ${ip_array[*]}
 do
     if [ "$ip" = "$localPcIP" ];then continue;fi
     ssh -p $sshPort $rootusr@$ip "${remote_mqttClient} ${subCRCMD}"
     sleep $pubRWait
 done
}

#远程和本地一次性订阅保留消息后
#收到的保留消息数量
querySubCR(){
 reportPath=$sPath/subCPubRMsgLogs/ 
 reMsg=${sPath}/${subCPubRRecieved} 
 sum=0
 expectNum=0
 if $localPcFlag;then
    i=0
    while true
    do
      sleep $waitForSession
      subpubrNum=`cat $reMsg|wc -l`  
      if [ "$subpubrNum" = "$pubRNum" ];then
         break
      fi
      
      if [ "$i" = "$querySubCount" ];then
        subpubrNum=`cat $reMsg|wc -l`  
        break
      fi
     ((i++))
    done 
    msg="本地PC${localPcIP}预期收到保留消息${pubRNum},实际收到${subpubrNum}"
    reportPubLog $reportPath $msg
    sum=`expr $sum + $subpubrNum`
    expectNum=`expr $expectNum + $pubRNum`
 fi

 for ip in ${ip_array[*]}
 do
    i=0
    while true
    do
      sleep $waitForSession
      subpubrNum=`ssh -p $sshPort $rootusr@$ip "cat ${remote_dir}/${subCPubRRecieved}|wc -l"`
      if [ "$subpubrNum" = "$pubRNum" ];then
         break
      fi
      
      if [ "$i" = "$querySubCount" ];then
	 subpubrNum=`ssh -p $sshPort $rootusr@$ip "cat ${remote_dir}/${subCPubRRecieved}|wc -l"`
        break
      fi
      ((i++))
    done  
    msg="远程PC${ip}预期收到保留消息${pubRNum},实际收到${subpubrNum}"
    reportPubLog $reportPath $msg
    sum=`expr $sum + $subpubrNum`
 done
 len=${#ip_array[*]}
 reNum=`expr $len \* $pubRNum`
 expectNum=`expr $expectNum + $reNum`
 msg="总共预期收到保留消息${expectNum},实际收到${sum}"
 reportPubLog $reportPath $msg
}

#本地单向证书认证并记录结果
subCaAuthQuLocal(){
 subCaLogPath=$sPath/subCaSessionLogs/
 subCaAuth
 sleep $subCaWait
 queryLocal $subCaLogPath $subCaFName $subCaNum $srv_ip $caPort
}
#远程单向证书认证
subCaAuthRemote(){
	step=1
        for ip in ${ip_array[*]}
        do
            scp ${sPath}/mqtt.conf $rootusr@${ip}:${remote_dir}
            if [ "$ip" = "$localPcIP" ];then continue;fi
            #修改配置文件中的值,保证每台机器上的mosquitto_sub的id是唯一的 
            newStart=`expr $subCaSNum + $subCaNum \* $step`
            ssh -p $sshPort $rootusr@$ip "sed -i 's/subCaSNum=${subCaSNum}/subCaSNum=${newStart}/g' ${remote_dir}/mqtt.conf"
            ssh -p $sshPort $rootusr@$ip "${remote_mqttClient} ${subCaAuthCMD}"&
           ((step++))
        done

}
#远程订阅并记录结果
subCaAuthQuRemote(){
  #与subQuLocal路径保持一致
  subCaLogPath=$sPath/subCaSessionLogs/
  subCaAuthRemote
  sleep $subCaWait
  queryRemote $subCaLogPath $subCaFName $subCaNum $srv_ip $caPort
}

#查询收到消息数量并写放日志
queryMsg(){
    local i=0
    local reportPath=$1
    #预期消息数
    local pubNum=$2
    #计数文件
    local numFile=$3
    #消息文件
    local msgFile=$4
    local pcIP=$5
    #收到消息数量
    local msgNum=0
    while true
    do
       #记录下发消息数
       local pubCountNum=`cat "$numFile"`
       if [ "$pubCountNum" = "$pubNum" ];then
            #实际收到消息数
	    msgNum=`cat ${msgFile}|wc -l`
            if [ "$msgNum" -lt "$pubNum" ];then
               local value=`expr $pubNum - $msgNum`
               local  msg="失败:${pcIP}发送消息数${pubNum}条,收到消息数${msgNum}条,相差${value}条"
            elif [ "$msgNum" = "$pubNum" ];then
               local  msg="成功:${pcIP}发送消息数${pubNum}条,收到消息数${msgNum}条"
            elif [ "$msgNum" -gt "$pubNum" ];then
               local value=`expr $msgNum - $pubNum`
               local  msg="异常:${pcIP}发送消息数${pubNum}条,收到消息数${msgNum}条,多收到${value}条"
            fi
            reportLog $reportPath $msg
            break
       fi
 
      ((i++))
      #循环查询达到限定次数跳出循环，但仍查询一次
      if [ "$i" = 5 ];then
         #实际收到消息数
	 msgNum=`cat ${msgFile}|wc -l`
         if [ "$msgNum" -lt "$pubNum" ];then
              local value=`expr $pubNum - $msgNum`
              local  msg="失败:${pcIP}发送消息数${pubNum}条,收到消息数${msgNum}条,相差${value}条"
         elif [ "$msgNum" = "$pubNum" ];then
             local  msg="成功:${pcIP}发送消息数${pubNum}条,收到消息数${msgNum}条"
         elif [ "$msgNum" -gt "$pubNum" ];then
             local value=`expr $msgNum - $pubNum`
             local  msg="异常:${pcIP}发送消息数${pubNum}条,收到消息数${msgNum}条,多收到${value}条"
         fi
         reportLog $reportPath $msg
         break;
      fi
      sleep $waitForSession
      
   done
}

#远程机器执行订阅
subCCaRemote(){
  local step=1
  local snum=$1
  local subnum=$2
  for ip in ${ip_array[*]}
  do 
	scp ${sPath}/mqtt.conf $rootusr@${ip}:${remote_dir}
	if [ "$ip" = "${localPcIP}" ];then continue;fi
	local newStart=`expr $snum + $subnum \* $step`
	ssh -p $sshPort $rootusr@$ip "sed -i 's/subCCaSNum=${snum}/subCCaSNum=${newStart}/g' ${remote_dir}/mqtt.conf"
        ssh -p $sshPort $rootusr@$ip "${remote_mqttClient} $subCCaCMD"&
	((step++))
  done  
}

#远程机器执行订阅，无创建账户操作
subCCaNoAccRemote(){
  for ip in ${ip_array[*]}
  do
        if [ "$ip" = "${localPcIP}" ];then continue;fi
        ssh -p $sshPort $rootusr@$ip "${remote_mqttClient} $subCCaNoAccCMD"&
  done
}


#远程发布,这里不需要改配置pub的起始序号，因为这里使用subcca中的序号
pubCCaRemote(){
  for ip in ${ip_array[*]}
  do
     ssh -p $sshPort $rootusr@$ip "${remote_mqttClient} $pubCCaCMD"&
  done 
}

#远程发布,这里不需要改配置pub的起始序号，因为这里使用subcca中的序号
pubCCaNoAccRemote(){
  for ip in ${ip_array[*]}
  do
     ssh -p $sshPort $rootusr@$ip "${remote_mqttClient} $pubCCaNoAccCMD"&
  done
}

#远程机器执行订阅
subCaConRemote(){
  local step=1
  local snum=$1
  local subnum=$2
  for ip in ${ip_array[*]}
  do
        scp ${sPath}/mqtt.conf $rootusr@${ip}:${remote_dir}
        if [ "$ip" = "${localPcIP}" ];then continue;fi
        local newStart=`expr $snum + $subnum \* $step`
        ssh -p $sshPort $rootusr@$ip "sed -i 's/subCaConSNum=${snum}/subCaConSNum=${newStart}/g' ${remote_dir}/mqtt.conf"
        ssh -p $sshPort $rootusr@$ip "${remote_mqttClient} $subCaConCMD"&
        ((step++))
  done
}

#创建发布消息的用户,序号与sub的序号一致
pubCaConAccRemote(){
  for ip in ${ip_array[*]}
  do
        if [ "$ip" = "${localPcIP}" ];then continue;fi
        ssh -p $sshPort $rootusr@$ip "${remote_mqttClient} $pubCaConAccCMD"&
  done

}

#远程机器客户端发布消息
pubCaConNoAccRemote(){
  for ip in ${ip_array[*]}
  do
        if [ "$ip" = "${localPcIP}" ];then continue;fi
        ssh -p $sshPort $rootusr@$ip "${remote_mqttClient} $pubCaConNoAccCMD"&
  done
}

#远程订阅不同主题
#snum = subCaMuTopicSNum
#subnum = subCaMuTopicNum
subCaMuRemote(){
  local step=1
  local snum=$1
  local subnum=$2
  for ip in ${ip_array[*]}
  do
        scp ${sPath}/mqtt.conf $rootusr@${ip}:${remote_dir}
        if [ "$ip" = "${localPcIP}" ];then continue;fi
        local newStart=`expr $snum + $subnum \* $step`
        ssh -p $sshPort $rootusr@$ip "sed -i 's/subCaMuTopicSNum=${snum}/subCaMuTopicSNum=${newStart}/g' ${remote_dir}/mqtt.conf"
        ssh -p $sshPort $rootusr@$ip "${remote_mqttClient} $subCaMuCMD"&
        ((step++))
  done
}

#创建发布消息的用户,序号与sub的序号一致
pubCaMuAccRemote(){
  for ip in ${ip_array[*]}
  do
        if [ "$ip" = "${localPcIP}" ];then continue;fi
        ssh -p $sshPort $rootusr@$ip "${remote_mqttClient} $pubCaMuAccCMD"&
  done

}

#远程机器客户端发布消息
pubCaMuNoAccRemote(){
  for ip in ${ip_array[*]}
  do
        if [ "$ip" = "${localPcIP}" ];then continue;fi
        ssh -p $sshPort $rootusr@$ip "${remote_mqttClient} $pubCaMuNoAccCMD"&
  done
}

if [ "sub" = "$1" ];then
   subQuLocal
fi
