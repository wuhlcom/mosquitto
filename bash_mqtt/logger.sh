#!/bin/bash
#create mosquitto client logs or server logs
#auth:wuhongliang
#date:2016-11-14

sPath=`dirname $0`
source $sPath/mqtt.conf 
logPath=$sPath/mqttLogs

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
  if [ -z "$1" ];then
 	 local srvIP=$srv_ip;
  else
	 local srvIP=$1
  fi
  if [ -z "$2" ];then 
	local srvPort=$srv_port;
  else
	local srvPort=$2
  fi
  local ipPort="${srvIP}:${srvPort}"
  process_num=`ps -ef | grep "mosquitto_sub"|wc -l`
  session_num=`netstat -apnt |grep $ipPort|grep ESTABLISHED|wc -l`
  process_num=`expr $process_num - 1`
  mqttinf="mqtt client process number: $process_num tcp session number: $session_num"
  echo ${mqttinf}
 }

#查询sub会话和进程，只返回数量
subResult(){
  if [ -z "$1" ];then
 	 local srvIP=$srv_ip;
  else
	 local srvIP=$1
  fi
  if [ -z "$2" ];then 
	local srvPort=$srv_port;
  else
	local srvPort=$2
  fi
  local ipPort="${srvIP}:${srvPort}"
  #session=`netstat -apnt |grep "$ip_port"|grep ESTABLISHED`
  local  session_num=`netstat -apnt |grep "${ipPort}"|grep ESTABLISHED|wc -l`
  local  process_num=`ps -ef | grep "mosquitto_sub"|wc -l`
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
#create log file dir
createPath(){
  if [ -z "$1" ];then
        logsPath=$logPath
  else
        logsPath=$1
  fi
  test -d $logsPath||mkdir -p $logsPath
}

#查询sub会话和进程，并将结果保存到文件中
subProcess(){
  path=$1
  createPath $path
  fileName=$2
  processFile="${path}/${fileName}_processes.log"
  :>$processFile
  ps -ef | grep "mosquitto_sub" >> $processFile
}

#查询sub会话和进程，并将结果保存到文件中
subSession(){
  path=$1
  createPath $path
  fileName=$2
  if [ -z "$3" ];then 
	local srvIP=$srv_ip;
  else
	local srvIP=$3
  fi
  if [ -z "$4" ];then 
	local srvPort=$srv_port;
  else
	local srvPort=$4
  fi
  local ipPort="${srvIP}:${srvPort}"
  sessionFile="${path}/${fileName}_sessions.log"
  :>$sessionFile
  netstat -apnt |grep "$ipPort"|grep ESTABLISHED >> $sessionFile
}

#获取最新的文件名
getLastLogFileName()
{
    path=$1
    cd $path
    lastLog=`ls -l |grep $currentTime | sort -k8rn | head -1 |awk '{print $9}'`
    logFileName=$lastLog
    cd ..
}
#判断文件名是否存在及文件是否超过指定的大小
isNeedNewFile()
{
    newFile=$1
    if [ -z $newFile ]; then
        return 2
    fi

    if [ -f $newFile ];then
        size=`ls -l $newFile | awk '{print $5}'`
        if [ $size -gt $fileSize ];then
           return 0
        else
            return 1
        fi
    else
        return 2
    fi
}

#创建日志文件名
createFile(){
    #currentTime=`date "+%Y%m%d%H%M%S"`
    if [ -z "$1" ];then
       logsPath=$logPath
    else
       logsPath=$1
    fi

    if [ -z "$2" ];then
        cfileName="${logsPath}/log-${intf}-${cIP}-${currentTime}.log"
    else
        fName=$2
        cfileName="${logsPath}/${fName}-${intf}-${cIP}-${currentTime}.log"
    fi
    createPath $logsPath
    getLastLogFileName $logsPath
    log_file_name=$logFileName
    isNeedNewFile $log_file_name
    result=$?

    if [ $result -eq 0 ] || [ $result -eq 2 ];then
        logFileName=$cfileName
    else
        logFileName=${logsPath}$log_file_name
    fi
}

#创建日志
writeLog ()
{
     msg=$1
     if [ -z "$2" ];then
      level=debug
     else
      level=$2
     fi

    if [ -z "$3" ];then
      logsPath=$logPath
    else
      logsPath=$3
    fi

    if [ -z "$4" ];then
      logFName="log"
    else
      logFName=$4
    fi
     createFile $logsPath $LogFName
    if [ -n "$msg" ];then
      logTime=`date "+[%Y-%m-%d %H:%M:%S]"`
      case $level in
               debug)
                    echo "[DEBUG] $logTime : $msg  " >> $logFileName
               ;;
               info)
                    echo "[INFO] $logTime : $msg  " >> $logFileName
               ;;
               error)
                    echo $logFileName
                    echo "[ERROR] $logTime : $msg  " >> $logFileName
               ;;
              *)
                    echo "error......" >> $logFileName
              ;;
      esac
   fi
}


#客户端查询cpu,mem,swap,mqtt并写入日志
writeMqttLog(){
	msg1=`top_cpu`
	msg2=`meminfo`
	msg3=`swapinfo`
	msg4=`mqttinfo`
	writeLog "$msg1"
	writeLog "$msg2"
	writeLog "$msg3"
	writeLog "$msg4"
}

writeSrvLog(){
	srv1=`srv_mqttinfo`
	srv2=`srv_mqtt`
	srv3=`srv_jps`
	writeLog "$srv1"
	writeLog "$srv2"
	writeLog "$srv3"
}
#监控客户端并生成日志 
monitorLog(){
	while true
	do
	  writeMqttLog
	  p_num=`ps -ef | grep mosquitto_sub|wc -l`
	  s_num=`netstat -apnt |grep $srv_ip:$srv_port|grep ESTABLISHED|wc -l`
	  if [ "$p_num" -eq 0 ] ||[ "$s_num" -eq 0 ]; then
	    msg="mqtt client process num $p_num,session number $s_num,stop logger"
	    writeLog $msg
 	    break
	  fi
	  sleep $logGap
	done
}

#监控服务端并生成日志
sMonitorLog(){
	while true
	do
	  writeSrvLog
          srv_session=$(netstat -apnt|grep "$srv_ip:$srv_port\|$client_ip"|grep ESTABLISHED|wc -l)
	  if [ "$srv_session" -eq 0 ]; then
	    msg="server session number $srv_session,stop logger"
	    writeLog $msg
 	    break
	  fi
	  sleep $logGap
	done
}

case $1 in
 "monitorlog")
     monitorLog
     ;;
 "smonitorlog")
     sMonitorLog
     ;;
 "subresult")
     subResult $2 $3
     ;;
 "srvresult")
     srvResult
     ;;
 "subprocess")
     subProcess $2 $3
     ;;
 "subsession")
     subSession $2 $3 $4 $5
     ;;
 "test")
     writeLog $2
     ;;
 *)
  #echo $0
  ;;
esac
