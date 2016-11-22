#!/bin/bash 
# send ssh cmd to run script of remote client  
ip_array=("192.168.10.164")  
user="zhilu" 
rootusr="root" 
remote_dir="/home/${user}/mosquitto/bash_mqtt"
remote_sub=$remote_dir/mqttClient.sh
cmd=mqttsub  
port=22
subNum=2
subRs="0 0"
#本地通过ssh执行远程服务器的脚本  
for ip in ${ip_array[*]}  
do  
    if [ $ip = "192.168.1.1" ]; then  
        port="7777"  
    fi  
    #指定某台机器去启动订阅
    # ssh -t -p $port $user@$ip "$remote_sub"&
    ssh -p $port $rootusr@$ip "${remote_sub} ${cmd}"&
    sleep 5 
done  
#:<<BLOCK'
query_sub=$remote_dir/logger.sh
cmd=subresult
i=0
for ip in ${ip_array[*]}
do
  while true
  do
    subLoop=`ssh -p $port $rootusr@$ip "cat ${remote_dir}/mqttSubNum"`
    mqttSubNum=`echo $subLoop|awk -F " " '{print $3}'`
    echo "====================="
    echo $mqttSubNum
    echo $subNum
    echo "===================="
    #订阅完成则查询订阅结果
    if [ "$mqttSubNum" = "$subNum" ];then
      subRs=$(ssh -p $port $rootusr@$ip "${query_sub} ${cmd}")
      break
    fi
    ((i++))
    echo $i
    #订阅超时后也要订阅结果
    if [ "$i" = 3 ];then
        subRs=$(ssh -p $port $rootusr@$ip "${query_sub} ${cmd}")
	break
    fi
    sleep 5
  done
done
proNum=`echo $subRs|awk -F " " '{print $1}'`
sesNum=`echo $subRs|awk -F " " '{print $2}'`

total="预期mosquitto_sub ${subNum}个，实际进程数${proNum}个，会话建立成功数${sesNum}"
echo $total
proRs=""
sesRs=""
if [ "$proNum" -lt "$subNum" ];then
   proRs="实际上有${proNum}个mosquitto_sub进程,少于预期的${subNum}个,相差`expr $subNum - $proNum`个"
fi
   
if [ "$sesNum" -lt "$subNum" ];then
   sesRs="实际上有${sesNum}个mosquitto_sub会话,少于预期的${subNum}个,相差`expr $subNum - $sesNum`个"
fi
sPath=`dirname $0`
source $sPath/logger.sh
logPath=$sPath/clogs/
write_log $total
write_log $proRs 
write_log $sesRs
#'BLOCK
