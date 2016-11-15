#!/bin/bash
curr_path=`pwd`
logpath=$curr_path/logs/
currenttime=`date "+%Y%m%d%H%M%S"`
fileSize=81920
logfilename=""
if [ -z $1 ];then
  srv_ip=192.168.10.188
else
  srv_ip=$1
fi

if [ -z $2 ];then
  srv_port=1883
else
  srv_port=$2
fi

if [ -z $3 ];then
  loggap=10
else
  loggap=$3
fi

client_ip=192.168.10.

top_cpu() {
 cpuinf=`top -bn 1|grep "Cpu"`
 echo  ${cpuinf}
}

top_mem() {
 memin=`top -bn 1|grep "Mem"`
 echo  ${memin}
}

meminfo() {
 mem=`free -m|grep -i "Mem"`
 mt=$(echo $mem|awk -F " " {'print $2'})
 mu=$(echo $mem|awk -F " " {'print $3'})
 mf=$(echo $mem|awk -F " " {'print $4'})
 meminf="mem total:$mt used:$mu free:$mf"
 echo  ${meminf}
}

swapinfo() {
 swap=`free -m|grep -i "Swap"`
 st=$(echo $swap|awk -F " " {'print $2'})
 su=$(echo $swap|awk -F " " {'print $3'})
 sf=$(echo $swap|awk -F " " {'print $4'})
 swapinf="swap total:$st used:$su free:$sf"
 echo  ${swapinf}
}

mqttinfo(){
 process_num=`ps -ef | grep mosquitto_sub|wc -l`
 session_num=`netstat -apnt |grep $srv_ip:$srv_port|grep ESTABLISHED|wc -l`
  mqttinf="process number: $process_num tcp session number: $session_num"
  echo ${mqttinf}
 }

srv_mqttinfo(){
 srv_session=$(netstat -apnt|grep "$srv_ip:$srv_port"|grep ESTABLISHED|wc -l)
 srv="mqtt sesion num $srv_session"
 echo ${srv}
}

srv_mqtt(){
 proc=$(ps -ef|grep -i "dispatch\|topicroute\|mqtt_process\|access")
 echo ${proc}
}

srv_jps(){
 jps=$(sudo jps)
 echo -e ${jps} 
}

createpath (){
 #create log file dir
 test -d $logpath||mkdir $logpath
 }

createfile()
{
    createpath
    getLastLogFileName $logpath
    filename=$logfilename
    isNeedNewFile $filename 
    result=$?
    if [ $result -eq 0 ];then
        logfilename=${logpath}clogs${currenttime}.log
    elif [ $result -eq 2 ];then
        logfilename=${logpath}clogs${currenttime}.log
    else
        logfilename=${logpath}$filename
    fi
}

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

write_log ()
{
              createfile 
              
              msg=$1
			  if [ -z $2 ];then
				level=debug
			  else
	            level=$1
			  fi
              case $level in
               debug)
               echo "[DEBUG] `date "+%Y%m%d%H%M%S"` : $msg  " >> $logfilename
               ;;
               info)
               echo "[INFO] `date "+%Y%m%d%H%M%S"` : $msg  " >> $logfilename
               ;;
               error)
               echo "[ERROE] `date "+%Y%m%d%H%M%S"` : $msg  " >> $logfilename
               ;;
               *)
               echo "error......" >> $logfilename
               ;;
               esac
}

getLastLogFileName()
{
    path=$1
    cd $path
    lastLog=`ls -l |grep $currenttime | sort -k8rn | head -1 |awk '{print $9}'`
    logfilename=$lastLog
}

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
 
monitor_log(){
	while true
	do
	  write_mqtt_log
	  p_num=`ps -ef | grep mosquitto_sub|wc -l`
	  s_num=`netstat -apnt |grep $srv_ip:$srv_port|grep ESTABLISHED|wc -l`
	  if [ "$p_num" -eq 0 ] ||[ "$s_num" -eq 0 ]; then
	    msg="process num $p_num,session number $s_num,stop logger"
	    write_log $msg
 	    break
	  fi
	  sleep $loggap
	done
}

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
	  sleep $loggap
	done
}

