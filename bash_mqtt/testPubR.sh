#!/bin/bash
startid=1
endid=1000
for i in `seq $startid $endid`
do
echo "=============pubidRetain${i}=============="
 mosquitto_pub -h 192.168.10.188 -t pubTopicRetain${i} -i "pubIDRetain${i}" -r -m "test${i}" -u mqttclient -P mqttclient&
done


