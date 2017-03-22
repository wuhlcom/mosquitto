#!/bin/bash
#source "/home/zhilu/mosquitto/bash_mqtt/shtest2.sh"
#echo `basename $0`
#fun1 "haha"
#fun2&
#stopScript

str(){
 local s="wa li"
 echo "${s}"
}

testStr(){
 local str1=$1
 echo my value is $str1 
}
#s=`str`
#echo $s
#testStr "$s"
a=false
if [ "$a" = "true" ]; then
  echo $a
  echo a is not null
else
  echo a is null
fi
