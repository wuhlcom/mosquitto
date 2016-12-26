#!/bin/bash
startid=1
endid=1000
:>pubrMsg
for i in `seq $startid $endid`
do
  echo "=============pubTopicRetain${i} ============"
  mosquitto_sub -h 192.168.10.188 -t pubTopicRetain${i} -i subMsgRetainId${i} -u mqttclient -P mqttclient -C 1 >> pubrMsg&
done
