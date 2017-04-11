Number=40000
j=0
for i in `seq 20001 $Number`
do
        mosquitto_sub -t testSubFixTopic -h 192.168.10.8 -p 1883 -q $j -i subCID$i -k 600 -u mqttclient -P mqttclient &
        j=`expr $j + 1`
        if [ $j -ge 3 ]; then
                j=0
        fi
done

sleep 20
while true
do
    for i in `seq 20001 $Number`
    do
        mosquitto_pub -t testSubFixTopic -h 192.168.10.8 -p 1883 -q 2 -i pubIDRetain20300 -k 600 -u mqttclient -P mqttclient -m test$i
        sleep 1 
    done
done
