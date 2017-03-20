#!/bin/bash
#监控执行机上的mosquitto_sub进程
#当进程数达到25000以上时主动kill脚本停止执行
currPath=`dirname $0`
crontabLogs=$currPath/crontab.log
homePath="/home/zhilu/mosquitto/"
killPids(){
    local timeStamp=$1
    pid=`ps -ef|grep -e $homePath -e testcase|grep -v grep|awk -F ' ' '{print $2}'`
    pids=(${pid// /})
    echo $pids
    for id in ${pids[@]};
    do
	kill -9 $id
        echo ${timeStamp}"停止所有相关的进程执行脚本" >> $crontabLogs
    done
}

killMqtt(){
  local timeStamp=$1
  local max=25000
  local processNum=`ps -ef | grep "mosquitto_sub"|grep -v grep|wc -l`
  if [ "$processNum" -ge $max ];then
      pkill -9 mosquitto_sub
      pkill -9 mosquitto_sub
      echo ${timeStamp}"第一次kill所有mosquitto_sub" >> $crontabLogs
      killPids $timeStamp
      

      pkill -9 mosquitto_sub
      pkill -9 mosquitto_sub
      echo ${timeStamp}"第二次kill所有mosquitto_sub" >> $crontabLogs
      killPids $timeStamp
  fi
}

logTime=`date "+[%Y-%m-%d %H:%M:%S]"`
#注意这里$logTime要加引号，因为$logTime中有空格
killMqtt "$logTime"
