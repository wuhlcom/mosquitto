#!/bin/bash

mqttSub(){
 startid=1
 endid=10
 :>PubrMsg
 for i in `seq $startid $endid`
 do
   echo "=============pubTopicRetain${i} ============"
   mosquitto_sub -h 192.168.10.8 -p 1883 -t mosquittoTopic${i} -i subCID${i} -u mqttclient -P mqttclient  >> PubrMsg&
 done
 sleep 200
}
mqttSub
