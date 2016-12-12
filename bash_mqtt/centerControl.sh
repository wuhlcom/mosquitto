#!/bin/bash 
# send ssh cmd to run script of remote client  
#注意文件加载的顺序
sPath=`dirname $0`
#注释文件顺序
source $sPath/mqttClient.sh
source $sPath/logger.sh

remote_mqttClient=$remote_dir/mqttClient.sh
remote_query=$remote_dir/logger.sh

subCMD=subloop  
subCRCMD=subcrloop  
subFixCMD=subfix  
pubFixCMD=pubfix
subRsCMD=subresult
subStopCMD=stopsubpub
subPubCMD=subpub
subCCMD=subcloop
subCNoAccCMD=subcloopnoacc
retainCMD=subpubr
pubRCMD=pubrloop
stopRetainCMD=stopsubpubr
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
reportLog(){
  logPath=$1
  if [ "$#" = 2 ];then
    message=$2
    write_log $message
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
	    proRs="Client_$ipaddr:实际上有${sesNum}个${client_type}会话,多于预期的${expect}个,相差`expr $sesNum - $exepct`个,有重复的client"
	  fi

	  write_log $total
	  write_log $proRs 
	  write_log $sesRs
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
   proNum1=0
   sesNum1=0
   #reportPath=$sPath/subLogs/
   sleep $waitForSession
   i=0
   while true
   do
     subRsNum=`cat "${sPath}/${fileName}"`
     #mqttSubNum=`echo $subRsNum|awk -F " " '{print $3}'`
     #订阅完成则查询订阅结果
     if [ "$subRsNum" = "$exprNum" ];then
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
  proNum1=`echo $subRs|awk -F " " '{print $1}'`
  sesNum1=`echo $subRs|awk -F " " '{print $2}'`
  reportLog $reportPath $localPcIP $proNum1 $sesNum1 $exprNum
}

#本地订阅并记录结果
subQuLocal(){
 subLocal
 subLogPath=$sPath/subLogs/
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
 filenName=$2
 exprNum=$3
 i=0
 sumPro1=0
 sumSes1=0
 #reportPath=$sPath/subLogs/
 for ip in ${ip_array[*]}
  do
    #排除本地IP
    if [ "$ip" = "$localPcIP" ];then continue;fi
    while true
    do
      sleep $waitForSession
      subRsNum=`ssh -p $sshPort $rootusr@$ip "cat ${remote_dir}/${fileName}"`
      #pcSubNum=`echo $subResult|awk -F " " '{print $3}'`
      #订阅完成则查询订阅结果
      if [ "$subRsNum" = "$exprNum" ];then
         subRs=$(ssh -p $sshPort $rootusr@$ip "${remote_query} ${subRsCMD}")
         break
      fi
      ((i++))
      #订阅超时后也要订阅结果
      if [ "$i" = "$querySubCount" ];then
        subRs=$(ssh -p $sshPort $rootusr@$ip "${remote_query} ${subRsCMD}")
	break
      fi
   done
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
 k=1
 spentTime=0
 reportPath=$sPath/subCoutinueLogs/
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
  subRemote
  subLogPath=$sPath/subLogs/
  queryRemote $subLogPath $subFName $subNum
}

#停止远程订阅
stopSubRemote(){
	for ip in ${ip_array[*]}  
	do 
	    #if IP is same as local ip,continue
	    if [ "$ip" = "$localPcIP" ];then continue;fi
 	    #必须加&
	    ssh -p $sshPort $rootusr@$ip "${remote_mqttClient} ${subStopCMD}"&
	done  
}

