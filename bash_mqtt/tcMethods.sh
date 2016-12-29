#!/bin/bash
#auth:wuhongliang
#date:2016-12-18
cuPath=`dirname $0`
source $cuPath/centerControl.sh
#testcase 1
#订阅指定数量，测试服务端最大支持订阅数
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
        sleep $waitForSession
        stopSubRemote
        if $localPcFlag;then
                stopSub
                sleep $waitForSession
		stopSpecScript
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
#长期订阅，订阅后不停的查询线程和会话
#在规定的时间内线程和会话数与预期的一直一致
subAllContinue(){
        proNum2=0
        sesNum2=0
        sumPro2=0
        sumSes2=0
	subRemote
        sleep $subWait
        if $localPcFlag;then
                subLocal
                sleep $subWait
        fi
        queryContinue 
        stopSubRemote
        if $localPcFlag;then
                stopSub
                sleep $waitForSession
		stopSpecScript
        fi  
}

#testcase 3
#单次订阅，发布，断开
#反复操作5分钟
#每一轮要求订阅数(进程和会话数)，发布后收到消息数，断开数要与预期一致
subCcontinue(){
 k=1
 spent=0
 reportPath=${sPath}/subCContinueSessionLogs/

 #第一次调用需创建账户
 if $localPcFlag;then
     subCLocal
 fi
 subCRemote
 sleep $subCWait 

 msg="====================订阅后第${k}次查询订阅情况======================="
 subCQuContinue $msg $reportPath $subCFName $subCNum
 pubC
 sleep $subCGap 
 msg="====================取消订阅后第${k}次查询订阅情况===================="
 unsubCQuContinue $msg $reportPath

 #后续调用不再创建账户
 while [ "$spent" -le "$subCTime" ]
 do
      ((k++))
       if $localPcFlag;then
         #本地订阅
         subCLoopNoAcc
       fi
       #远程订阅
       subCNoAccRemote
       sleep $subCWait 
       msg="====================订阅后第${k}次查询订阅情况======================="
       #查询
       subCQuContinue $msg $reportPath $subCFName $subCNum
       #发布，发布后会自动断开订阅，此操作相当于取消订阅
       pubCNoAcc
       msg="====================取消订阅后第${k}次查询订阅情况===================="
       unsubCQuContinue $msg $reportPath
       spent=`expr $k \* $subCGap`
 done
 stopSubRemote
 if $localPcFlag;then
      stopSub
      stopSpecScript
 fi  
}

#testcase 4
#多台机器同时长期订阅，订阅后多台机器同时不停发布消息
#直到收到消息数达到预期目标或执行超时才停止
subFixAll(){
        subFixSessionLogPath=$sPath/subFixSessionLogs/
        subFixMsgLogPath=$sPath/subFixMsgLogs/
	count=1
        realNum=0
        skipTime=0
        subFixRemote
        sleep $subFixWait
        if $localPcFlag;then
                subFixLocal
                sleep $subFixWait
 		queryLocal $subFixSessionLogPath $subFixFName $subFixNum
        fi
        queryRemote $subFixSessionLogPath $subFixFName $subFixNum

       while true 
       do
         pubFixLocal
         pubFixRemote
         sleep $WaitForSession
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

      stopSubRemote
      if $localPcFlag;then
          stopSub
          stopSpecScript
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
 stopSubPubR
 stopSpecScript
}

#testcase 6
#创建账户，一次性订阅发布断开
#测试点主要观察每一次循环订阅-发布-断开时
#订阅数，发布后收到消息数，断开数是要与预期的一致
#订阅-发布-断开
#统计每一轮会话数
#统计每一轮收到消息数
#统计收到总的消息数
subCRecontinue(){
  #会话统计
  subCReSessionPath=${sPath}/subCReSessionLogs/
  #消息统计
  subCReMsgPath=${sPath}/subCReMsgLogs/
  #总的消息统计
  subCReMsgAllPath=${sPath}/subCReMsgAllLogs/
  k=1
  spent=0
  msgNum=0
  totalMsgNum=0
  #第一次调用需创建账户
  if $localPcFlag;then
     subCReLoop
     sleep $subCReWait
  fi
  subCReRemote
  sleep $subCReWait
  msg="====================订阅后第${k}次查询订阅情况======================="
  subCQuContinue $msg $subCReSessionPath $subCReFName $subCReNum

  pubCRe 
  sleep $subCReGap
  msg="=============取消订阅后第${k}次查询订阅情况===================="
  unsubCQuContinue $msg $subCReSessionPath
  totalMsgNum=`queryMsgNum $subCReMsgPath $msg $subCReRecieved $subCReNum`
  msg="======第${k}次统计收到消息总数为${totalMsgNum}======"
  reportLog $subCReMsgAllPath $msg

 #后续调用不再创建账户
 while [ "$spent" -le "$subCReTime" ]
 do
      ((k++))
       if $localPcFlag;then
         #本地订阅
         subCReLoopNoAcc
       fi
       #远程订阅
       subCReNoAccRemote
       msg="====================订阅后第${k}次查询订阅情况======================="
       #查询
       subCQuContinue $msg $subCReSessionPath $subCReFName $subCReNum
       #发布，发布后会自动断开订阅，此操作相当于取消订阅
       pubCReNoAcc
       sleep $subCGap

       totalMsgNum=`queryMsgNum $subCReMsgPath $msg $subCReRecieved $subCReNum`
       msg="======第${k}次统计收到消息总数为${totalMsgNum}======"
       reportLog $subCReMsgAllPath $msg

       msg="====================取消订阅后第${k}次查询订阅情况===================="
       unsubCQuContinue $msg $subCReSessionPath
       spent=`expr $k \* $subCReGap`
 done
 stopSubRemote
 if $localPcFlag;then
      stopSub
      stopSpecScript
 fi  
}
