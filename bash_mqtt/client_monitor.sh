#!/bin/sh
host=192.168.10.188
process_num=`ps -ef | grep mosquitto_sub|wc -l`
session_num=`netstat -apnt |grep $host:1883|grep ESTABLISHED|wc -l`

curr=`dirname $(pwd)`
echo $curr
#rs=$(test -d $curr/)
if [ $(test -d "$curr") ]; then
 echo "ahah"
if

echo =============================================================
echo `date "+[%Y-%m-%d %H:%M:%S]"` process number: $process_num
echo `date "+[%Y-%m-%d %H:%M:%S]"` tcp session number: $session_num
echo =============================================================
