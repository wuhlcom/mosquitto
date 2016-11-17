#!/bin/bash
#wuhongliang
#2016-11-17

stopSubPub(){
  pkill mosquitto_sub
  pids= `ps -ef |grep mqttClient.sh|grep /bin/bash|awk -F " " '{print $2}'`
  OLD_IFS="$IFS"
  IFS=" "
  arr=($pids)
  IFS="$OLD_IFS"
  for pid in ${arr[@]};
  do 
    kill -9 $pid
  done
}

