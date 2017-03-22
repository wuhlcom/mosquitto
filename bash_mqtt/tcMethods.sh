#!/bin/bash
#auth:wuhongliang
#date:2016-12-18
cuPath=`dirname $0`
reportsPath=$cuPath/reports
source $cuPath/centerControl.sh
#testcase 1
#订阅指定数量，测试服务端最大支持订阅数
subAll(){
      #  proNum1=0
      #  sesNum1=0
        sumPro1=0
        sumSes1=0
	subQuRemote
        if $localPcFlag;then
                subQuLocal
                expectNum=`expr $expectNum + $subNum`
        fi
        sleep $waitForSession
        #records用来保存查询到的会话和进程的详细信息
	local logDir="${reportsPath}/subAll/subAllRecords"
        local logDirRemote="${remoteReportsDir}/subAll/subAllRecords"
        subProcess $logDir subAll
        subSession $logDir subAll
 	for ip in ${ip_array[*]}
	do
	   ssh -p $sshPort $rootusr@$ip "${remote_query} subprocess ${logDirRemote} subAll"
	   ssh -p $sshPort $rootusr@$ip "${remote_query} subsession ${logDirRemote} subAll"
	done
	stopSpecScript
        stopSubRemote
        if $localPcFlag;then
                stopSub
                sleep $waitForSession
        fi  

        local sumProAll=`expr $proNum1 + $sumPro1`
        local sumSesAll=`expr $sesNum1 + $sumSes1`
        if [ "$sumProAll" = "$expectNum" ];then
           local rs="预期订阅总process数为$expectNum,实际数量为$sumProAll"
        else
           local value=`expr $expectNum - $sumProAll`
           local rs="预期订阅总process数为$expectNum,实际数量为$sumProAll,相差${value}"
        fi  
        reportLog $reportPath $rs 
  
        if [ "$sumSesAll" = "$expectNum" ];then
           local rs="预期订阅总session数为$expectNum,实际数量为$sumSesAll"
        else
           local value=`expr $expectNum - $sumSesAll`
           local rs="预期订阅总session数为$expectNum,实际数量为$sumSesAll,相差${value}"
        fi  
        reportLog $reportPath $rs 
}

#testcase 2
#长期订阅，订阅后不停的查询线程和会话
#在规定的时间内线程和会话数与预期的一直一致
subAllContinue(){
        proNum2=0
        sesNum2=0
        sumPro2=0
        sumSes2=0
	subRemote&
        sleep $subWait
        if $localPcFlag;then
                subLocal
                sleep $subWait
        fi
        local logDir="${reportsPath}/subAllContinue/subAllContinueRecords"
        local logDirRemote="${remoteReportsDir}/subAllContinue/subAllContinueRecords"
        subProcess $logDir subAllcon
        subSession $logDir subAllcon
 	for ip in ${ip_array[*]}
	do
	   ssh -p $sshPort $rootusr@$ip "${remote_query} subprocess ${logDirRemote} subAllcon"
	   ssh -p $sshPort $rootusr@$ip "${remote_query} subsession ${logDirRemote} subAllcon"
	done
        queryContinue 
	stopSpecScript
        stopSubRemote
        if $localPcFlag;then
                stopSub
                sleep $waitForSession
        fi  
}

