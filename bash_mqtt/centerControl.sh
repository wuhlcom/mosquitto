#!/bin/bash 
# send ssh cmd to run script of remote client  
ip_array=("192.168.10.76")  
user="vagrant"  
remote_dir="/home/vagrant/bash_mqtt"
remote_sub=$remote_dir/mqttClient.sh
cmd=mqttsub  
port=22
subnum=6
#本地通过ssh执行远程服务器的脚本  
for ip in ${ip_array[*]}  
do  
    if [ $ip = "192.168.1.1" ]; then  
        port="7777"  
    fi  
    #指定某台机器去启动订阅
    # ssh -t -p $port $user@$ip "$remote_cmd"&
    ssh -p $port $user@$ip "$remote_cmd $cmd"&
    sleep 5 
done  

query_sub=$remote_dir/logger.sh
cmd=subresult
i=0
for ip in ${ip_array[*]}
do
  while true
  do
    subloop=`ssh -p $port $user@$ip "cat /home/vagrant/bash_mqtt/subLoop"`
    loopnum=`echo $subloop|awk -F " " '{print $3}'`
    #订阅完成则查询订阅结果
    if [ $loopnum = $subnum ];then
      subrs=$(ssh -p $port $user@$ip "$qurey_sub $cmd")
      break
    fi
    ((i++))
    #订阅超时后也要订阅结果
     subrs=$(ssh -p $port $user@$ip "$qurey_sub $cmd")
    if [ $i = 10 ];then
	break
    fi
    sleep 5
  done
done

