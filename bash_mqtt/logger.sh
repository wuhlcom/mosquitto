#!/bin/bash
#create mosquitto client logs or server logs
#auth:wuhongliang
#date:2016-11-14

sPath=`dirname $0`
source $sPath/mqtt.conf 
logPath=$sPath/logs/

#查询cpu top
top_cpu() {
 cpuinf=`top -bn 1|grep "Cpu"`
 echo  ${cpuinf}
}

#查询内存 top
top_mem() {
 memin=`top -bn 1|grep "Mem"`
 echo  ${memin}
}

#查询内存 free
meminfo() {
 mem=`free -m|grep -i "Mem"`
 mt=$(echo $mem|awk -F " " {'print $2'})
 mu=$(echo $mem|awk -F " " {'print $3'})
 mf=$(echo $mem|awk -F " " {'print $4'})
 meminf="mem total:$mt used:$mu free:$mf"
 echo  ${meminf}
}
#查询swap free
swapinfo() {
 swap=`free -m|grep -i "Swap"`
 st=$(echo $swap|awk -F " " {'print $2'})
 su=$(echo $swap|awk -F " " {'print $3'})
 sf=$(echo $swap|awk -F " " {'print $4'})
 swapinf="swap total:$st used:$su free:$sf"
 echo  ${swapinf}
}

#查询sub会话和进程，返回日志描述
mqttinfo(){
  process_num=`ps -ef | grep "mosquitto_sub"|wc -l`
  session_num=`netstat -apnt |grep $srv_ip:$srv_port|grep ESTABLISHED|wc -l`
  process_num=`expr $process_num - 1`
  #echo `date +"%Y-%m-%d %H:%M:%S"`>"$sPath"/subResult
  #echo $process_num>>"$sPath"/subResult
  #echo $session_num>>"$sPath"/subResult
  mqttinf="mqtt client process number: $process_num tcp session number: $session_num"
  echo ${mqttinf}
 }

#查询sub会话和进程，只返回数量
subResult(){
  ip_port="${srv_ip}:${srv_port}"
  #session=`netstat -apnt |grep "$ip_port"|grep ESTABLISHED`
  session_num=`netstat -apnt |grep "$ip_port"|grep ESTABLISHED|wc -l`
  process_num=`ps -ef | grep "mosquitto_sub"|wc -l`
  process_num=`expr $process_num - 1`
  echo ${process_num}
  echo ${session_num}
 }
#服务端查询mqtt会话并返回日志描述格式结果
srv_mqttinfo(){
 if [ -n $clientIP ];then
   srv_session=$(netstat -apnt|grep "$srv_ip:$srv_port"|grep $clientIP|grep ESTABLISHED|wc -l)
 else
   srv_session=$(netstat -apnt|grep "$srv_ip:$srv_port"|grep ESTABLISHED|wc -l)
 fi
 #echo `date +"%Y-%m-%d %H:%M:%S"`>"$sPath"/srvResult
 #echo $srv_session>>"$sPath"/srvResult
 srv="mqtt server sesion num $srv_session"
 echo ${srv}
}
#查询服务端会话并返回数量
srvResult(){
 if [ -n $clientIP ];then
   srv_session=$(netstat -apnt|grep "$srv_ip:$srv_port"|grep $clientIP|grep ESTABLISHED|wc -l)
 else
   srv_session=$(netstat -apnt|grep "$srv_ip:$srv_port"|grep ESTABLISHED|wc -l)
 fi
 echo ${srv_session}
}

#服务端进程查询，返回日志描述格式结果
srv_mqtt(){
 #proc=$(ps -ef|grep -i "dispatch\|topicroute\|mqtt_process\|access")
 #echo ${proc}
 dis=$(ps -ef|grep -i dispatch|grep iot|wc -l)
 route=$(ps -ef|grep -i topicroute|grep iot|wc -l)
 mqtt_pro=$(ps -ef|grep -i mqtt_process|grep iot|wc -l)
 acc=$(ps -ef|grep -i access|grep iot|wc -l)
 srv_pro="dispatch topicroute mqtt_access access  OK!"
 if [ ! $dis = 2 ]||[ ! $route = 2 ]||[ ! $mqtt_pro = 2 ]||[ ! $acc = 2 ];then
 	srv_pro="ERROR:dispatch num:$dis,topicroute num:$route,mqtt_process num:$mqtt_pro,access num:$acc"
 fi
 echo ${srv_pro}
}
#服务端jps进程查询，返回日志描述格式结果
srv_jps(){
 #jps=$(sudo jps)
 #echo -e ${jps} 
 kafka=`sudo jps|grep Kafka|wc -l`
 zoom=`sudo jps|grep QuorumPeerMain|wc -l`
 pro="Kafka QuorumPeerMain  OK!"
 if [ ! $kafka = 1 ]||[ ! $zoom = 3 ];then
	pro="ERROR:kafa session number $kafka,QuormPeerMain number $zoom"
 fi
 echo ${pro}
}
#如果目录不存在创建目录
createpath (){
 #create log file dir
 test -d $logPath||mkdir $logPath
 }