#testcase 3
#单次订阅，发布，断开
#反复操作5分钟
#每一轮要求订阅数(进程和会话数)，发布后收到消息数，断开数要与预期一致
subCContinue(){
 local k=1
 local reportPath=${reportsPath}/subCContinue/subCContinueSessionLogs/
 #第一次调用需创建账户
 subCRemote&
 if $localPcFlag;then
     subCLocal
 fi
 sleep $subCWait 

 local msg="====================订阅后第${k}次查询订阅情况======================="
 subCQuContinue $msg $reportPath $subCFName $subCNum
 pubC
 sleep $subCGap 
 msg="====================取消订阅后第${k}次查询订阅情况===================="
 unsubCQuContinue $msg $reportPath
 sleep $subCGap 
 #后续调用不再创建账户
 while [ "$k" -le "$subCTimes" ]
 do
      ((k++))
       #远程订阅
       subCNoAccRemote
       #本地订阅
       if $localPcFlag;then
         subCLoopNoAcc&
       fi
       sleep $subCWait 
       msg="====================订阅后第${k}次查询订阅情况======================="
       subCQuContinue $msg $reportPath $subCFName $subCNum 
       local rsSub=$?	 
	   if [ "$rsSub" = "1" ];then 	     
	     break; 
	   fi
       #发布，发布后会自动断开订阅，此操作相当于取消订阅
       pubCNoAcc
       sleep $subCGap
       msg="====================取消订阅后第${k}次查询订阅情况===================="
       unsubCQuContinue $msg $reportPath
       local rsUn=$?
       if [ "$rsUn" = "1" ];then 	     
	     break; 
       fi
       sleep $subCGap
 done
 stopSpecScript
 stopSubRemote
 if $localPcFlag;then
      stopSub
 fi  
}

#testcase 4
#多台机器同时长期订阅，订阅后多台机器同时不停发布消息
#直到收到消息数达到预期目标或执行超时才停止
subFixAll(){
        local subFixSessionLogPath=$reportsPath/subFixAll/subFixAllSessionLogs/
        local subFixMsgLogPath=$reportsPath/subFixAll/subFixAllMsgLogs/
	local count=1
        local realNum=0
        local skipTime=0
        subFixRemote&
        if $localPcFlag;then
                subFixLocal
 		queryLocal $subFixSessionLogPath $subFixFName $subFixNum
        fi
        sleep $subFixWait
        queryRemote $subFixSessionLogPath $subFixFName $subFixNum

        while true 
        do
          pubFixRemote
          pubFixLocal
          sleep $puballwaittime
          msg="=============第${count}次查询订阅消息结果=============="
          realNum=`queryFixMsgNum $subFixMsgLogPath $msg $subFixRecieved $subFixCount`
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

        stopSpecScript
        stopSubRemote
        if $localPcFlag;then
          stopSub
        fi
}

#testcase 5
#多台机器发布大量的保留消息
#每条消息都是唯一
#多台机器分别自己这台机器发布的保留消息
#使用一次性订阅，不停的订阅保留消息直到所有保留消息都订阅完成
#统计收到的保留消息总数以判断是否正常
subCPubR(){
 #发布保留消息
 pubRetain
 sleep $pubRWait
 #查询发布情况
 queryPubRLocal
 queryPubRRemote
 #订阅保留消息
 subCRetain
 sleep $pubRWait
 #查询收到保留消息数量
 querySubCR
 sleep $waitForSession
 #停止远程订阅和删除保留消息
 stopRetainRemote
 #停止本地订阅和删除保留消息
 stopSpecScript
 stopSubPubR
}

#testcase 6
#创建账户，一次性订阅发布断开
#测试点主要观察每一次循环订阅-发布-断开时
#订阅数，发布后收到消息数，断开数是要与预期的一致
#订阅-发布-断开
#统计每一轮会话数
#统计每一轮收到消息数
#统计收到总的消息数
subCReContinue(){
  #会话统计
  local subCReSessionPath=${reportsPath}/subCReContinue/subCReContinueSessionLogs/
  #消息统计
  local subCReMsgPath=${reportsPath}/subCReContinue/subCReContinueMsgLogs/
  #总的消息统计
  local subCReMsgAllPath=${reportsPath}/subCReContinue/subCReContinueMsgAllLogs/
  local k=1
  local spent=0
  local totalMsgNum=0
  #第一次调用需创建账户
  subCReRemote
  if $localPcFlag;then
     subCReLoop
  fi
  #订阅后等待
  sleep $subCReWait
  local msg="====================订阅后第${k}次查询订阅情况======================="
  subCQuContinue $msg $subCReSessionPath $subCReFName $subCReNum

  pubCRe 
  #发布消息后等待
  sleep $subCReGap
  msg="=============取消订阅后第${k}次查询订阅情况===================="
  unsubCQuContinue $msg $subCReSessionPath
  totalMsgNum=`queryMsgNum $subCReMsgPath $msg $subCReRecieved $subCReNum`
  msg="===============第${k}次统计收到消息总数为${totalMsgNum}================"
  reportLog $subCReMsgAllPath $msg

  #后续调用不再创建账户
  #while [ "$spent" -le "$subCReTime" ]
  while [ "$k" -le "$subCReTimes" ]
  do
      ((k++))
       #远程订阅
       subCReNoAccRemote
        #本地订阅
       if $localPcFlag;then
         subCReLoopNoAcc
       fi
       msg="====================订阅后第${k}次查询订阅情况======================="
       sleep $subCReWait
       #查询订阅情况
       subCQuContinue $msg $subCReSessionPath $subCReFName $subCReNum
       #发布，发布后会自动断开订阅，此操作相当于取消订阅
       pubCReNoAcc
       sleep $subCReGap

       totalMsgNum=`queryMsgNum $subCReMsgPath $msg $subCReRecieved $subCReNum`
       msg="===============第${k}次统计收到消息总数为${totalMsgNum}==============="
       reportLog $subCReMsgAllPath $msg

       msg="===============取消订阅后第${k}次查询订阅情况===================="
       unsubCQuContinue $msg $subCReSessionPath
  #    spent=`expr $k \* \( $subCReGap + $subCReWait \)`
  done
  stopSpecScript
  stopSubRemote
  if $localPcFlag;then
      stopSub
  fi  
}

