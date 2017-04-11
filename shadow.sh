#!/bin/sh

Number=50000
j=0
k=1
typeid1="6eHABx0Pqlra5Mv0"
typeid2="rCtQmpeYZFQzZJNk"
clientid_perfix="71a6c76test"
topic_perfix="MIA-IoT/devices"
#thingsid="c38bdbc0ff95b2b7"
thingsid_perfix="c38bdbc0ff9"
server_ip="192.168.10.8"
for i in `seq 30001 $Number`
do
        mosquitto_sub -t $topic_perfix/$typeid1$clientid_perfix$i/things/$typeid2$thingsid_perfix$i/command -h $server_ip -q $j -i $clientid_perfix$i -u 123 -P 456 & 
        j=`expr $j + 1`
        if [ $j -ge 3 ]; then
                j=0
        fi
done
sleep 1
echo publish
while true
do    
        for i in `seq 10001 $Number`
        do
                
                payload="[{\"name\":\"screen\",\"value\":\"$kbbbb$i\"},{\"name\":\"count1\",\"value\":10}]"
                mosquitto_pub -t $topic_perfix/$typeid1$clientid_perfix$i/things/$typeid2$thingsid_perfix$i/expect -h $server_ip -i zyk -u zyk -P zyk -m "$payload"
        done
        k=k+1
done
