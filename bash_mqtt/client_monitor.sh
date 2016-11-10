host=192.168.10.188
process_num=`ps -ef | grep mosquitto_sub|wc -l`
session_num=`netstat -apnt |grep $host:1883|grep ESTABLISHED|wc -l`
echo $process_num
echo $session_num