#testcase 7
#使用单身证书来认证
subCa(){
   sumPro1=0
   subSes1=0
   local logDir="${reportsPath}/subCa/subCaRecords"
   local logDirRemote="${remoteReportsDir}/subCa/subCaRecords"
   local expTotalNum=0
   subCaAuthQuRemote
   if $localPcFlag;then
	subCaAuthQuLocal
	expTotalNum=`expr $expectNum + $subCaNum`
   fi
   sleep $waitForSession
   subProcess $logDir subCa
   subSession $logDir subCa $srv_ip $caPort

   for ip in ${ip_array[*]}
   do
	ssh -p $sshPort $rootusr@$ip "${remote_query} subprocess ${logDirRemote} subCa"   
	ssh -p $sshPort $rootusr@$ip "${remote_query} subsession ${logDirRemote} subCa $srv_ip $caPort"   
   done
   sumProAll=`expr $proNum1 + $sumPro1`
   sumSesAll=`expr $sesNum1 + $sumSes1`

   if [ "$sumProAll" = "$expTotalNum" ];then
       	rs="预期订阅总process数为$expTotalNum,实际数量为$sumProAll"
   else
       	value=`expr $expTotalNum - $sumProAll`
       	rs="预期订阅总process数为$expTotalNum,实际数量为$sumProAll,相差${value}"
   fi
   reportLog $reportPath $rs

   if [ "$sumSesAll" = "$expectNum" ];then
       	rs="预期订阅总session数为$expTotalNum,实际数量为$sumSesAll"
   else
       	value=`expr $expTotalNum - $sumSesAll`
       	rs="预期订阅总session数为$expTotalNum,实际数量为$sumSesAll,相差${value}"
   fi
   reportLog "${reportPath}" "${rs}"
   
   local x=1
   local sleepTimes=0
   while [ "$sleepTimes" -le "$subCaQueryTime" ]
   do
	sleep $subCaGapTime 
        ((x++))
        local msg="============================================================="
        reportLog "${reportPath}" "${msg}"
        sleepTimes=`expr $subCaGapTime \* $x`
        queryLocal $subCaLogPath $subCaFName $subCaNum $srv_ip $caPort
     	queryRemote $subCaLogPath $subCaFName $subCaNum $srv_ip $caPort

	sumProAll=`expr $proNum1 + $sumPro1`
        sumSesAll=`expr $sesNum1 + $sumSes1`
        if [ "$sumProAll" = "$expTotalNum" ];then
                rs="预期订阅总process数为$expTotalNum,实际数量为$sumProAll"
        else
                value=`expr $expTotalNum - $sumProAll`
                rs="预期订阅总process数为$expTotalNum,实际数量为$sumProAll,相差${value}"
        fi
        reportLog $reportPath $rs

        if [ "$sumSesAll" = "$expTotalNum" ];then
                rs="预期订阅总session数为$expTotalNum,实际数量为$sumSesAll"
        else
                value=`expr $expTotalNum - $sumSesAll`
                rs="预期订阅总session数为$expTotalNum,实际数量为$sumSesAll,相差${value}"
        fi
   	reportLog $reportPath $rs
   done
 
   stopSpecScript
   stopSubRemote
   if $localPcFlag;then
       	stopSub
       	sleep $waitForSession
   fi
}

