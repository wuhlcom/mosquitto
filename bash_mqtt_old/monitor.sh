#!/bin/bash
#监控执行机上的mosquitto_sub进程
#当进程数达到25000以上时主动kill脚本停止执行
currPath=`dirname $0`
logs=$currPath/mqttCron.log
killPids(){
    local logTime=$1
    pid=`ps -ef|grep -e  mqtt -e testcase|grep -v grep|awk -F ' ' '{print $2}'`
    pids=(${pid// /})
    for id in ${pids[@]};
    do
	kill -9 $id
        echo "${logTime}停止执行脚本" >> $logs
    done
}

killMqtt(){
  local logTime=$1
  local max=25000
  local process_num=`ps -ef | grep "mosquitto_sub"|wc -l`
  if [ "$process_num" -ge $max ];then
      killPids $logTime
      pkill -9 mosquitto_sub
      pkill -9 mosquitto_sub
      echo "${logTime}kill mosquitto_sub" >> $logs
  fi
}

logTime=`date "+[%Y-%m-%d %H:%M:%S]"`
killMqtt $logTime
