#!/bin/sh
#date:2016-11-10
#auth:wuhongliang
if [ -z $2 ];then
  srv_ip=192.168.10.103
else
  srv_ip=$2
fi

if [ -z $3 ];then
  srv_port=1883
else
  srv_port=$3
fi

if [ -z $4 ];then
 report_time=5
else
 report_time=$4
fi

if [ -z $5 ];then
  client_ip=""
else
  client_ip=$5
fi

clog="clog"
clogerr="clogerr"

#logftime
logftime() {
  ft=`date +"%Y%m%d%H%M%S"`
  echo ${ft}
}
#log content time
logtime() {
   t=`date +"[%Y-%m-%d %H:%M:%S]"`
   echo ${t}
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

create_logfile() {
 curr_path=`pwd`
 clogsdir=$curr_path/clogs

 #create log file dir
 test -d $clogsdir&&echo "'$clogsdir' existed"||mkdir $clogsdir

 logft=`logftime`
 clogname=${clog}${logft}
 clogerrname=${clogerr}${logft}
 clogpath=${clogsdir}/${clogname}
 clogerrpath=${clogsdir}/${clogerrname}
}

#create logs
createlog()
{
 logt=`logtime`
 echo "[==============$logt========================]">>$clogpath
 minfo=`meminfo`
 sinfo=`swapinfo`
 echo $minfo>>$clogpath
 echo $sinfo>>$clogpath
 process_num=`ps -ef | grep mosquitto_sub|wc -l`
 session_num=`netstat -apnt |grep $srv_ip:$srv_port|grep ESTABLISHED|wc -l`
 echo "process number: $process_num">>$clogpath
 echo "tcp session number: $session_num">>$clogpath
 }

#continus create logs
report()
{
 create_logfile
 while true
 do
        createlog
        if [ "$process_num" -eq 0 -o "$session_num" -eq 0 ];then
        #if [ "$process_num" = 0 ] || [ "$session_num" = 0 ]; then 
	 echo "stop report log">>$clogpath
	 break
        fi
        sleep $report_time
 done
}                                    

if [ "$1" = "report" ];then
   report
else
   echo "Please input 'report' param"
fi




