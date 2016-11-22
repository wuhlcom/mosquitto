#!/bin/bash 
# send ssh cmd to run script of remote client  

sPath=`dirname $0`
source $sPath/logger.sh
logPath=$sPath/clogs/
source $sPath/mqtt.conf
#ip_array=("192.168.10.164")  
user="zhilu" 
rootusr="root" 
remote_dir="/home/${user}/mosquitto/bash_mqtt"
remote_sub=$remote_dir/mqttClient.sh
subCMD=mqttsub  
subRsCMD=subresult 
sshPort=22
#subNum=2
subRs="0 0"
#每台客户机命令发下成功后等待间隔
waitForSession=50
localPcFlag=false
localIntf=eth0
localPcIP=`ip a|grep "inet\s*192.168.10.*$localIntf"|awk -F " " '{print $2}'|sed 's/\/24//g'`
local_query_sub=$sPath/logger.sh

subLog(){  
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
      subRs=$(${local_query_sub} ${subRsCMD})
      break
    fi
    ((i++))
    #订阅超时后也要订阅结果
    if [ "$i" = 10 ];then
        subRs=$(${local_query_sub} ${subRsCMD})
	break
    fi
    sleep 5
  done
  proNum=`echo $subRs|awk -F " " '{print $1}'`
  sesNum=`echo $subRs|awk -F " " '{print $2}'`
  subLog $localPcIP $proNum $sesNum
}

localSQ(){
 localSub
 localQuery
}
#本地通过ssh执行远程服务器的脚本 
remoteSub(){ 
for ip in ${ip_array[*]}  
do 
    #if IP is same as local ip,continue
    if [ "$ip" = "$localPcIP" ];then continue;fi
    scp ${sPath}/mqtt.conf root@${ip}:${remote_dir} 
    # ssh -t -p $sshPort $user@$ip "$remote_sub"&
    ssh -p $sshPort $rootusr@$ip "${remote_sub} ${subCMD}"&
    sleep $waitForSession 
done  
}

#查询远程订阅结果
remoteQuery(){
 query_sub=$remote_dir/logger.sh
 i=0
 for ip in ${ip_array[*]}
  do
    if [ "$ip" = "$localPcIP" ];then continue;fi
    while true
    do
       subLoop=`ssh -p $sshPort $rootusr@$ip "cat ${remote_dir}/mqttSubNum"`
       mqttSubNum=`echo $subLoop|awk -F " " '{print $3}'`
       #订阅完成则查询订阅结果
       if [ "$mqttSubNum" = "$subNum" ];then
          subRs=$(ssh -p $sshPort $rootusr@$ip "${query_sub} ${subRsCMD}")
         break
      fi
      ((i++))
      #订阅超时后也要订阅结果
      if [ "$i" = 10 ];then
        subRs=$(ssh -p $sshPort $rootusr@$ip "${query_sub} ${subRsCMD}")
	break
      fi
      sleep 5
   done
   proNum=`echo $subRs|awk -F " " '{print $1}'`
   sesNum=`echo $subRs|awk -F " " '{print $2}'`
   subLog $ip $proNum $sesNum
 done
}

remoteSQ(){
 remoteSub
 remoteQuery
}
