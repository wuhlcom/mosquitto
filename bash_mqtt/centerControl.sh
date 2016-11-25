#!/bin/bash 
# send ssh cmd to run script of remote client  
#注意文件加载的顺序
sPath=`dirname $0`
source $sPath/mqttClient.sh
source $sPath/logger.sh

user="zhilu" 
rootusr="root" 
remote_dir="/home/${user}/mosquitto/bash_mqtt"
remote_mqttClient=$remote_dir/mqttClient.sh
remote_query=$remote_dir/logger.sh

subCMD=mqttsub  
subRsCMD=subresult
subStopCMD=stopsub
subPubCMD=subpub
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
  logPath=$sPath/rslogs/
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
  subRs="0 0"
  $sPath/mqttClient.sh ${subCMD}
  sleep $waitForSession
}

#查询本地订阅结果
localQuery(){
  i=0
   while true
   do
     subLoop=`cat "${sPath}/mqttSubNum"`
     mqttSubNum=`echo $subLoop|awk -F " " '{print $3}'`
     #订阅完成则查询订阅结果
     if [ "$mqttSubNum" = "$subNum" ];then
       subRs=$(${local_query} ${subRsCMD})
       break
     fi
     ((i++))
     #订阅超时后也要订阅结果
     if [ "$i" = 10 ];then
        subRs=$(${local_query} ${subRsCMD})
	break
     fi
     sleep 5
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
	    scp ${sPath}/mqtt.conf root@${ip}:${remote_dir} 
	    newStart=`expr $sSubNum + $subNum \* $step`
	    
	    ssh -p $sshPort $rootusr@$ip "sed -i 's/sSubNum=${sSubNum}/sSubNum=${newStart}/g' ${remote_dir}/mqtt.conf"
	    sleep 2
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
       subLoop=`ssh -p $sshPort $rootusr@$ip "cat ${remote_dir}/mqttSubNum"`
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
  remoteQuery
}

#停止远程订阅
stopRemoteSub(){
	for ip in ${ip_array[*]}  
	do 
	    #if IP is same as local ip,continue
	    if [ "$ip" = "$localPcIP" ];then continue;fi
	    ssh -p $sshPort $rootusr@$ip "${remote_mqttClient} ${subStopCMD}"&
	done  
}

mqttSubPubRemote(){
	sum=0
	for ip in ${ip_array[*]}  
	do 
	    #if IP is same as local ip,continue
	    if [ "$ip" = "$localPcIP" ];then continue;fi
	    ssh -p $sshPort $rootusr@$ip "${remote_mqttClient} ${subPubCMD}"&
            num=`ssh -p $sshPort $rootusr@$ip "cat ${remote_dir}/subPubMsgNum|wc -l"`
	   
            if [ "$num" -ne "$sub_pub_num" ];then
        	diffvalue=`expr $sub_pub_num- $snum`
	        pcrs="${ip}预期订阅/发布总数为$sub_pub_num,实际数量为$num,相差${diffvalue}\n"       
	    fi

	    sum=`expr $sum + $num` 
	    ssh -p $sshPort $rootusr@$ip "${remote_mqttClient} ${subStopCMD}"&
	done 
        len=${#ip_array[@]} 
        expectNum=`expr $len \* $sub_pub_num`
        if [ "$sum" = "$expectNum" ];then
	        rs="预期订阅/发布总数为$expectNum,实际数量为$sum\n"       
	else 
        	value=`expr $expectNum - $sum`
	        rs="预期订阅/发布总数为$expectNum,实际数量为$sum,相差${value}\n"        
	fi
}
#if $localPcFlag;then
#	localSQ
#	stopSubPub
#fi
#remoteSQ
#stopRemoteSub
