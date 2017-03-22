#!/bin/sh

Number=50000
j=0
k=1
typeid1="O7sddgwi96j43YJ1"
typeid2="p5JvLJ6eZQqb5U1W"
clientid_perfix="71a6c76test"
topic_perfix="MIA-IoT/devices"
thingsid="p5JvLJ6eZQqb5U11"
server_ip="192.168.10.8"
for i in `seq 49999 $Number`
do
        mosquitto_sub -t $topic_perfix/$typeid1$clientid_perfix$i/things/$typeid2$thingsid/command -h $server_ip -q $j -i $clientid_perfix$i -u 123 -P 456 & 
        j=`expr $j + 1`
        if [ $j -ge 3 ]; then
                j=0
        fi
done
sleep 1
echo publish
while true
do    
        for i in `seq 49999 $Number`
        do
                
                payload="[{\"name\":\"screen\",\"value\":\"$kbbbb$i\"},{\"name\":\"count1\",\"value\":10}]"
                mosquitto_pub -t $topic_perfix/$typeid1$clientid_perfix$i/things/$typeid2$thingsid/expect -h $server_ip -i zyk -u zyk -P zyk -m "$payload"
        done
        k=k+1
done
