#!/bin/bash
#auth:wuhongliang
#date:2017-01-04
getProcessIDs(){
  local fileName=$1
  local ids= `cat $fileName |awk -F " " '{print $10}'`
  echo ${ids}
}

checkProcess(){
  local idPre=$1
  local startID=$2
  local endID=$3
  local reportFile=$4
  i=0
  :>subProcessError.log
  ids=getProcessIDs $reportFile
  for id in `seq $startID $endID`
  do
   flag=false
   subID=$idPre$id
   for rid in $ids;
   do
     if [ "$id" = "$rid" ];then
        echo "Sub ID ${id} existed!"
        flag=true
        break
     fi
   done
   if [ ! "${flag}" ];then
      echo "Can't find Sub ID \'${id} \'!" >> subProcessError.log
   fi
 done
}

getSessionIDs(){
  local fileName=$1
  local ids= `cat $fileName |awk -F " " '{print $7}'`
  echo ${ids}
}

checkSession(){
  local idPre=$1
  local startID=$2
  local endID=$3
  local reportFile=$3
  i=0
  :>subSessionError.log
  ids=getSessionIDs $reportFile
  for id in `seq $startID $endID`
  do
   flag=false
   subID=$idPre$id
   for rid in $ids;
   do
     if [ "$id" = "$rid" ];then
        echo "Sub ID ${id} existed!"
        flag=true
        break
     fi
   done
   if [ ! "${flag}" ];then
      echo "Can't find Sub ID \'${id} \'!" >> subSessionError.log
   fi
 done
}
if [ "$1" = "checkprocess" ];then
   checkProcess $2 $3 $4 $5 
fi
