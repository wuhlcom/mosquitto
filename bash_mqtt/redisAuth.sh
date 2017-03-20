#!/bin/bash
#auth:wuhongliang
#date:2016-12-02
#add mqtt usr passwd
sPath=`dirname $0`
#source $sPath/mqtt.conf
accBegin=1
accEnd=100
clientIDPre=mosquitto
accFileName=redis_liucaiping
redisPort=6379
redisSrvIP=192.168.10.99
defaultUsr="mqttclient"
defaultPasswd="mqttclient"
redisSet(){
     redisID=$1
     #中括号中判断变量一定要加引号
     if [ -z "$2" ];then
       redisUsr=$defaultUsr
     else
        redisUsr=$2
     fi

     if [ -z "$3" ];then
       redisPasswd=$defaultPasswd
     else
       redisPasswd=$3
     fi

     if [ -z "$4" ];then
       redisIndex=$defaultIndex
     else
       redisIndex=$4
     fi
     #redisData=`echo "set UIDPWD:$redisID;$redisUsr;$redisPasswd $redisIndex"`
     redisData=`echo "hmset CINFO:$redisID USER $redisUsr PASSWD $redisPasswd"`
     echo ${redisData} 
}

redisAcc(){
  accFile=/tmp/${accFileName}.c
  accLog=${accFile}.log
  :>$accFile
  :>$accLog
  if [ "$accEnd" = 0 ];then
            echo `redisSet $clientIDPre`>>$accFile
  else
        for i in `seq $accBegin $accEnd`
           do
            clientID=$clientIDPre$i
            echo `redisSet $clientID`>>$accFile
        done
  fi
 # redis-cli < $accFile >>$accLog
 redis-cli -p $redisPort -h $redisSrvIP  < $accFile >>$accLog
}

redisAcc
