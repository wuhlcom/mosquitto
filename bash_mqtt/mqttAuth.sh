#!/bin/bash
#auth:wuhongliang
#date:2016-12-02
#add mqtt usr passwd
accBegin=$1
accEnd=$2
clientIDPre=$3
accFileName=$4

redisSet(){
     redisID=$1
     if [ -z $2 ];then
       redisUsr=$defaultUsr
     else
        redisUsr=$2
     fi

     if [ -z $3 ];then
       redisPasswd=$defaultPasswd
     else
       redisPasswd=$3
     fi

     if [ -z $4 ];then
       redisIndex=$defaultIndex
     else
       redisIndex=$4
     fi
     redisData=`echo "set UIDPWD:$redisID;$redisUsr;$redisPasswd $redisIndex"`
     echo ${redisData} 
}

redisAcc(){
  accFile=/tmp/${accFileName}.c
  acclog=/tmp/${accFile}.log
  :>$acc
  :>$acclog
  for i in `seq $accBegin $accEnd`
   do
    clientID=$clientIDPre$i
    echo `redisSet $clientID`>>$accFile
  done
  redis-cli < $accFile >>$acclog
}

redisAcc
