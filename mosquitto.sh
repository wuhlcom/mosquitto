Number=20000
j=0
for i in `seq 1 $Number`
do
        mosquitto_sub -t testSubFixTopic -h 192.168.10.8 -p 1883 -q 1 -i subFixID$i -k 3600 -u mqttclient -P mqttclient &
done
