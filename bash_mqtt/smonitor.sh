#!/bin/bash
#moniter
# statstic the mqtt connetions number
# mointer the processes
# moniter cpu,memery
#netstat -apn|grep 192.168.10.201:1883|grep 192.168.10.200|grep ESTABLISHED|wc -l
#echo ps -ax |grep "dispatch\|topicroute\|mqtt_process\|access" 1>>log 2>>logerr

#logfile name time
srv_ip="192.168.10.188"
srv_port="1883"
client_ip=""
srvlog="srglog"
srvlogerr="srglogerr"
function logftime {
  ft=`date +"%Y%m%d%H%M%S"`
  echo ${ft}
}

#log content time
function logtime {
  t=`date +"[%Y-%m-%d %H:%M:%S]"`
  echo ${t}
}

function meminfo {
 mem=`free -m|grep -i "Mem"`
 mt=$(echo $mem|awk -F " " {'print $2'})
 mu=$(echo $mem|awk -F " " {'print $3'})
 mf=$(echo $mem|awk -F " " {'print $4'})
 meminf="mem total:$mt used:$mu free:$mf"
 echo  ${meminf}
}

function swapinfo {
 swap=`free -m|grep -i "Swap"`
 st=$(echo $swap|awk -F " " {'print $2'})
 su=$(echo $swap|awk -F " " {'print $3'})
 sf=$(echo $swap|awk -F " " {'print $4'})
 swapinf="swap total:$st used:$su free:$sf"
 echo  ${swapinf}
}

curr_path=`pwd`
srvlogsdir=$curr_path/srvlogs

#create log file dir
test -d $srvlogsdir&&echo "'$srvlogsdir' existed"||mkdir $srvlogsdir

logft=`logftime`
srvlog=${srvlog}${logft}
srvlogerr=${srvlogerr}${logft}
srvlogpath=${srvlogsdir}/${srvlog}
srvlogerrpath=${srvlogsdir}/${srvlogerr}

createlog()
{
 logt=`logtime`
 echo "[==============$logt========================]">>$srvlogpath
 minfo=`meminfo`
 sinfo=`swapinfo`
 echo $minfo>>$srvlogpath
 echo $sinfo>>$srvlogpath
 session_num=$(netstat -apnt|grep "$srv_ip:$srv_port"|grep "192.168.10"|grep ESTABLISHED|wc -l)
 echo "mqtt session:$session_num">>$srvlogpath
 ps -ef |grep -i "dispatch\|topicroute\|mqtt_process\|access" 1>>$srvlogpath 2>>$srvlogerrpath
 sudo jps 1>>$srvlogpath 2>>$srvlogerrpath
 }

while true
do
	createlog
        sleep 300	
done
