Number=20000
j=0
for i in `seq 1 $Number`
do
        mosquitto_sub -t testSubFixTopic -h 192.168.10.8 -p 1883 -q $j -i subCID$i -k 600 -u mqttclient -P mqttclient -C 1 &
        j=`expr $j + 1`
        if [ $j -ge 3 ]; then
                j=0
        fi
         
done