#testcase 11
#订阅单个主题，推送大量消息
subCaATopic(){
  local subCaLogPath=$reportsPath/subCaATopic/subCaATopicMsgLogs/
  nulog=${recordsPath}/${pubCaATopicFName}
  : > $nulog
  subCaTopic
  createAccount $pubCaATopicIDPre  $pubCaATopicSNum $pubCaATopicENum "${intf}-${cIP}-pubCaATopic"
  for i in `seq $pubCaATopicSNum $pubCaATopicENum`
  do
      local pubAMsg=${pubCaATopicMsgPre}${i}
      local pubAID=${pubCaATopicIDPre}${i}
      pub $subCaATopic $pubAMsg $pubAID $pubCaATopicQos $defaultUsr $defaultPasswd $auType
      #发布消息过快，服务端处理不过来
      sleep 0.3
      local count=`expr $i - $pubCaATopicSNum + 1`
      echo  $count > $nulog
      if [ `expr $count % $pubCaQueryNum` = 0 ];then
        sleep $pubCaQueryWait
        queryMsg $subCaLogPath $count $pubCaATopicFName $subCaATopicRecieved $localPcIP
      fi
  done
  stopSub
  sleep $waitForSession
  stopSpecScript
}

#testcase 9
#不同客户端订阅不同主题并发布不同主题的消息
subPubCCa(){
  subCCaSessionLog=$reportsPath/subPubCCa/subPubCCaSessionLogs/
  subCCaMsgLog=$reportsPath/subPubCCa/subPubCCaMsgLogs/
  local p=1
  local length=0
  local expTotalNum=$subCCaNum
  sumPro1=0
  sumSes1=0
  if [ -n "$ip_array" ];then
     length=${#ip_array[*]}
  fi

  if [ "$length" -ne "0" ];then
      subCCaRemote $subCCaSNum $subCCaNum
      expTotalNum=`expr \( $length + 1 \) \*  $subCCaNum`
  fi
  subCCa
  sleep $subCCaWait

  if [ "$length" -ne "0" ];then
     queryRemote $subCCaSessionLog $subCCaFName $subCCaNum $srv_ip $caPort
  fi
  queryLocal $subCCaSessionLog $subCCaFName $subCCaNum $srv_ip $caPort

  ##########################################
  local sumProAll=`expr $proNum1 + $sumPro1`
  local sumSesAll=`expr $sesNum1 + $sumSes1`
  local submsg="=========第${p}次查询订阅情况======="
  reportLog $subCCaSessionLog $submsg
  if [ "$sumProAll" = "$expTotalNum" ];then
         rs="预期订阅总process数为$expTotalNum,实际数量为$sumProAll"
  else
      value=`expr $expTotalNum - $sumProAll`
         rs="预期订阅总process数为$expTotalNum,实际数量为$sumProAll,相差${value}"
  fi
  reportLog $subCCaSessionLog $rs

  if [ "$sumSesAll" = "$expTotalNum" ];then
        rs="预期订阅总session数为$expTotalNum,实际数量为$sumSesAll"
  else
     value=`expr $expTotalNum - $sumSesAll`
        rs="预期订阅总session数为$expTotalNum,实际数量为$sumSesAll,相差${value}"
  fi
  reportLog $subCCaSessionLog $rs
  ##########################################

  if [ "$length" -ne "0" ];then
     pubCCaRemote
  fi
  pubCCa
  sleep $pubCCaWait

  local msg="=========第${p}次查询收到消息情况======="
  queryMsgNum $subCCaMsgLog $msg $subCCaRecieved $subCCaNum
  p=`expr $p + 1` 
  while [ "$p" -le "$subPubCCaTimes" ]
  do
    if [ "$length" -ne "0" ];then
       subCCaNoAccRemote
    fi
    subCCaNoAcc
    sleep $subCCaWait

    if [ "$length" -ne "0" ];then
        queryRemote $subCCaSessionLog $subCCaFName $subCCaNum $srv_ip $caPort
    fi
    queryLocal $subCCaSessionLog $subCCaFName $subCCaNum $srv_ip $caPort

  ##########################################
  sumProAll=`expr $proNum1 + $sumPro1`
  sumSesAll=`expr $sesNum1 + $sumSes1`
  local submsg="=========第${p}次查询订阅情况======="
  reportLog $subCCaSessionLog $submsg
  if [ "$sumProAll" = "$expTotalNum" ];then
         rs="预期订阅总process数为$expTotalNum,实际数量为$sumProAll"
  else
      value=`expr $expTotalNum - $sumProAll`
         rs="预期订阅总process数为$expTotalNum,实际数量为$sumProAll,相差${value}"
  fi
  reportLog $subCCaSessionLog $rs

  if [ "$sumSesAll" = "$expTotalNum" ];then
        rs="预期订阅总session数为$expTotalNum,实际数量为$sumSesAll"
  else
     value=`expr $expTotalNum - $sumSesAll`
        rs="预期订阅总session数为$expTotalNum,实际数量为$sumSesAll,相差${value}"
  fi
  reportLog $subCCaSessionLog $rs
  ##########################################

    if [ "$length" -ne "0" ];then
       pubCCaNoAccRemote
    fi
    pubCCaNoAcc
    sleep $pubCCaWait

    msg="=========第${p}次查询收到消息情况======="
    queryMsgNum $subCCaMsgLog $msg $subCCaRecieved $subCCaNum
    ((p++))
  done 
  stopSpecScript
  sleep $waitForSession
  if [ "$length" -ne "0" ];then
 	stopSubRemote
  fi
  stopSub
}

#testcase 10
subPubCaCon(){
  subCaConSessionLog=$reportsPath/subPubCaCon/subPubCaConSessionLogs/
  subCaConMsgLog=$reportsPath/subPubCaCon/subPubCaConMsgLogs/
  local p=1
  local length=0
  local expTotalNum=$subCaConNum
  sumPro1=0
  sumSes1=0
  if [ -n "$ip_array" ];then
     length=${#ip_array[*]}
  fi

  if [ "$length" -ne "0" ];then
      subCaConRemote $subCaConSNum $subCaConNum
      expTotalNum=`expr \( $length + 1 \) \*  $subCaConNum`
  fi
  subCaCon
  sleep $subCaConWait

  if [ "$length" -ne "0" ];then
     queryRemote $subCaConSessionLog $subCaConFName $subCaConNum $srv_ip $caPort
  fi
  queryLocal $subCaConSessionLog $subCaConFName $subCaConNum $srv_ip $caPort
 
  ##########################################
  local sumProAll=`expr $proNum1 + $sumPro1`
  local sumSesAll=`expr $sesNum1 + $sumSes1`
  if [ "$sumProAll" = "$expTotalNum" ];then
         rs="预期订阅总process数为$expTotalNum,实际数量为$sumProAll"
  else
      value=`expr $expTotalNum - $sumProAll`
         rs="预期订阅总process数为$expTotalNum,实际数量为$sumProAll,相差${value}"
  fi
  reportLog $subCaConSessionLog $rs

  if [ "$sumSesAll" = "$expTotalNum" ];then
        rs="预期订阅总session数为$expTotalNum,实际数量为$sumSesAll"
  else
     value=`expr $expTotalNum - $sumSesAll`
        rs="预期订阅总session数为$expTotalNum,实际数量为$sumSesAll,相差${value}"
  fi
  reportLog $subCaConSessionLog $rs
  ############################################
  #创建远程发布消息的客户端账户
  if [ "$length" -ne "0" ];then
	pubCaConAccRemote
  fi
  #为本机上的客户端创建账户
  pubCaConAcc
  sleep $pubCaConWait

  ###开始循环发布消息 
  while [ "$p" -le "$subPubCaConTimes" ]
  do
    #清除旧的消息
    : > $recordsPath/$subCaConRecieved
    if [ "$length" -ne "0" ];then
       ssh -p $sshPort $rootusr@$ip ": > ${remote_dir}/${subCaConRecieved}"
    fi

    #发布消息
    if [ "$length" -ne "0" ];then
       pubCaConNoAccRemote
    fi
    pubCaConNoAcc
    sleep $pubCaConWait

    #查询结果
    local msg="=========第${p}次查询收到消息情况======="
    queryMsgNum $subCaConMsgLog $msg $subCaConRecieved $subCaConNum
    ((p++))
  done

  stopSpecScript
  if [ "$length" -ne "0" ];then
        stopSubRemote
  fi
  stopSub
}

#testcase 8
subPubCaMu(){
  subPubCaMuSessionLog=$reportsPath/subPubCaMu/subPubCaMuSessionLogs/
  subPubCaMuMsgLog=$reportsPath/subPubCaMu/subPubCaMuMsgLogs/
  local p=1
  local length=0
  #单台PC会话数
  local expProNum=`expr $subCaMuCNum \* $subCaMuTopicNum`
  #多台PC会话总数 
  local expTotalNum=$expProNum 
  sumPro1=0
  sumSes1=0
  if [ -n "$ip_array" ];then
     length=${#ip_array[*]}
  fi

  #远程订阅
  if [ "$length" -ne "0" ];then
      subCaMuRemote $subCaMuTopicPre $subCaMuCIDPre $pubCaMuIDPre $pubCaMuMsgPre
      expTotalNum=`expr \( $length + 1 \) \*  $expProNum`
  fi
  #本地订阅
  subCaMu
  sleep $subCaMuWait
 
  #查询订阅情况
  if [ "$length" -ne "0" ];then
     queryRemote $subPubCaMuSessionLog $subCaMuFName $expProNum $srv_ip $caPort
  fi
  queryLocal $subPubCaMuSessionLog $subCaMuFName $expProNum $srv_ip $caPort

  ##################################################################
  local sumProAll=`expr $proNum1 + $sumPro1`
  local sumSesAll=`expr $sesNum1 + $sumSes1`
  if [ "$sumProAll" = "$expTotalNum" ];then
         rs="预期订阅总process数为$expTotalNum,实际数量为$sumProAll"
  else
      value=`expr $expTotalNum - $sumProAll`
         rs="预期订阅总process数为$expTotalNum,实际数量为$sumProAll,相差${value}"
  fi
  reportLog $subPubCaMuSessionLog $rs

  if [ "$sumSesAll" = "$expTotalNum" ];then
        rs="预期订阅总session数为$expTotalNum,实际数量为$sumSesAll"
  else
     value=`expr $expTotalNum - $sumSesAll`
        rs="预期订阅总session数为$expTotalNum,实际数量为$sumSesAll,相差${value}"
  fi
  reportLog $subPubCaMuSessionLog $rs
  ####################################################################

  #发布消息
  if [ "$length" -ne "0" ];then
    pubCaMuAccRemote
  fi
  pubCaMuAcc
  sleep $pubCaMuWait

  ######开始循环发布消息 
  while [ "$p" -le "$subPubCaMuTimes" ]
  do
    #清除旧的消息
    : > $recordsPath/$subCaMuRecieved
    if [ "$length" -ne "0" ];then
       ssh -p $sshPort $rootusr@$ip ": > ${remote_dir}/${subCaMuRecieved}"
    fi

    #发布消息
    if [ "$length" -ne "0" ];then
       pubCaMuNoAccRemote
    fi
    pubCaMuNoAcc
    sleep $pubCaMuWait

    #查询结果
    local msg="=========第${p}次查询收到消息情况======="
    queryMsgNum $subPubCaMuMsgLog $msg $subCaMuRecieved $expProNum
    ((p++))
  done

  stopSpecScript
  if [ "$length" -ne "0" ];then
        stopSubRemote
  fi
  stopSub
  sleep $waitForSession
}
