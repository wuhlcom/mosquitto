#!/bin/bash 
# send ssh cmd to run script of remote client  
#注意文件加载的顺序
sPath=`dirname $0`
#注释文件顺序
source $sPath/mqttClient.sh
source $sPath/logger.sh

rootusr="root" 
remote_dir="/home/zhilu/mosquitto/bash_mqtt"
remote_mqttClient=$remote_dir/mqttClient.sh
remote_query=$remote_dir/logger.sh

subCMD=subloop  
subRsCMD=subresult
subStopCMD=stopsubpub
subPubCMD=subpub
retainCMD=subpubretain
subCCMD=subcloop
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
reportLog(){
  logPath=$1
  if [ "$#" = 2 ];then
    message=$2
    write_log $message
  else 
	ipaddr=$2
	proNum=$3
	sesNum=$4 
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
 fi
}

#local pc sub
subLocal(){ 
  $sPath/mqttClient.sh ${subCMD}
}

#查询本地订阅结果
queryLocal(){
   proNum1=0
   sesNum1=0
   reportPath=$sPath/subLogs/
   sleep $waitForSession
   i=0
   while true
   do
     subLoopRs=`cat "${sPath}/${subFName}"`
     mqttSubNum=`echo $subLoopRs|awk -F " " '{print $3}'`
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
  proNum1=`echo $subRs|awk -F " " '{print $1}'`
  sesNum1=`echo $subRs|awk -F " " '{print $2}'`
  reportLog $reportPath $localPcIP $proNum1 $sesNum1
}

#本地订阅并记录结果
subQuLocal(){
 subLocal
 queryLocal
}

#本地下达指令让远程机器进行订阅
subRemote(){ 
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
queryRemote(){
 i=0
 sumPro1=0
 sumSes1=0
 reportPath=$sPath/subLogs/
 for ip in ${ip_array[*]}
  do
    #排除本地IP
    if [ "$ip" = "$localPcIP" ];then continue;fi
    while true
    do
      sleep $waitForSession
      subResult=`ssh -p $sshPort $rootusr@$ip "cat ${remote_dir}/${subFName}"`
      pcSubNum=`echo $subResult|awk -F " " '{print $3}'`
      #订阅完成则查询订阅结果
      if [ "$pcSubNum" = "$subNum" ];then
         subRs=$(ssh -p $sshPort $rootusr@$ip "${remote_query} ${subRsCMD}")
         break
      fi
      ((i++))
      #订阅超时后也要订阅结果
      if [ "$i" = 10 ];then
        subRs=$(ssh -p $sshPort $rootusr@$ip "${remote_query} ${subRsCMD}")
	break
      fi
   done
   proNum=`echo $subRs|awk -F " " '{print $1}'`
   sesNum=`echo $subRs|awk -F " " '{print $2}'`
   reportLog $reportPath $ip $proNum $sesNum
   sumPro1=`expr $sumPro1 + $proNum`   
   sumSes1=`expr $sumSes1 + $sesNum`   
 done
 len=${#ip_array[@]}
 #多个客户端预期订阅/发布总数
 expectNum=`expr $len \* $subNum`

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
        reportLog $reportPath $ip $proNum $sesNum
        if $localPcFlag;then
	    subRsLocal=$(${local_query} ${subRsCMD})
            proNumLocal=`echo $subRsLocal|awk -F " " '{print $1}'`
            sesNumLocal=`echo $subRsLocal|awk -F " " '{print $2}'`
            reportLog $reportPath $localPcIP $proNum $sesNum
            proNum=`expr $proNum + $proNumLocal`
            sesNum=`expr $sesNum + $sesNumLocal`
        fi
        sumPro2=`expr $sumPro2 + $proNum`   
        sumSes2=`expr $sumSes2 + $sesNum`   
    done
   
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
  queryRemote
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
       	session_num=`cat ${sPath}/${subPubFName}|wc -l`
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
   reportLog $reportPath $localPcIP $proNum $sesNum
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
           	session_num=`ssh -p $sshPort $rootusr@$ip "cat ${remote_dir}/${subPubFName}|wc -l"`
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
	    reportLog $reportPath $ip $proNum $sesNum
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
   subPubRetain
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
           	num=`cat ${sPath}/${subPubRFName}|wc -l`
	        if [ "$pubRetainNum" =  "$num" ];then
		        retainRs="执行PC${localPcIP}预期订阅到保留消息数为$pubRetainNum,实际数量为$num"
    		        break 
		fi

		((queryNum++))
                if [ "$queryNum" = "$querySubCount"  ];then
		 	break
		fi
              	sleep $querySubGap
       done
       reportLog $reportPath $retainRs
       if [ "$pubRetainNum" -ne "$num" ];then
         diffvalue=`expr $pubRetainNum - $num`
         retainRs="执行PC${localPcIP}预期订阅到保留消息数为$pubRetainNum,实际数量为$num,相差${diffvalue}"
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
	    retainNewStart=`expr $pubRsNum + $pubRetainNum \* $step`
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
           	num=`ssh -p $sshPort $rootusr@$ip "cat ${remote_dir}/${subPubRFName}|wc -l"`
            	if [ "$num" = "$pubRetainNum" ];then
		        retainRsR="远程PC${ip}预期订阅到保留消息数为$pubRetainNum,实际数量为$num"
    		        break 
		fi

		((queryNum++))
                if [ "$queryNum" = "$querySubCount"  ];then
		 	break
		fi
              	sleep $querySubGap
	    done

            reportLog $reportPath $retainRsR
	    if [ "$pubRetainNum" -ne "$num" ];then
            	diffvalue=`expr $pubRetainNum - $num`
		retainRsR="远程PC${ip}预期订阅到保留消息数为$pubRetainNum,实际数量为$num,相差${diffvalue}"
	        reportLog $reportPath $retainRsR
	    fi

	    #统计所有pc的会话数
	    sum=`expr $sum + $num`
	done
 
        len=${#ip_array[@]} 
        #多个客户端预期订阅/发布总数
        expectNum=`expr $len \* $pubRetainNum`

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
subCQueryLocal(){
  reportPath=$sPath/subCLogs/
  subCProNum=0 
  subCSesNum=0
  i=0
  while true
  do
	subCCount=`cat "${sPath/${subCFName}}"`
	if [ "$subCCount" = "$subCNum" ];then
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
  reportLog $reportPath $localPcIP $subCProNum $subCSesNum
}
#一次性订阅和查询
subCQueryLocal(){
 subCLocal
 subCQueryLocal
}
#远程一性订阅
subCRemote(){
   step=1
   for ip in ${ip_array[*]}
   do
     if [ "$ip" = "$localPcIP" ];then continue;fi
     newStart=`expr $subCsNum + $subCNum \* $step`
     #修改远程客户机创建客户端的范围
     ssh -p $sshPort $rootusr@$ip "sed -i 's/subCsNum=${subCsNum}/subCsNum=${newStart}/g' ${remote_dir}/mqtt.conf"
     #远程客户机进行订阅
     ssh -p $sshPort $rootusr@$ip "${remote_mqttClient} ${subCCMD}"&
     sleep $waitForSession
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
     reportLog $reportPath $ip $proNum $sesNum
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

subCRepeat(){
 while [ "subC" ]
 do
         subCQLocal
	 subCQRemote
	 pubC 
 done
}

 