#创建日志文件名
createfile()
{
    createpath
    getLastLogFileName $logPath
    filename=$logFileName
    isNeedNewFile $filename
    result=$?
    if [ -z "$1" ];then
        logFileName="${logPath}log-${intf}-${cIP}-${currentTime}.log"
    else
   	logFileName=$1
    fi

    if [ $result -eq 0 ] || [ $result -eq 2 ];then
        logFileName=$logFileName
    else
        logFileName=${logPath}$filename
    fi
}

#判断文件名是否存在及文件是否超过指定的大小
isNeedNewFile()
{
    filename=$1
    if [ -z $filename ]; then
        return 2
    fi
    
    if [ -f $filename ];then
        size=`ls -l $filename | awk '{print $5}'`
        if [ $size -gt $fileSize ];then
           return 0
        else
            return 1
        fi
    else
        return 2
    fi
}
#创建日志
write_log ()
{
              msg=$1
              
	      if [ -n "$2" ];then
	           createfile $2 
	      else
		   createfile
	      fi
              
	      if [ -z "$3" ];then
		level=debug
	      else
	        level=$3
	      fi
              
	     if [ -n "$msg" ];then
                case $level in
                  debug)
                     echo "[DEBUG] `date "+[%Y-%m-%d %H:%M:%S]"` : $msg  " >> $logFileName
                  ;;
                  info)
                     echo "[INFO] `date "+[%Y-%m-%d %H:%M:%S]"` : $msg  " >> $logFileName
                  ;;
                  error)
                     echo "[ERROE] `date "+[%Y-%m-%d %H:%M:%S]"` : $msg  " >> $logFileName
                 ;;
                 *)
                     echo "error......" >> $logFileName
                 ;;
              esac
	   fi
}
#
getLastLogFileName()
{
    path=$1
    cd $path
    lastLog=`ls -l |grep $currentTime | sort -k8rn | head -1 |awk '{print $9}'`
    logFileName=$lastLog
    cd .. 
}

#客户端查询cpu,mem,swap,mqtt并写入日志
write_mqtt_log(){
	msg1=`top_cpu`
	msg2=`meminfo`
	msg3=`swapinfo`
	msg4=`mqttinfo`
	write_log "$msg1"
	write_log "$msg2"
	write_log "$msg3"
	write_log "$msg4"
}

write_srv_log(){
	srv1=`srv_mqttinfo`
	srv2=`srv_mqtt`
	srv3=`srv_jps`
	write_log "$srv1"
	write_log "$srv2"
	write_log "$srv3"
}
#监控客户端并生成日志 
monitor_log(){
	while true
	do
	  write_mqtt_log
	  p_num=`ps -ef | grep mosquitto_sub|wc -l`
	  s_num=`netstat -apnt |grep $srv_ip:$srv_port|grep ESTABLISHED|wc -l`
	  if [ "$p_num" -eq 0 ] ||[ "$s_num" -eq 0 ]; then
	    msg="mqtt client process num $p_num,session number $s_num,stop logger"
	    write_log $msg
 	    break
	  fi
	  sleep $logGap
	done
}

#监控服务端并生成日志
smonitor_log(){
	while true
	do
	  write_srv_log
          srv_session=$(netstat -apnt|grep "$srv_ip:$srv_port\|$client_ip"|grep ESTABLISHED|wc -l)
	  if [ "$srv_session" -eq 0 ]; then
	    msg="server session number $srv_session,stop logger"
	    write_log $msg
 	    break
	  fi
	  sleep $logGap
	done
}

case $1 in
 "monitorlog")
     monitor_log
     ;;
 "smonitorlog")
     smonitor_log
     ;;
 "subresult")
     subResult
     ;;
 "srvresult")
     srvResult
     ;;
 "test")
     write_log $2
     ;;
 *)
  #echo $0
  ;;
esac