queryFix(){
        reportPath=$1
        msg=$2
        fileName=$3
        reportLog $reportPath $msg 

        sum=0
        subMsgRs=0
        
        if $localPcFlag;then 
          subMsgRs=`cat $sPath/$fileName|wc -l`
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
        
        message="预期订阅和发布交互数为${subFixCount}查询到当前订阅到的消息总数为$sum"
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

subFixAll(){
        subFixLogPath=$sPath/subFixLogs/
        subFixRsLogPath=$sPath/subFixRsLogs/
	count=1
        realNum=0
        skipTime=0
        subFixRemote
        if $localPcFlag;then
                subFixLocal
 		queryLocal $subFixLogPath $subFixFName $subFixNum
        fi
        queryRemote $subFixLogPath $subFixFName $subFixNum
        
        pubFixLocal
        pubFixRemote

       while true 
       do
         msg="第${count}次查询订阅消息结果"
         realNum=`queryFix $subFixRsLogPath $msg $subFixRecieved`
         echo $realNum
         if [ "$realNum" -ge "$subFixCount" ];then
            break
         fi

         if [ "$skipTime" = "$subFixQueryTime" ];then
		break
         fi

         sleep $subFixGap
         skipTime=`expr $subFixGap \* $count` 
	 ((count++))
      done

      stopSubRemote
      if $localPcFlag;then
          stopSubPub
      fi
}

#testcase 1
subAll(){
        proNum1=0
        sesNum1=0
        sumPro1=0
        sumSes1=0
	subQuRemote
        if $localPcFlag;then
                subQuLocal
                expectNum=`expr $expectNum + $subNum`
        fi
  
        stopSubRemote
        if $localPcFlag;then
                stopSubPub
        fi  
        sumProAll=`expr $proNum1 + $sumPro1`
        sumSesAll=`expr $sesNum1 + $sumSes1`
        if [ "$sumProAll" = "$expectNum" ];then
            rs="预期订阅总process数为$expectNum,实际数量为$sumProAll"
        else
            value=`expr $expectNum - $sumProAll`
            rs="预期订阅总process数为$expectNum,实际数量为$sumProAll,相差${value}"
        fi  
        reportLog $reportPath $rs 
  
        if [ "$sumSesAll" = "$expectNum" ];then
            rs="预期订阅总session数为$expectNum,实际数量为$sumSesAll"
        else
            value=`expr $expectNum - $sumSesAll`
            rs="预期订阅总session数为$expectNum,实际数量为$sumSesAll,相差${value}"
        fi  
        reportLog $reportPath $rs 
}

#testcase 2
subAllContinue(){
        proNum2=0
        sesNum2=0
        sumPro2=0
        sumSes2=0
	subRemote
        if $localPcFlag;then
                subLocal
        fi
        queryContinue 
        stopSubRemote
        if $localPcFlag;then
                stopSubPub
        fi  
}

#local pc sub pub
subPubLocal(){
    $sPath/mqttClient.sh ${subPubCMD}
}

#local pc sub pub query
subPubQuLocal(){
    reportPath=$sPath/subPubLogs/
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
   reportLog $reportPath $localPcIP $proNum $sesNum $sub_pub_num
   reportLog $reportPath $subRecived
   if [ "$sub_pub_num" -ne "$session_num" ];then
      value=`expr $sub_pub_num - $session_num`
      subRecived="执行PC${localPcIP}预期订阅/发布总数为$sub_pub_num,实际数量为$session_num,相差${value}"
      reportLog $reportPath $subRecived
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
	sum=0
        reportPath=$sPath/subPubLogs/
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
	    reportLog $reportPath $ip $proNum $sesNum $sub_pub_num
	    reportLog $reportPath $subRecivedR

	    if [ "$sub_pub_num" -ne "$num" ];then
            	diffvalue=`expr $sub_pub_num - $num`
	    	subRecivedR="远程PC${ip}预期订阅/发布数为$sub_pub_num,实际数量为$num,相差${diffvalue}"
	        reportLog $reportPath $subRecivedR
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
        reportLog $reportPath $recievedTotal
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
        reportPath=$sPath/pubRetainLogs/
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
	sum=0
        reportPath=$sPath/pubRetainLogs/
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
	    ssh -p $sshPort $rootusr@$ip "${remote_mqttClient} ${stopRetainCMD}"&
	done
}

#本地一次性订阅
subCLocal(){
 $sPath/mqttClient.sh ${subCCMD}
}

#查询本地一次性订阅
subCQuLocal(){
  reportPath=$sPath/subCLogs/
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
   reportPath=$sPath/subCLogs/
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
                num=`ssh -p $sshPort $rootusr@$ip "cat ${remote_dir}/${subCFName}|wc -l"`
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
   msg=$1
   reportPath=$sPath/subCContinueLogs/
   reportLog $reportPath $msg
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
                num=`ssh -p $sshPort $rootusr@$ip "cat ${remote_dir}/${subCFName}|wc -l"`
                if [ "$num" = "$subCNum" ];then
                        subCRsR=$(ssh -p $sshPort $rootusr@$ip "${remote_query} ${subRsCMD}")
                        break
                fi

                if [ "$queryNum" = "$querySubCount"  ];then
                        subCRsR=$(ssh -p $sshPort $rootusr@$ip "${remote_query} ${subRsCMD}")
                        break
                fi
                ((queryNum++))
                sleep $querySubGap
     done
     proNum=`echo $subCRsR|awk -F " " '{print $1}'`
     sesNum=`echo $subCRsR|awk -F " " '{print $2}'`
     reportLog $reportPath $ip $proNum $sesNum $subCNum
     sumPro=`expr $sumPro + $proNum`
     sumSes=`expr $sumSes + $sesNum`
  done

  if $localPcFlag;then 
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
     subCProNum=`echo $subCRs|awk -F " " '{print $1}'`
     subCSesNum=`echo $subCRs|awk -F " " '{print $2}'`
     reportLog $reportPath $localPcIP $subCProNum $subCSesNum $subCNum
     sumPro=`expr $sumPro + $subCProNum`
     sumSes=`expr $sumSes + $subCSesNum`
  fi

  len=${#ip_array[@]}
  if $localPcFlag;then
    len=`expr $len + 1`
  fi
  #多个客户端预期订阅/发布总数
  expectNum=`expr $len \* $subCNum`
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
   reportPath=$sPath/subCContinueLogs/
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
  done

  if $localPcFlag;then 
      i=0
      while true
      do
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
        sleep $querySubGap
     done
     subCProNum=`echo $subCRs|awk -F " " '{print $1}'`
     subCSesNum=`echo $subCRs|awk -F " " '{print $2}'`
     reportLog $reportPath $localPcIP $subCProNum $subCSesNum $zero
     sumPro=`expr $sumPro + $subCProNum`
     sumSes=`expr $sumSes + $subCSesNum`
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

#testcase 3
subCcontinue(){
 k=1
 spent=0

 #第一调用需创建账户
 if $localPcFlag;then
     subCLocal
 fi

 subCRemote
 msg="====================订阅后第${k}次查询订阅情况======================="
 subCQuContinue $msg
 pubC
 sleep $pubCWait 
 msg="====================取消订阅后第${k}次查询订阅情况===================="
 unsubCQuContinue $msg

 #后续调用不再创建账户
 while [ "$spent" -le "$subCTime" ]
 do
      ((k++))
       if $localPcFlag;then
         subCLoopNoAcc
       fi
       subCNoAccRemote
       msg="====================订阅后第${k}次查询订阅情况======================="
       subCQuContinue $msg
       pubCNoAcc
       sleep $pubCWait 
       msg="====================取消订阅后第${k}次查询订阅情况===================="
       unsubCQuContinue $msg
       sleep $subCGap
       spent=`expr $k \* $subCGap`
 done
}

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
     ssh -p $sshPort $rootusr@$ip "${remote_mqttClient} ${pubRCMD}"&
    ((step++))
 done
}

reportPubLog(){
  logPath=$1
  if [ "$#" = 2 ];then
    message=$2
    write_log $message
  else
        ipaddr=$2
        pubnum=$3
        expect=$4
        total="Client_$ipaddr:预期mosquitto_pub数为${expect}个，实际数${pubnum}个"
        pubrRs=""
        if [ "$pubnum" -lt "$expect" ];then
           pubrRs="Client_$ipaddr:实际上有${pubnum}个mosquitto_pub个,少于预期的${expect}个,相差`expr $expect - $pubnum`个"
        fi

  fi
  write_log $pubrRs
}

queryPubRLocal(){
 reportPath=${sPath}/pubRNumberLogs/
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
 reportPath=$sPath/pubRNumberLogs/
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
    done  
    reportPubLog $reportPath $ip $pubrNum $pubRNum 
 done 
}

subCRetain(){
 #step=1
 if $localPcFlag;then
    subCRLoop
 fi
 
 for ip in ${ip_array[*]}
 do
     # scp ${sPath}/mqtt.conf $rootusr@${ip}:${remote_dir}
     if [ "$ip" = "$localPcIP" ];then continue;fi
     #newStart=`expr $pubRsNum + $pubRNum \* $step`
     #ssh -p $sshPort $rootusr@$ip "sed -i 's/pubRsNum=${pubRsNum}/pubRsNum=${newStart}/g' ${remote_dir}/mqtt.conf"
     ssh -p $sshPort $rootusr@$ip "${remote_mqttClient} ${subCRCMD}"
     #((step++))
 done
}

querySubCR(){
 reportPath=$sPath/subCPubRLogs/  
 sum=0
 expectNum=0
 if $localPcFlag;then
    i=0
    while true
    do
      sleep $waitForSession
      subpubrNum=`cat ${sPath}/${subCPubRRecieved}|wc -l`  
      if [ "$subpubrNum" = "$pubRNum" ];then
         break
      fi
      
      if [ "$i" = "$querySubCount" ];then
        subpubrNum=`cat $sPath/$subCPubRRecieved`  
        break
      fi
     ((i++))
    done 
    msg="本地PC${localPcIP}预期收到保留消息${pubRNum},实际收到${subpubrNum}"
    reportPubLog $reportPath $msg
    sum=`expr $sum + $subpubrNum`
    expectNum=`expr $expectNum + $subpubrNum`
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
	 subpubrNum=`ssh -p $sshPort $rootusr@$ip "cat ${remote_dir}/${subCPubRRecieved}"`
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

subCPubR(){
 pubRetain
 queryPubRLocal
 queryPubRRemote
 subCRetain
 querySubCR
 stopRetainRemote
 stopSubPubR
}
 
